// Seed the Firebase Local Emulator Suite with the fixtures the iOS E2E tests
// expect, mirroring the web e2e seed: an allowlist, a roster with presence, a
// #general channel, and a couple of tasks. Run inside `firebase emulators:exec`
// so FIRESTORE_EMULATOR_HOST is set. Uses the admin SDK (bypasses rules).
import { initializeApp } from 'firebase-admin/app';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';

const PROJECT_ID = process.env.GCLOUD_PROJECT || 'demo-commander';
initializeApp({ projectId: PROJECT_ID });
const db = getFirestore();

const docId = (email) => email.toLowerCase().replace(/[.@]/g, '_');

async function seed() {
  // Allowlist / roster.
  const people = [
    { email: 'test@palmr.ai', name: 'Test User', isAdmin: true, projects: null },
    { email: 'tim@palmr.ai', name: 'Tim', isAdmin: false, projects: ['palmr-ios'] },
    { email: 'jing@palmr.ai', name: 'Jing', isAdmin: false, projects: ['palmr-ios'] },
    // Dan has the "dan" sandbox project (https://manage.everbot.org/dan) —
    // grant applied via scripts/grant-project-access.mjs.
    { email: 'dan@palmr.ai', name: 'Dan', isAdmin: false, projects: ['dan'] },
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

  // #general channel with one message.
  await db.collection('commander_channels').doc('general').set({
    name: 'general', isPublic: true, members: [],
    createdBy: 'test@palmr.ai', createdAt: FieldValue.serverTimestamp(),
    lastMessageAt: FieldValue.serverTimestamp(),
  });
  await db.collection('commander_channels').doc('general').collection('messages').add({
    type: 'text', text: 'Welcome to Commander chat!',
    authorUid: 'tim-uid', authorName: 'Tim', authorEmail: 'tim@palmr.ai',
    isBot: false, createdAt: FieldValue.serverTimestamp(),
  });

  // Repo registry + a couple of tasks so Emma has projects to infer.
  await db.collection('commander_repo_registry').doc('palmr-ios').set({
    name: 'palmr-ios', path: '~/repos/palmr-ios', default_branch: 'main',
  });
  await db.collection('commander_repo_registry').doc('dan').set({
    name: 'dan', path: '~/repos/dan', default_branch: 'main',
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
