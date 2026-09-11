#!/usr/bin/env node
/**
 * upload-test-run.cjs — Drive upload + Firestore write for a MobileCommander iOS
 * E2E run.
 *
 * Invoked by run-ios-e2e-and-publish.sh with a path to a manifest JSON. The bash
 * orchestrator runs xcodebuild, records simulator video, and parses xcresult
 * bundles into per-phase summary JSONs. This script reads those summaries,
 * uploads videos + screenshots to Drive, and writes the `test_runs` Firestore doc
 * the dashboard project tab reads (commander/src/testRuns.js → normalizeRun).
 *
 * Adapted from palmr-coach-ios/scripts/upload-test-run.cjs so MobileCommander's
 * runs render in the Emma dashboard exactly like Palmr Coach's do.
 *
 * firebase-admin + the service-account key are reused from the commander worker
 * install on the same machine (~/repos/experimental/commander/worker).
 *
 * Usage:
 *   node upload-test-run.cjs <manifest.json>
 *   node upload-test-run.cjs <manifest.json> --dry-run
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const COMMANDER_WORKER_DIR =
  process.env.COMMANDER_WORKER_DIR ||
  path.join(os.homedir(), 'repos/experimental/commander/worker');

// Same shared Drive user as the other Palmr E2E publishers (WebPT / Coach).
const DRIVE_UID =
  process.env.PALMR_E2E_DRIVE_UID || '0JjNEqCqlIPfayo94D8vuSxYUjF3';

// Display label for the Drive folder tree.
const DRIVE_ROOT_FOLDER =
  process.env.MC_DRIVE_FOLDER || 'MobileCommander iOS E2E';

// Default project name — must match how MobileCommander tasks are filed so the
// run shows under the same project tab (TASK_CONTEXT.md: "mobile commander").
const DEFAULT_PROJECT = process.env.MC_PROJECT_NAME || 'mobile commander';

const args = process.argv.slice(2);
const DRY_RUN = args.includes('--dry-run');
const manifestPath = args.find((a) => !a.startsWith('--'));

if (!manifestPath) {
  console.error('[upload-test-run] usage: node upload-test-run.cjs <manifest.json> [--dry-run]');
  process.exit(2);
}

const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf-8'));

// ---------------------------------------------------------------------------
// Summary JSON parsing (pre-parsed by the bash runner from xcresult bundles)
// ---------------------------------------------------------------------------

function parseSummary(reportPath, fallbackDurationMs) {
  if (!reportPath || !fs.existsSync(reportPath)) return null;
  let data;
  try {
    data = JSON.parse(fs.readFileSync(reportPath, 'utf-8'));
  } catch (e) {
    console.error(`[upload-test-run] could not parse summary ${reportPath}: ${e.message}`);
    return null;
  }
  const passed = data.passed || 0;
  const total = data.total || 0;
  const duration_ms = data.duration_ms || fallbackDurationMs || 0;
  const failed = Array.isArray(data.failed) ? data.failed : [];
  return { passed, total, duration_ms: Math.round(duration_ms), failed };
}

// ---------------------------------------------------------------------------
// Drive (factored from commander/worker/drive-upload.js)
// ---------------------------------------------------------------------------

const MIME_TYPES = {
  '.webm': 'video/webm',
  '.mp4': 'video/mp4',
  '.mov': 'video/quicktime',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
};

async function refreshToken(refresh_token, client_id, client_secret) {
  const resp = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id,
      client_secret,
      refresh_token,
      grant_type: 'refresh_token',
    }),
  });
  if (!resp.ok) {
    throw new Error(`token refresh failed: ${await resp.text()}`);
  }
  const data = await resp.json();
  return data.access_token;
}

async function getUserAccessToken(db, uid) {
  const doc = await db.collection('commander_user_drive').doc(uid).get();
  if (!doc.exists) throw new Error(`commander_user_drive/${uid} not found`);
  const { refresh_token, client_id, client_secret, status } = doc.data();
  if (status !== 'connected' || !refresh_token || !client_id || !client_secret) {
    throw new Error(`Drive for uid ${uid} is not connected`);
  }
  return refreshToken(refresh_token, client_id, client_secret);
}

async function getOrCreateFolder(accessToken, folderName, parentId = null) {
  const safeName = folderName.replace(/'/g, "\\'");
  let q = `name='${safeName}' and mimeType='application/vnd.google-apps.folder' and trashed=false`;
  if (parentId) q += ` and '${parentId}' in parents`;

  const searchResp = await fetch(
    `https://www.googleapis.com/drive/v3/files?q=${encodeURIComponent(q)}&fields=files(id,name)`,
    { headers: { Authorization: `Bearer ${accessToken}` } }
  );
  const searchData = await searchResp.json();
  if (searchData.files && searchData.files.length > 0) return searchData.files[0].id;

  const metadata = { name: folderName, mimeType: 'application/vnd.google-apps.folder' };
  if (parentId) metadata.parents = [parentId];
  const createResp = await fetch('https://www.googleapis.com/drive/v3/files', {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(metadata),
  });
  const folder = await createResp.json();
  if (!folder.id) throw new Error(`folder create failed: ${JSON.stringify(folder)}`);
  return folder.id;
}

async function uploadFile(accessToken, filePath, folderId, displayName) {
  const ext = path.extname(filePath).toLowerCase();
  const mimeType = MIME_TYPES[ext] || 'application/octet-stream';
  const fileName = displayName || path.basename(filePath);
  const fileContent = fs.readFileSync(filePath);

  const boundary = 'mobilecommander_ios_e2e_upload_boundary';
  const metadata = JSON.stringify({ name: fileName, parents: [folderId] });
  const body = Buffer.concat([
    Buffer.from(
      `--${boundary}\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n${metadata}\r\n` +
        `--${boundary}\r\nContent-Type: ${mimeType}\r\n\r\n`
    ),
    fileContent,
    Buffer.from(`\r\n--${boundary}--`),
  ]);

  const resp = await fetch(
    'https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&fields=id,name,webViewLink',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${accessToken}`,
        'Content-Type': `multipart/related; boundary=${boundary}`,
      },
      body,
    }
  );
  if (!resp.ok) throw new Error(`upload failed for ${fileName}: ${await resp.text()}`);
  const file = await resp.json();

  await fetch(`https://www.googleapis.com/drive/v3/files/${file.id}/permissions`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${accessToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ role: 'reader', type: 'anyone' }),
  });

  let url = file.webViewLink;
  if (!url) {
    const metaResp = await fetch(
      `https://www.googleapis.com/drive/v3/files/${file.id}?fields=id,name,webViewLink`,
      { headers: { Authorization: `Bearer ${accessToken}` } }
    );
    url = (await metaResp.json()).webViewLink;
  }
  return { name: fileName, url };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

(async () => {
  const projectName = manifest.project || DEFAULT_PROJECT;
  const reports = manifest.reports || {};
  const measured = manifest.measured || {};
  const unit = parseSummary(reports.unit, measured.unit_ms);
  const smoke = parseSummary(reports.smoke, measured.smoke_ms);
  const scenarios = parseSummary(reports.scenarios, measured.scenarios_ms);

  const failed_specs = [
    ...(unit ? unit.failed : []),
    ...(smoke ? smoke.failed : []),
    ...(scenarios ? scenarios.failed : []),
  ];

  const installFailed = !!manifest.failure_stage;
  const suiteAllGreen = (s) => s && s.total > 0 && s.passed === s.total && s.failed.length === 0;
  const all_green = Boolean(
    !installFailed &&
    suiteAllGreen(unit) &&
    suiteAllGreen(smoke) &&
    suiteAllGreen(scenarios) &&
    failed_specs.length === 0
  );

  const blankSuite = { passed: 0, total: 0, duration_ms: 0 };
  const slim = (s) =>
    s ? { passed: s.passed, total: s.total, duration_ms: s.duration_ms } : { ...blankSuite };

  // Top-level unit/smoke/scenarios shape — normalizeRun() reads either this or a
  // nested `suites` object; the webpt + coach runners both write top-level.
  const doc = {
    project: projectName,
    branch: manifest.branch || 'main',
    commit_sha: manifest.commit_sha || null,
    commit_short: manifest.commit_short || null,
    unit: slim(unit),
    smoke: slim(smoke),
    scenarios: slim(scenarios),
    all_green,
    machine: manifest.machine || os.hostname(),
    duration_ms: manifest.duration_ms || 0,
    failed_specs,
  };
  if (manifest.failure_stage) {
    doc.failure_stage = manifest.failure_stage;
    doc.error_message = manifest.error_message || null;
  }

  console.log(
    `[upload-test-run] parsed: unit ${doc.unit.passed}/${doc.unit.total}, ` +
      `smoke ${doc.smoke.passed}/${doc.smoke.total}, ` +
      `scenarios ${doc.scenarios.passed}/${doc.scenarios.total}, ` +
      `all_green=${all_green}` +
      (failed_specs.length ? `, failures: ${failed_specs.join('; ')}` : '')
  );

  // ----- Drive upload (best-effort) -----
  const videos = Array.isArray(manifest.individual_videos) ? manifest.individual_videos : [];
  const combinedVideo = manifest.combined_video;
  const screenshots = Array.isArray(manifest.screenshots) ? manifest.screenshots : [];
  const canUpload = !installFailed && (combinedVideo || videos.length > 0 || screenshots.length > 0);

  if (DRY_RUN) {
    console.log('[upload-test-run] --dry-run: skipping Drive + Firestore. Doc would be:');
    console.log(JSON.stringify({ ...doc, project: projectName }, null, 2));
    console.log(
      `[upload-test-run] would upload ${videos.length} clips` +
        (combinedVideo ? ' + 1 combined video' : '') +
        (screenshots.length ? ` + ${screenshots.length} screenshots` : '') +
        ` under "${DRIVE_ROOT_FOLDER}", write test_runs + projects/${projectName}`
    );
    return;
  }

  // firebase-admin + service account from commander worker install
  let admin, db, FieldValue;
  try {
    admin = require(path.join(COMMANDER_WORKER_DIR, 'node_modules', 'firebase-admin'));
    const saPath = path.join(COMMANDER_WORKER_DIR, 'serviceAccountKey.json');
    const sa = require(saPath);
    if (!admin.apps.length) {
      admin.initializeApp({ credential: admin.credential.cert(sa) });
    }
    db = admin.firestore();
    db.settings({ ignoreUndefinedProperties: true });
    FieldValue = admin.firestore.FieldValue;
  } catch (e) {
    console.error(`[upload-test-run] FATAL: cannot init firebase-admin from ${COMMANDER_WORKER_DIR}: ${e.message}`);
    process.exit(3);
  }

  if (canUpload) {
    try {
      const accessToken = await getUserAccessToken(db, DRIVE_UID);
      const now = new Date();
      const dateStr = now.toISOString().slice(0, 10);
      const timeStr = now.toTimeString().slice(0, 5);

      const rootFolderId = await getOrCreateFolder(accessToken, DRIVE_ROOT_FOLDER);
      const dateFolderId = await getOrCreateFolder(accessToken, dateStr, rootFolderId);
      const runFolderId = await getOrCreateFolder(accessToken, `${timeStr} run`, dateFolderId);
      doc.drive_folder_url = `https://drive.google.com/drive/folders/${runFolderId}`;

      if (combinedVideo && fs.existsSync(combinedVideo)) {
        const stamp = (manifest.commit_short || 'run') + '-' + (manifest.run_stamp || '');
        const combined = await uploadFile(
          accessToken,
          combinedVideo,
          runFolderId,
          `mobile-commander-combined-${stamp}.mp4`.replace(/-+\.mp4$/, '.mp4')
        );
        doc.combined_video_url = combined.url;
        console.log(`[upload-test-run] uploaded combined video → ${combined.url}`);
      }

      const individual_videos = [];
      for (let i = 0; i < videos.length; i++) {
        const v = videos[i];
        const p = v.path;
        if (!p || !fs.existsSync(p)) continue;
        const label = v.name || `phase-${i + 1}.mp4`;
        const up = await uploadFile(accessToken, p, runFolderId, label);
        individual_videos.push(up);
        console.log(`[upload-test-run] uploaded clip ${label} → ${up.url}`);
      }
      doc.individual_videos = individual_videos;

      if (screenshots.length > 0) {
        const shotsFolderId = await getOrCreateFolder(accessToken, 'screenshots', runFolderId);
        const uploaded_screenshots = [];
        for (const s of screenshots) {
          if (!s.path || !fs.existsSync(s.path)) continue;
          const up = await uploadFile(accessToken, s.path, shotsFolderId, s.name || path.basename(s.path));
          uploaded_screenshots.push(up);
          console.log(`[upload-test-run] uploaded screenshot ${up.name} → ${up.url}`);
        }
        doc.screenshots = uploaded_screenshots;
      }
    } catch (e) {
      console.error(`[upload-test-run] Drive upload failed: ${e.message}`);
      doc.drive_failure = e.message;
      doc.individual_videos = doc.individual_videos || [];
    }
  } else {
    doc.individual_videos = [];
  }

  // ----- Firestore write -----
  doc.timestamp = FieldValue.serverTimestamp();
  const ref = await db.collection('test_runs').add(doc);
  console.log(`[upload-test-run] wrote test_runs/${ref.id}`);

  const latest = { ...doc, test_run_id: ref.id };
  delete latest.timestamp;
  latest.updated_at = FieldValue.serverTimestamp();
  await db
    .collection('projects')
    .doc(projectName)
    .set(
      { name: projectName, latest_test_run: latest, latest_test_run_at: FieldValue.serverTimestamp() },
      { merge: true }
    );
  console.log(`[upload-test-run] updated projects/${projectName}.latest_test_run`);

  await admin.app().delete().catch(() => {});
})().catch((e) => {
  console.error(`[upload-test-run] FATAL: ${e.stack || e.message}`);
  process.exit(1);
});
