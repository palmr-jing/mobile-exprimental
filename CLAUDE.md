# MobileCommander — native Emma iOS app

The native iOS client for Emma / the Palmr commander fleet (bundle id **`ai.palmr.emma`**,
App Store Connect app id `6780673334`). SwiftUI app: Ask-Emma chat, Videos (recordings +
reels), task/issue reporting. Ships to testers via **TestFlight**.

## Stack

- **SwiftUI**, Swift Testing (unit) + **XCUITest** (UI/E2E).
- **xcodegen** — the Xcode project is generated from `project.yml`; `MobileCommander.xcodeproj`
  is a build artifact.
- **Firebase** (Auth + Firestore + Storage), project `fir-web-codelab-8ace9` (shared with the
  rest of Palmr; hardwired in `GoogleService-Info.plist`).

## ⚠️ Local testing is REQUIRED before every TestFlight upload

**Never `scripts/upload-testflight.sh` without first running the test suite on the iOS
Simulator and seeing it pass.** A TestFlight round-trip is slow and expensive — archive +
Apple processing (minutes-to-hours) + on-device install — and it burns a build number. Any
bug a simulator test can catch **must** be caught locally first. (2026-07-17, #1049: a
reel-format fix was uploaded to TestFlight straight from the worker's `test_status` without a
local sim run, even though a UITest that reproduces the exact behavior already existed. The
user had to discover it worked by installing the build. Don't do that — run the test locally.)

### The workflow

```sh
# 1. Regenerate the project if any files were ADDED/REMOVED (see xcodegen gotcha below).
xcodegen generate

# 2. Run the suites on the simulator. Default destination is iPhone 17 Pro.
scripts/run-tests.sh                 # unit (Swift Testing) + UITests (XCUITest under emulator)
SKIP_EMULATOR=1 scripts/run-tests.sh # unit tests only (hermetic, fast)
DEST="platform=iOS Simulator,name=iPad Air 11-inch (M4)" scripts/run-tests.sh  # test on the iPad

# 3. ONLY after the suite passes locally: archive + upload.
ASC_ISSUER_ID=<uuid> scripts/upload-testflight.sh
```

### Running UITests without the Firebase emulator

`run-tests.sh` runs the XCUITests under the Firebase Local Emulator Suite, which needs the
`firebase` CLI on `PATH`. **It is not installed globally on this machine** (we use
`npx firebase-tools` for deploys) — so `run-tests.sh` silently **skips** the UITests when
`firebase` isn't found and runs unit tests only. To actually run UITests either
`npm i -g firebase-tools`, or run the mock-seam UITests directly (no emulator needed):

```sh
# UITests driven by launch-arg mock fixtures (-UITEST -MOCK_VIDEOS) need NO live data.
xcodebuild test -scheme MobileCommander \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:MobileCommanderUITests/VideosUITests
```

**Prefer a mock-seam UITest that reproduces the bug offline** (like #1049's
`VideosUITests.testUnsupportedFormatReelShowsMessage`, which injects a WebM "Reel · N clips"
fixture via `-MOCK_VIDEOS` and asserts the failure message) so the behavior is verifiable on
the simulator without live Firestore/Storage — that is the test that lets you validate a
change locally before TestFlight.

## TestFlight

`scripts/upload-testflight.sh` does xcodegen → archive (Release, automatic signing) → export
→ `altool` validate → upload. Requires `ASC_ISSUER_ID` (in this machine's shell env), the
signing keychain (`~/Library/Keychains/palmr-signing.keychain-db`, unlocked by the script),
and the ASC key (`~/.appstoreconnect/private_keys/AuthKey_99L2CGPPWK.p8`).

- **Bump the build number** before uploading: `CURRENT_PROJECT_VERSION` in `project.yml` is a
  date stamp `YYYYMMDD.N` (e.g. `20260717.1`). Two uploads with the same build number are
  rejected. Commit the bump to `main`.
- After upload the build shows `processingState=PROCESSING` then `VALID` in App Store Connect
  (minutes). Query with `node scripts/asc.mjs GET "/v1/builds?filter[app]=6780673334&sort=-uploadedDate&fields[builds]=version,processingState"`.
- **Internal testers get every processed build automatically.** You do **not** (and cannot)
  assign a build to the internal "Beta Testers" group via the API — `POST .../betaGroups/<id>/relationships/builds`
  returns 422 "Cannot add internal group to a build." Once the build is `VALID`, refresh the
  TestFlight app. Export compliance is already `usesNonExemptEncryption=false`, so there's no
  "Missing Compliance" gate.

## Gotchas

- **xcodegen**: any **new** Swift file must be added to the build with `xcodegen generate`
  before it compiles — otherwise it's silently absent and you install a stale app. Modifying
  existing files doesn't require a regen, but running it is harmless.
- Piping `xcodebuild` through `| tail`/`| grep` can **mask a build failure** (grep exits 0);
  check `${PIPESTATUS[0]}` or read the full log when a run "passes" suspiciously fast.
- The app is hardwired to Firebase project `fir-web-codelab-8ace9`; the emulator + seed must
  run under the same id or every Firestore-backed UITest fails with a stream error.
- Reports from this app's "Report an issue" go **directly to `commander_tasks`**, not the
  `issue_reports` inbox (see `Sources/Views/Support/ReportIssue.swift`).
