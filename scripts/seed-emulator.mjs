// Seed the Firebase Local Emulator Suite with the fixtures the iOS E2E tests
// expect, mirroring the web e2e seed: an allowlist, a roster with presence, a
// #general channel, and a couple of tasks. Run inside `firebase emulators:exec`
// so FIRESTORE_EMULATOR_HOST is set. Uses the admin SDK (bypasses rules).
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

// Defaults to the app's Firebase project (Resources/GoogleService-Info.plist) so
// a standalone `node seed-emulator.mjs` (with FIRESTORE_EMULATOR_HOST set) writes
// to the same emulator namespace the iOS app reads. The runner exports
// GCLOUD_PROJECT to override.
const PROJECT_ID = process.env.GCLOUD_PROJECT || 'fir-web-codelab-8ace9';
initializeApp({ projectId: PROJECT_ID });
const db = getFirestore();

const docId = (email) => email.toLowerCase().replace(/[.@]/g, '_');

async function seed() {
  // Allowlist / roster.
  const people = [
    { email: 'test@palmr.ai', name: 'Test User', isAdmin: true, projects: null },
    { email: 'tim@palmr.ai', name: 'Tim', isAdmin: false, projects: ['palmr-ios'] },
    { email: 'jing@palmr.ai', name: 'Jing', isAdmin: false, projects: ['palmr-ios'] },
  ];
  for (const p of people) {
    await db.collection('commander_allowed_users').doc(docId(p.email)).set(p);
  }

  // Presence: Tim online, Jing stale (offline).
  await db.collection('commander_presence').doc('tim-uid').set({
    email: 'tim@palmr.ai', displayName: 'Tim', online: true, lastSeen: FieldValue.serverTimestamp(),
  });
  await db.collection('commander_presence').doc('jing-uid').set({
    email: 'jing@palmr.ai', displayName: 'Jing', online: true,
    lastSeen: new Date(Date.now() - 10 * 60 * 1000), // 10 min ago → offline
  });

  // #general channel with a seeded thread. We use explicit, monotonically
  // increasing timestamps (rather than serverTimestamp) so the message order is
  // deterministic for the reply-to scenario test: Tim's human message first,
  // then Emma's bot message. The scenario replies to each to verify @emma is
  // auto-tagged for the bot reply but NOT for the human reply (#811/#835).
  const t0 = new Date(Date.now() - 5 * 60 * 1000); // 5 min ago
  const t1 = new Date(Date.now() - 4 * 60 * 1000); // 4 min ago
  await db.collection('commander_channels').doc('general').set({
    name: 'general', isPublic: true, members: [],
    createdBy: 'test@palmr.ai', createdAt: FieldValue.serverTimestamp(),
    lastMessageAt: t1,
  });
  const messages = db.collection('commander_channels').doc('general').collection('messages');
  // Human message — replying to this must NOT auto-tag @emma.
  await messages.add({
    type: 'text', text: 'Welcome to Commander chat!',
    authorUid: 'tim-uid', authorName: 'Tim', authorEmail: 'tim@palmr.ai',
    isBot: false, createdAt: t0,
  });
  // Emma (bot) message — replying to this MUST auto-tag @emma. Kept emoji-free so
  // XCUITest can match the bubble by its exact accessibility label.
  await messages.add({
    type: 'text', text: 'Build 20260625 is green across the fleet',
    authorUid: 'emma-bot', authorName: 'Emma', authorEmail: 'emma@palmr.ai',
    isBot: true, createdAt: t1,
  });

  // Repo registry + a couple of tasks so Emma has projects to infer.
  await db.collection('commander_repo_registry').doc('palmr-ios').set({
    name: 'palmr-ios', path: '~/repos/palmr-ios', default_branch: 'main',
  });
  await db.collection('commander_tasks').add({
    num_id: 1, project: 'palmr-ios', path: '~/repos/palmr-ios',
    task: 'Seeded task', status: 'running', created_at: FieldValue.serverTimestamp(),
  });

  // A reel "released" to the test user — the exact shape manage.everbot.org's
  // Reels "Release to app" action writes, so the Videos tab has something to show.
  await db.collection('commander_videos').doc('reel_seed_1').set({
    kind: 'reel',
    video_url: 'https://storage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    storage_path: null,
    title: 'MMA Night — Fighter Reel',
    thumbnail_url: 'https://storage.googleapis.com/gtv-videos-bucket/sample/images/ForBiggerJoyrides.jpg',
    duration_seconds: 65,
    project: 'mobile commander',
    source_url: 'https://manage.everbot.org/',
    assigned_emails: ['test@palmr.ai'],
    released_by: 'seed@palmr.ai',
    created_at: FieldValue.serverTimestamp(),
    updated_at: FieldValue.serverTimestamp(),
  });

  console.log(`Seeded emulator project ${PROJECT_ID}.`);
}

seed().then(() => process.exit(0)).catch((err) => { console.error(err); process.exit(1); });
