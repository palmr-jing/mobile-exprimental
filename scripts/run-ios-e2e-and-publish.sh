#!/bin/bash
# run-ios-e2e-and-publish.sh — one MobileCommander iOS E2E run, end to end.
#
# Mirrors palmr-coach-ios/scripts/run-ios-e2e-and-publish.sh so MobileCommander's
# runs land in the Emma dashboard project tab with tests, scenarios, unit results,
# and video — exactly like Palmr Coach. Triggered 3x/day by the
# com.palmr.mobilecommander-e2e LaunchAgent on palmr-m24 (09:00/15:00/21:00 local),
# and runnable by hand.
#
# It:
#   1. Syncs the repo to origin/main and regenerates the Xcode project (xcodegen)
#   2. Boots the iOS simulator and builds for testing once
#   3. Runs unit (MobileCommanderTests), smoke (SignInUITests), and scenario
#      (ChatUITests + ChatScenarioUITests) suites against the seeded Firebase
#      emulator, recording simulator video per UI phase
#   4. Parses .xcresult bundles via xcresulttool for pass/fail counts
#   5. Trims, captions, and concatenates per-phase .mp4 clips via ffmpeg
#   6. Hands a manifest to upload-test-run.cjs for Drive upload + Firestore write
#
# Hermetic: everything talks to the local Firebase Local Emulator Suite seeded by
# scripts/seed-emulator.mjs. It never touches the live fleet.
#
# NOT `set -e`: a failing suite is an expected outcome we still publish.
set -uo pipefail

# --- locate repo -------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_DIR"

LOG_DIR="$REPO_DIR/logs"
mkdir -p "$LOG_DIR"
RUN_LOG="$LOG_DIR/e2e-runs.log"

# --- log rotation: daily files, keep last 30 days ----------------------------
if [ -f "$RUN_LOG" ]; then
  LAST_MOD_DAY=$(date -r "$RUN_LOG" +%Y-%m-%d 2>/dev/null || echo "")
  TODAY=$(date +%Y-%m-%d)
  if [ -n "$LAST_MOD_DAY" ] && [ "$LAST_MOD_DAY" != "$TODAY" ]; then
    mv "$RUN_LOG" "$LOG_DIR/e2e-runs-$LAST_MOD_DAY.log" 2>/dev/null || true
  fi
fi
find "$LOG_DIR" -name 'e2e-runs-*.log' -type f -mtime +30 -delete 2>/dev/null || true

exec > >(tee -a "$RUN_LOG") 2>&1

now_ms() { node -e 'process.stdout.write(String(Date.now()))'; }
now_sec() { node -e 'process.stdout.write(String(Date.now()/1000))'; }
ts() { date '+%Y-%m-%d %H:%M:%S %Z'; }
log() { echo "[$(ts)] $*"; }

RUN_START_MS=$(now_ms)
RUN_STAMP=$(date +%Y%m%d-%H%M%S)
log "=============================================================="
log "MobileCommander iOS E2E run starting (host=$(hostname -s), stamp=$RUN_STAMP)"

# --- configuration -----------------------------------------------------------
SIMULATOR_NAME="${MC_SIMULATOR:-iPhone 17 Pro}"
SCHEME="MobileCommander"
DERIVED_DATA="/tmp/MobileCommander-DerivedData"
DESTINATION="platform=iOS Simulator,name=$SIMULATOR_NAME"
# Must match the app's Firebase project (Resources/GoogleService-Info.plist):
# the emulator namespaces data per project id, so seeding any other id leaves the
# app reading an empty backend.
PROJECT_ID="${PROJECT_ID:-fir-web-codelab-8ace9}"
EMULATOR_HOST="127.0.0.1"
FIRESTORE_PORT=8080
AUTH_PORT=9099
STORAGE_PORT=9199
PROJECT_NAME="${MC_PROJECT_NAME:-mobile commander}"
COMMANDER_WORKER_DIR="${COMMANDER_WORKER_DIR:-$HOME/repos/experimental/commander/worker}"

# Pass --dry-run through to the uploader when MC_E2E_DRY_RUN=1 (local validation
# that never writes to live Firestore/Drive).
PUBLISH_EXTRA=""
[ "${MC_E2E_DRY_RUN:-0}" = "1" ] && PUBLISH_EXTRA="--dry-run"

MANIFEST="$LOG_DIR/manifest-$RUN_STAMP.json"
UNIT_RESULT="/tmp/mc-unit-$RUN_STAMP.xcresult"
SMOKE_RESULT="/tmp/mc-smoke-$RUN_STAMP.xcresult"
SCENARIOS_RESULT="/tmp/mc-scenarios-$RUN_STAMP.xcresult"
UNIT_JSON="$LOG_DIR/unit-$RUN_STAMP.json"
SMOKE_JSON="$LOG_DIR/smoke-$RUN_STAMP.json"
SCENARIOS_JSON="$LOG_DIR/scenarios-$RUN_STAMP.json"
COMBINED_VIDEO="$LOG_DIR/combined-$RUN_STAMP.mp4"

# Per-phase video clips
SMOKE_VIDEO="$LOG_DIR/phase-2-smoke-$RUN_STAMP.mp4"
SCENARIOS_VIDEO="$LOG_DIR/phase-3-scenarios-$RUN_STAMP.mp4"

EMULATOR_PID=""
VIDEO_PID=""
SIM_UDID=""

# --- cleanup ------------------------------------------------------------------
cleanup() {
  if [ -n "$VIDEO_PID" ] && kill -0 "$VIDEO_PID" 2>/dev/null; then
    kill -INT "$VIDEO_PID" 2>/dev/null || true
    wait "$VIDEO_PID" 2>/dev/null || true
    VIDEO_PID=""
  fi
  if [ -n "$EMULATOR_PID" ] && kill -0 "$EMULATOR_PID" 2>/dev/null; then
    log "stopping Firebase emulators (PID $EMULATOR_PID)"
    kill "$EMULATOR_PID" 2>/dev/null || true
    wait "$EMULATOR_PID" 2>/dev/null || true
    EMULATOR_PID=""
  fi
}
trap cleanup EXIT

# --- helper: resolve the firebase CLI ----------------------------------------
firebase_cmd() {
  if command -v firebase &>/dev/null; then
    echo "firebase"
  elif command -v npx &>/dev/null; then
    echo "npx --no-install firebase-tools"
  else
    echo ""
  fi
}

# --- helper: ensure node deps for seeding (firebase-admin) -------------------
# seed-emulator.mjs imports firebase-admin via ESM; that ignores NODE_PATH, so the
# package must resolve from the repo's node_modules. Install on demand (cached on
# palmr-m24). Returns non-zero if it still can't be resolved.
ensure_node_deps() {
  if [ -d "$REPO_DIR/node_modules/firebase-admin" ]; then
    return 0
  fi
  log "installing node deps (firebase-admin/firebase-tools) for seeding"
  ( cd "$REPO_DIR" && npm install --no-audit --no-fund --prefer-offline 2>&1 | tail -5 ) || true
  [ -d "$REPO_DIR/node_modules/firebase-admin" ]
}

# --- helper: parse xcresult → summary JSON -----------------------------------
parse_xcresult() {
  local bundle="$1"
  local output="$2"
  local fallback_ms="${3:-0}"

  if [ ! -d "$bundle" ]; then
    echo '{"passed":0,"total":0,"duration_ms":0,"failed":[]}' > "$output"
    return
  fi

  node -e '
    const { execSync } = require("child_process");
    const fs = require("fs");
    const bundle = process.argv[1];
    const output = process.argv[2];
    const fallbackMs = parseInt(process.argv[3] || "0", 10);

    let passed = 0, total = 0, durationMs = 0;
    const failed = [];

    try {
      const raw = execSync(
        `xcrun xcresulttool get test-results summary --path "${bundle}" --compact`,
        { encoding: "utf-8", timeout: 30000 }
      );
      const summary = JSON.parse(raw);
      passed = summary.passedTests || 0;
      total = summary.totalTestCount || 0;
      if (summary.startTime && summary.finishTime) {
        durationMs = Math.round((summary.finishTime - summary.startTime) * 1000);
      }
    } catch (e) {
      process.stderr.write("xcresulttool summary failed: " + e.message + "\n");
    }

    try {
      const raw = execSync(
        `xcrun xcresulttool get test-results tests --path "${bundle}" --compact`,
        { encoding: "utf-8", timeout: 30000 }
      );
      const data = JSON.parse(raw);
      const walk = (node, parentName) => {
        const name = parentName ? parentName + "/" + node.name : node.name;
        if (node.result === "Failed" && node.nodeType === "Test Case") {
          failed.push(name);
        }
        for (const child of node.children || []) walk(child, name);
      };
      for (const node of data.testNodes || []) walk(node, "");
    } catch (e) {
      process.stderr.write("xcresulttool tests failed: " + e.message + "\n");
    }

    if (!durationMs && fallbackMs) durationMs = fallbackMs;

    fs.writeFileSync(output, JSON.stringify({ passed, total, duration_ms: durationMs, failed }));
    process.stderr.write("parsed " + bundle + ": " + passed + "/" + total + "\n");
  ' "$bundle" "$output" "$fallback_ms"
}

# --- helper: start/stop simulator video recording ----------------------------
start_video() {
  local output="$1"
  if [ -z "$SIM_UDID" ]; then
    log "WARNING: no simulator UDID — skipping video recording"
    return
  fi
  xcrun simctl io "$SIM_UDID" recordVideo --codec=h264 "$output" &
  VIDEO_PID=$!
  log "started video recording (PID $VIDEO_PID) → $output"
}

stop_video() {
  if [ -n "$VIDEO_PID" ] && kill -0 "$VIDEO_PID" 2>/dev/null; then
    kill -INT "$VIDEO_PID" 2>/dev/null || true
    wait "$VIDEO_PID" 2>/dev/null || true
    log "stopped video recording (PID $VIDEO_PID)"
    VIDEO_PID=""
  fi
}

# --- helper: generate ffmpeg trim filter from xcresult test timings ----------
# Keeps only frames during active tests so the clip isn't mostly idle home screen.
generate_trim_filter() {
  local xcresult="$1"
  local video_start="$2"
  local video="$3"

  [ -d "$xcresult" ] && [ -f "$video" ] || return 0

  local script="/tmp/mc-trim-gen-$$.js"
  cat > "$script" <<'TRIMJS'
const { execSync } = require("child_process");
const videoStart = parseFloat(process.argv[3]);
const bundle = process.argv[2];

if (isNaN(videoStart)) {
  process.stderr.write("trim: invalid video start epoch\n");
  process.exit(1);
}

let data;
try {
  const raw = execSync(
    `xcrun xcresulttool get test-results tests --path "${bundle}" --compact`,
    { encoding: "utf-8", timeout: 30000 }
  );
  data = JSON.parse(raw);
} catch (e) {
  process.stderr.write("trim: xcresulttool parse failed: " + e.message + "\n");
  process.exit(1);
}

const tests = [];
const walk = (node) => {
  if (node.nodeType === "Test Case") {
    tests.push({
      name: node.name,
      startTime: node.startTime != null ? node.startTime : null,
      duration: (typeof node.duration === "number" && isFinite(node.duration)) ? node.duration : 0,
    });
  }
  for (const child of node.children || []) walk(child);
};
for (const node of data.testNodes || []) walk(node);

if (tests.length === 0) {
  process.stderr.write("trim: no test cases found\n");
  process.exit(1);
}

const BUFFER = 0.4;
const segments = [];
const hasStartTimes = tests.every(t => t.startTime !== null);

if (hasStartTimes) {
  for (const t of tests) {
    const relStart = t.startTime - videoStart;
    segments.push({ start: Math.max(0, relStart - BUFFER), end: relStart + t.duration + BUFFER });
  }
  process.stderr.write("trim: using per-test startTime for " + tests.length + " test(s)\n");
} else {
  // Fallback: estimate by walking suite start + cumulative durations.
  let suiteStart = null;
  const walkSuite = (node) => {
    if ((node.nodeType === "Test Suite" || node.nodeType === "Unit Test Bundle") && node.startTime != null) {
      if (suiteStart === null || node.startTime < suiteStart) suiteStart = node.startTime;
    }
    for (const child of node.children || []) walkSuite(child);
  };
  for (const node of data.testNodes || []) walkSuite(node);
  if (suiteStart === null) {
    try {
      const sumRaw = execSync(
        `xcrun xcresulttool get test-results summary --path "${bundle}" --compact`,
        { encoding: "utf-8", timeout: 30000 }
      );
      suiteStart = JSON.parse(sumRaw).startTime || null;
    } catch {}
  }
  if (suiteStart === null) { process.stderr.write("trim: no timing data\n"); process.exit(1); }
  const GAP = 2.5;
  let cursor = suiteStart - videoStart;
  for (let i = 0; i < tests.length; i++) {
    if (i > 0) cursor += GAP;
    segments.push({ start: Math.max(0, cursor - BUFFER), end: cursor + tests[i].duration + BUFFER });
    cursor += tests[i].duration;
  }
  process.stderr.write("trim: using estimated offsets for " + tests.length + " test(s)\n");
}

segments.sort((a, b) => a.start - b.start);
const merged = [{ ...segments[0] }];
for (let i = 1; i < segments.length; i++) {
  const prev = merged[merged.length - 1];
  if (segments[i].start <= prev.end) prev.end = Math.max(prev.end, segments[i].end);
  else merged.push({ ...segments[i] });
}

const TARGET_FPS = 30;
const expr = merged.map(s => `between(t,${s.start.toFixed(3)},${s.end.toFixed(3)})`).join("+");
process.stdout.write(`fps=${TARGET_FPS},select='${expr}',setpts=N/${TARGET_FPS}/TB`);
process.stderr.write("trim: " + merged.length + " segment(s)\n");
TRIMJS

  node "$script" "$xcresult" "$video_start" || true
  rm -f "$script"
}

# --- helper: generate per-test caption drawtext filters ----------------------
generate_captions() {
  local xcresult="$1"
  local output="$2"
  local font="$3"

  [ -d "$xcresult" ] || return 0

  local script="/tmp/mc-caption-gen-$$.js"
  cat > "$script" <<'CAPTIONSCRIPT'
const { execSync } = require("child_process");
const fs = require("fs");
const bundle = process.argv[2];
const output = process.argv[3];
const fontFile = process.argv[4] || "/System/Library/Fonts/Helvetica.ttc";

const humanize = {
  "testReplyToEmmaAutoTagsMention": "Reply to Emma → message auto-tags @emma",
  "testReplyToTeammateDoesNotTagEmma": "Reply to a teammate → no @emma added",
  "testReplyBarCancels": "Stage a reply, then cancel it",
  "testTypeAndSendMessage": "Type and send a chat message",
  "testVoiceDictationFillsComposer": "Voice dictation fills the composer",
  "testMentionAutocompleteAppears": "@mention autocomplete offers Emma",
  "testReplyBarAppearsAndCancels": "Reply bar appears, then cancels",
};

function fallbackHumanize(name) {
  return name.replace(/^test[A-Z]?_?/, "").replace(/([a-z])([A-Z])/g, "$1 $2").replace(/^./, s => s.toUpperCase());
}
function escapeDrawtext(s) {
  return s.replace(/\\/g, "\\\\").replace(/'/g, "’").replace(/%/g, "%%").replace(/:/g, "\\:");
}

let cues = [];
try {
  const raw = execSync(
    `xcrun xcresulttool get test-results tests --path "${bundle}" --compact`,
    { encoding: "utf-8", timeout: 30000 }
  );
  const data = JSON.parse(raw);
  const tests = [];
  const walk = (node) => {
    if (node.nodeType === "Test Case") {
      const dur = (typeof node.duration === "number" && isFinite(node.duration)) ? node.duration : 0;
      tests.push({ name: node.name.replace(/\(\)$/, ""), duration: dur });
    }
    for (const child of node.children || []) walk(child);
  };
  for (const node of data.testNodes || []) walk(node);

  let cum = 0;
  const MIN = 1.5;
  for (const t of tests) {
    const label = humanize[t.name] || fallbackHumanize(t.name);
    const start = cum;
    const end = cum + Math.max(t.duration, MIN);
    cues.push({ start, end, label });
    cum = end;
  }
  process.stderr.write("captions: " + tests.length + " cue(s)\n");
} catch (e) {
  process.stderr.write("captions: generation failed: " + e.message + "\n");
}

if (cues.length > 0) {
  const filters = cues.map(c => [
    "drawtext=fontfile='" + fontFile + "'",
    "text='" + escapeDrawtext(c.label) + "'",
    "fontsize=40", "fontcolor=white", "box=1", "boxcolor=black@0.6", "boxborderw=8",
    "x=(w-text_w)/2", "y=h-220",
    "enable='between(t," + c.start.toFixed(3) + "," + c.end.toFixed(3) + ")'",
  ].join(":"));
  fs.writeFileSync(output, filters.join(","));
  process.stderr.write("captions: wrote " + cues.length + " drawtext filter(s)\n");
}
CAPTIONSCRIPT

  node "$script" "$xcresult" "$output" "$font" 2>&1 || true
  rm -f "$script"
}

# --- helper: publish manifest via uploader -----------------------------------
publish() {
  node -e '
    const fs = require("fs");
    const m = {
      project: process.env.M_PROJECT || "mobile commander",
      branch: "main",
      machine: process.env.M_MACHINE || require("os").hostname(),
      commit_sha: process.env.M_SHA || null,
      commit_short: process.env.M_SHORT || null,
      run_stamp: process.env.M_STAMP || "",
      duration_ms: parseInt(process.env.M_TOTAL_MS || "0", 10),
      failure_stage: process.env.M_FAIL_STAGE || null,
      error_message: process.env.M_ERR || null,
      reports: {
        unit: process.env.M_UNIT_JSON || null,
        smoke: process.env.M_SMOKE_JSON || null,
        scenarios: process.env.M_SCEN_JSON || null,
      },
      measured: {
        unit_ms: parseInt(process.env.M_UNIT_MS || "0", 10),
        smoke_ms: parseInt(process.env.M_SMOKE_MS || "0", 10),
        scenarios_ms: parseInt(process.env.M_SCEN_MS || "0", 10),
      },
      combined_video: process.env.M_COMBINED || null,
      individual_videos: JSON.parse(process.env.M_VIDEOS || "[]"),
      screenshots: JSON.parse(process.env.M_SCREENSHOTS || "[]"),
    };
    fs.writeFileSync(process.env.M_OUT, JSON.stringify(m, null, 2));
  '

  log "wrote manifest $MANIFEST"
  log "publishing to Drive + Firestore...${PUBLISH_EXTRA:+ ($PUBLISH_EXTRA)}"
  node "$SCRIPT_DIR/upload-test-run.cjs" "$MANIFEST" $PUBLISH_EXTRA
}

export_publish_vars() {
  export M_OUT="$MANIFEST"
  export M_PROJECT="$PROJECT_NAME"
  export M_MACHINE="${MACHINE_NAME:-$(hostname -s)}"
  export M_SHA="${COMMIT_SHA:-}"
  export M_SHORT="${COMMIT_SHORT:-}"
  export M_STAMP="$RUN_STAMP"
  export M_TOTAL_MS="$(( $(now_ms) - RUN_START_MS ))"
  export M_FAIL_STAGE="${FAILURE_STAGE:-}"
  export M_ERR="${ERROR_MESSAGE:-}"
  export M_UNIT_JSON="${UNIT_REPORT:-}"
  export M_SMOKE_JSON="${SMOKE_REPORT:-}"
  export M_SCEN_JSON="${SCEN_REPORT:-}"
  export M_UNIT_MS="${UNIT_MS:-0}"
  export M_SMOKE_MS="${SMOKE_MS:-0}"
  export M_SCEN_MS="${SCEN_MS:-0}"
  export M_COMBINED="${COMBINED_OUT:-}"
  export M_VIDEOS="${VIDEOS_JSON:-[]}"
  export M_SCREENSHOTS="${SCREENSHOTS_JSON:-[]}"
}

# --- 1. sync to origin/main + regenerate project -----------------------------
# MC_E2E_SKIP_SYNC=1 runs the tree as-is (e.g. validating a branch/worktree
# before it is on main); the LaunchAgent never sets it.
if [ "${MC_E2E_SKIP_SYNC:-0}" = "1" ]; then
  log "MC_E2E_SKIP_SYNC=1 — not syncing to origin/main"
else
  log "git fetch + reset --hard origin/main"
  if ! git fetch origin 2>&1; then
    log "WARNING: git fetch failed; proceeding with the tree as-is"
  fi
  git reset --hard origin/main 2>&1 || log "WARNING: git reset failed; proceeding with the tree as-is"
fi

COMMIT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "")
COMMIT_SHORT=${COMMIT_SHA:0:8}
MACHINE_NAME=$(hostname -s)
log "at commit $COMMIT_SHORT"

log "xcodegen generate"
if command -v xcodegen &>/dev/null; then
  xcodegen generate 2>&1 | tail -3 || log "WARNING: xcodegen generate failed; using committed project"
else
  log "WARNING: xcodegen not found; using committed MobileCommander.xcodeproj"
fi

# --- 2. boot simulator -------------------------------------------------------
defaults write com.apple.iphonesimulator ShowSingleTouches -bool true
log "enabled simulator tap indicators (ShowSingleTouches)"

log "booting simulator: $SIMULATOR_NAME"
xcrun simctl boot "$SIMULATOR_NAME" 2>/dev/null || true

SIM_UDID=$(xcrun simctl list devices booted -j 2>/dev/null | node -e '
  const j = require("fs").readFileSync("/dev/stdin","utf-8");
  const d = JSON.parse(j).devices;
  for (const [rt, devs] of Object.entries(d)) {
    for (const dev of devs) {
      if (dev.name === "'"$SIMULATOR_NAME"'" && dev.state === "Booted") {
        process.stdout.write(dev.udid); process.exit(0);
      }
    }
  }
' 2>/dev/null || echo "")

if [ -n "$SIM_UDID" ]; then
  log "simulator booted: $SIMULATOR_NAME ($SIM_UDID)"
else
  log "WARNING: could not determine simulator UDID — video recording will be skipped"
fi

# --- 3. build for testing (once) ---------------------------------------------
log "xcodebuild build-for-testing"
BUILD_START=$(now_ms)
rm -rf "$UNIT_RESULT" "$SMOKE_RESULT" "$SCENARIOS_RESULT" 2>/dev/null || true

if ! xcodebuild build-for-testing \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    2>&1 | tee "$LOG_DIR/xcodebuild-build-$RUN_STAMP.log" | tail -20; then
  BUILD_MS=$(( $(now_ms) - BUILD_START ))
  log "ERROR: build-for-testing failed ($BUILD_MS ms) — publishing build-failure doc"
  FAILURE_STAGE="build"
  ERROR_MESSAGE="xcodebuild build-for-testing failed"
  export_publish_vars
  publish
  exit 1
fi
BUILD_MS=$(( $(now_ms) - BUILD_START ))
log "build succeeded in $(( BUILD_MS / 1000 ))s"

# --- 4. unit tests (MobileCommanderTests) ------------------------------------
# Hermetic (Swift Testing / XCTest, in-process) — no emulator, no video.
log "running unit tests (MobileCommanderTests)"
UNIT_START=$(now_ms)
xcodebuild test-without-building \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -derivedDataPath "$DERIVED_DATA" \
    -only-testing:MobileCommanderTests \
    -resultBundlePath "$UNIT_RESULT" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    2>&1 | tee "$LOG_DIR/xcodebuild-unit-$RUN_STAMP.log" | tail -30 || log "unit suite reported failures"
UNIT_MS=$(( $(now_ms) - UNIT_START ))
parse_xcresult "$UNIT_RESULT" "$UNIT_JSON" "$UNIT_MS"
[ -f "$UNIT_JSON" ] && UNIT_REPORT="$UNIT_JSON"
log "unit tests done (${UNIT_MS}ms)"

# --- 5. boot + seed the Firebase emulator (shared by smoke + scenario) -------
# Both UI phases drive the app under -UITEST, which points Firestore/Auth/Storage
# at the local emulator (TestConfig defaults: 8080/9099/9199). Boot it once, seed
# it, run both phases, then tear it down.
EMULATOR_READY=false
FIREBASE_CMD="$(firebase_cmd)"

if [ -z "$FIREBASE_CMD" ]; then
  log "WARNING: firebase CLI not found (firebase / npx firebase-tools) — skipping UI phases"
elif ! ensure_node_deps; then
  log "WARNING: firebase-admin not resolvable for seeding — skipping UI phases"
else
  for PORT in $FIRESTORE_PORT $AUTH_PORT $STORAGE_PORT; do
    if lsof -i ":$PORT" -t &>/dev/null; then
      log "port $PORT in use — killing existing process"
      lsof -i ":$PORT" -t | xargs kill -9 2>/dev/null || true
    fi
  done
  sleep 1

  log "starting Firebase emulators (auth, firestore, storage) for $PROJECT_ID"
  $FIREBASE_CMD emulators:start --only auth,firestore,storage --project "$PROJECT_ID" &
  EMULATOR_PID=$!
  log "emulator PID: $EMULATOR_PID"

  for i in $(seq 1 60); do
    if curl -s "http://$EMULATOR_HOST:$FIRESTORE_PORT/" >/dev/null 2>&1; then
      log "emulator ready after ${i}s"
      EMULATOR_READY=true
      break
    fi
    sleep 1
  done

  if [ "$EMULATOR_READY" = true ]; then
    log "seeding emulator"
    FIRESTORE_EMULATOR_HOST="$EMULATOR_HOST:$FIRESTORE_PORT" \
    FIREBASE_AUTH_EMULATOR_HOST="$EMULATOR_HOST:$AUTH_PORT" \
    FIREBASE_STORAGE_EMULATOR_HOST="$EMULATOR_HOST:$STORAGE_PORT" \
    GCLOUD_PROJECT="$PROJECT_ID" \
      node "$REPO_DIR/scripts/seed-emulator.mjs" 2>&1 || log "WARNING: emulator seeding failed"
  else
    log "ERROR: emulator did not start within 60s — UI phases will report no data"
  fi
fi

# --- 6. smoke tests (SignInUITests) ------------------------------------------
log "running smoke tests (SignInUITests)"
SMOKE_START=$(now_ms)
if [ "$EMULATOR_READY" = true ]; then
  SMOKE_VIDEO_EPOCH=$(now_sec)
  start_video "$SMOKE_VIDEO"
  xcodebuild test-without-building \
      -scheme "$SCHEME" \
      -destination "$DESTINATION" \
      -derivedDataPath "$DERIVED_DATA" \
      -only-testing:MobileCommanderUITests/SignInUITests \
      -resultBundlePath "$SMOKE_RESULT" \
      CODE_SIGN_IDENTITY="" \
      CODE_SIGNING_REQUIRED=NO \
      2>&1 | tee "$LOG_DIR/xcodebuild-smoke-$RUN_STAMP.log" | tail -30 || log "smoke suite reported failures"
  stop_video
else
  echo '{"passed":0,"total":0,"duration_ms":0,"failed":["emulator unavailable"]}' > "$SMOKE_JSON"
fi
SMOKE_MS=$(( $(now_ms) - SMOKE_START ))
[ -d "$SMOKE_RESULT" ] && parse_xcresult "$SMOKE_RESULT" "$SMOKE_JSON" "$SMOKE_MS"
[ -f "$SMOKE_JSON" ] && SMOKE_REPORT="$SMOKE_JSON"
log "smoke tests done (${SMOKE_MS}ms)"

SMOKE_TRIM_FILTER=""
if [ -d "$SMOKE_RESULT" ] && [ -f "$SMOKE_VIDEO" ] && [ -n "${SMOKE_VIDEO_EPOCH:-}" ]; then
  SMOKE_TRIM_FILTER=$(generate_trim_filter "$SMOKE_RESULT" "$SMOKE_VIDEO_EPOCH" "$SMOKE_VIDEO")
  [ -n "$SMOKE_TRIM_FILTER" ] && log "generated trim filter for smoke phase"
fi

# Export screenshot attachments from the smoke xcresult bundle.
SCREENSHOTS_JSON="[]"
SCREENSHOTS_DIR="$LOG_DIR/screenshots-$RUN_STAMP"
if [ -d "$SMOKE_RESULT" ]; then
  mkdir -p "$SCREENSHOTS_DIR"
  xcrun xcresulttool export --type attachments \
      --path "$SMOKE_RESULT" \
      --output-path "$SCREENSHOTS_DIR" 2>&1 || log "WARNING: screenshot export failed"
  SCREENSHOTS_JSON=$(node -e '
    const fs = require("fs"), path = require("path");
    const dir = process.argv[1];
    const out = [];
    try {
      for (const f of fs.readdirSync(dir).sort()) {
        const ext = path.extname(f).toLowerCase();
        if ([".png", ".jpg", ".jpeg"].includes(ext)) out.push({ name: f, path: path.join(dir, f) });
      }
    } catch {}
    process.stdout.write(JSON.stringify(out));
  ' "$SCREENSHOTS_DIR" 2>/dev/null || echo "[]")
  NUM_SHOTS=$(echo "$SCREENSHOTS_JSON" | node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync("/dev/stdin","utf-8")).length))' 2>/dev/null || echo 0)
  log "exported $NUM_SHOTS screenshot(s) from smoke results"
fi

# --- 7. scenario tests (ChatUITests + ChatScenarioUITests) -------------------
log "running scenario tests (ChatUITests + ChatScenarioUITests)"
SCEN_START=$(now_ms)
if [ "$EMULATOR_READY" = true ]; then
  SCENARIOS_VIDEO_EPOCH=$(now_sec)
  start_video "$SCENARIOS_VIDEO"
  xcodebuild test-without-building \
      -scheme "$SCHEME" \
      -destination "$DESTINATION" \
      -derivedDataPath "$DERIVED_DATA" \
      -only-testing:MobileCommanderUITests/ChatUITests \
      -only-testing:MobileCommanderUITests/ChatScenarioUITests \
      -resultBundlePath "$SCENARIOS_RESULT" \
      CODE_SIGN_IDENTITY="" \
      CODE_SIGNING_REQUIRED=NO \
      2>&1 | tee "$LOG_DIR/xcodebuild-scenarios-$RUN_STAMP.log" | tail -30 || log "scenario suite reported failures"
  stop_video
else
  echo '{"passed":0,"total":0,"duration_ms":0,"failed":["emulator unavailable"]}' > "$SCENARIOS_JSON"
fi
SCEN_MS=$(( $(now_ms) - SCEN_START ))
[ -d "$SCENARIOS_RESULT" ] && parse_xcresult "$SCENARIOS_RESULT" "$SCENARIOS_JSON" "$SCEN_MS"
[ -f "$SCENARIOS_JSON" ] && SCEN_REPORT="$SCENARIOS_JSON"
log "scenario tests done (${SCEN_MS}ms)"

SCENARIOS_TRIM_FILTER=""
if [ -d "$SCENARIOS_RESULT" ] && [ -f "$SCENARIOS_VIDEO" ] && [ -n "${SCENARIOS_VIDEO_EPOCH:-}" ]; then
  SCENARIOS_TRIM_FILTER=$(generate_trim_filter "$SCENARIOS_RESULT" "$SCENARIOS_VIDEO_EPOCH" "$SCENARIOS_VIDEO")
  [ -n "$SCENARIOS_TRIM_FILTER" ] && log "generated trim filter for scenarios phase"
fi

# --- 8. tear down emulator ---------------------------------------------------
if [ -n "$EMULATOR_PID" ] && kill -0 "$EMULATOR_PID" 2>/dev/null; then
  log "stopping Firebase emulators"
  kill "$EMULATOR_PID" 2>/dev/null || true
  wait "$EMULATOR_PID" 2>/dev/null || true
  EMULATOR_PID=""
fi

# --- 9. trim, caption, and concat per-phase video clips via ffmpeg -----------
log "collecting per-phase video clips"
CLIP_DIR="$LOG_DIR/clips-$RUN_STAMP"
mkdir -p "$CLIP_DIR"
VIDEOS_JSON="[]"
COMBINED_OUT=""

export SMOKE_VIDEO SCENARIOS_VIDEO CLIP_DIR
VIDEO_COLLECTOR="/tmp/mc-collect-videos-$RUN_STAMP.js"
cat > "$VIDEO_COLLECTOR" <<'NODESCRIPT'
const fs = require("fs"), path = require("path");
const clips = [
  { src: process.env.SMOKE_VIDEO, name: "02-smoke.mp4" },
  { src: process.env.SCENARIOS_VIDEO, name: "03-scenarios.mp4" },
];
const out = [];
for (const clip of clips) {
  if (!clip.src || !fs.existsSync(clip.src)) continue;
  if (fs.statSync(clip.src).size < 1024) continue;
  const dest = path.join(process.env.CLIP_DIR, clip.name);
  fs.copyFileSync(clip.src, dest);
  out.push({ name: clip.name, path: dest });
}
process.stderr.write("found " + out.length + " phase video(s)\n");
process.stdout.write(JSON.stringify(out));
NODESCRIPT

node "$VIDEO_COLLECTOR" 1>/tmp/mc-videos-$RUN_STAMP.json || true
VIDEOS_JSON=$(cat /tmp/mc-videos-$RUN_STAMP.json 2>/dev/null || echo "[]")
rm -f "$VIDEO_COLLECTOR" /tmp/mc-videos-$RUN_STAMP.json

NUM_CLIPS=$(echo "$VIDEOS_JSON" | node -e 'process.stdout.write(String(JSON.parse(require("fs").readFileSync("/dev/stdin","utf-8")).length))' 2>/dev/null || echo 0)
log "found $NUM_CLIPS phase video(s)"

if [ "${NUM_CLIPS:-0}" -gt 0 ] && command -v ffmpeg >/dev/null 2>&1; then
  CAPTION_FONT="/System/Library/Fonts/Helvetica.ttc"
  [ -f "$CAPTION_FONT" ] || CAPTION_FONT="/System/Library/Fonts/Monaco.ttf"

  SCENARIOS_CAPTIONS="$CLIP_DIR/scenarios-captions.txt"
  [ -d "$SCENARIOS_RESULT" ] && generate_captions "$SCENARIOS_RESULT" "$SCENARIOS_CAPTIONS" "$CAPTION_FONT"
  SMOKE_CAPTIONS="$CLIP_DIR/smoke-captions.txt"
  [ -d "$SMOKE_RESULT" ] && generate_captions "$SMOKE_RESULT" "$SMOKE_CAPTIONS" "$CAPTION_FONT"

  PROCESSED_CONCAT="$CLIP_DIR/processed-concat.txt"
  : > "$PROCESSED_CONCAT"

  caption_clip() {
    local src="$1" dst="$2" label="$3" captions="${4:-}" trim_filter="${5:-}"
    local drawtext="drawtext=fontfile='${CAPTION_FONT}':text='${label}':fontsize=36:fontcolor=white:box=1:boxcolor=black@0.7:boxborderw=10:x=(w-text_w)/2:y=30:enable='lt(t,2)'"
    local vf=""
    [ -n "$trim_filter" ] && vf="${trim_filter},"
    vf="${vf}${drawtext}"
    if [ -n "$captions" ] && [ -f "$captions" ]; then
      vf="${vf},$(cat "$captions")"
    fi
    if ffmpeg -y -hide_banner -loglevel error -i "$src" -vf "$vf" \
         -c:v libx264 -preset fast -crf 23 "$dst" 2>&1; then
      return 0
    fi
    log "WARNING: captioned encode failed for $(basename "$src"); using original"
    cp "$src" "$dst"
  }

  PHASE_CLIPS=("02-smoke.mp4" "03-scenarios.mp4")
  PHASE_LABELS=("Smoke — sign-in & chat boot" "Scenarios — reply-to + @emma auto-tag")

  for idx in 0 1; do
    CLIP_SRC="$CLIP_DIR/${PHASE_CLIPS[$idx]}"
    CLIP_DST="$CLIP_DIR/captioned-${PHASE_CLIPS[$idx]}"
    [ -f "$CLIP_SRC" ] || continue
    CAPTIONS_ARG=""
    TRIM_ARG=""
    if [ "$idx" -eq 0 ]; then
      [ -f "$SMOKE_CAPTIONS" ] && CAPTIONS_ARG="$SMOKE_CAPTIONS"
      TRIM_ARG="${SMOKE_TRIM_FILTER:-}"
    else
      [ -f "$SCENARIOS_CAPTIONS" ] && CAPTIONS_ARG="$SCENARIOS_CAPTIONS"
      TRIM_ARG="${SCENARIOS_TRIM_FILTER:-}"
    fi
    caption_clip "$CLIP_SRC" "$CLIP_DST" "${PHASE_LABELS[$idx]}" "$CAPTIONS_ARG" "$TRIM_ARG"
    log "captioned ${PHASE_CLIPS[$idx]}"
    ESCAPED_DST="${CLIP_DST//\'/\'\\\'\'}"
    echo "file '${ESCAPED_DST}'" >> "$PROCESSED_CONCAT"
  done

  if [ -s "$PROCESSED_CONCAT" ]; then
    log "concatenating captioned clips → $COMBINED_VIDEO"
    if ffmpeg -y -hide_banner -loglevel error -f concat -safe 0 -i "$PROCESSED_CONCAT" \
         -c copy "$COMBINED_VIDEO" 2>&1; then
      COMBINED_OUT="$COMBINED_VIDEO"
      log "combined video written ($(du -h "$COMBINED_VIDEO" 2>/dev/null | cut -f1))"
    elif ffmpeg -y -hide_banner -loglevel error -f concat -safe 0 -i "$PROCESSED_CONCAT" \
         -c:v libx264 -preset fast -crf 23 "$COMBINED_VIDEO" 2>&1; then
      COMBINED_OUT="$COMBINED_VIDEO"
      log "combined video written via re-encode"
    else
      log "WARNING: ffmpeg concat failed; uploading individual clips only"
    fi
  fi
elif [ "${NUM_CLIPS:-0}" -gt 0 ]; then
  log "WARNING: ffmpeg not found on PATH; uploading individual clips only"
fi

# --- 10. publish -------------------------------------------------------------
export_publish_vars
publish

RUN_END_MS=$(now_ms)
log "MobileCommander iOS E2E run finished in $(( (RUN_END_MS - RUN_START_MS) / 1000 ))s"
log "=============================================================="
