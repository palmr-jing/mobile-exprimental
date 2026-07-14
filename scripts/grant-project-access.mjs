// Grant a user access to a project in the Commander allowlist.
//
// Access lives in Firestore `commander_allowed_users`, doc id = email with `.`
// and `@` replaced by `_`, shape `{ email, name, isAdmin, projects }`. The iOS
// app (and the web commander) READ this to scope what a user can see; it is the
// UI-side mirror of the backend boundary. There is deliberately no in-app editor
// for it — grants are an operator action, which is what this script performs.
//
//   projects == null  → unrestricted (every project)
//   projects == ['*'] → unrestricted
//   projects == [...] → limited to the named projects
//
// The <project> argument is the project's slug — the same segment the web
// console uses in its URL, e.g. https://manage.everbot.org/dan → slug "dan".
//
// Usage (production — needs Firebase Admin credentials for the target project):
//   GOOGLE_APPLICATION_CREDENTIALS=~/keys/fir-web-codelab-8ace9.json \
//     node scripts/grant-project-access.mjs dan@everbot.org dan
//
// Against the local emulator (no credentials needed):
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-commander \
//     node scripts/grant-project-access.mjs dan@palmr.ai dan
//
// The write is idempotent and never *narrows* access: a user who is already an
// admin or already unrestricted is left untouched (adding a scoped project to
// them would otherwise strip their access to everything else).

// Default target: Emma's production Firebase project (see Resources/GoogleService-Info.plist).
const DEFAULT_PROJECT_ID = 'fir-web-codelab-8ace9';

/** commander_allowed_users doc id for an email (matches Access.emailToDocId + the web backend). */
export function docId(email) {
  return email.toLowerCase().replace(/[.@]/g, '_');
}

/** Title-case the local-part of an email as a fallback display name ("dan@palmr.ai" → "Dan"). */
export function nameFromEmail(email) {
  const local = email.split('@')[0] || email;
  return local.charAt(0).toUpperCase() + local.slice(1);
}

/**
 * Decide how to grant `project` to a user given their existing allowlist doc
 * (`existing` is the Firestore document data, or null if the doc is absent).
 * Pure — no Firestore, no side effects — so it is unit-testable in isolation.
 *
 * Returns { op, message, data? }:
 *   op 'create' → no doc yet; write `data` as a new doc.
 *   op 'merge'  → doc exists; merge `data` (only `projects`) into it.
 *   op 'skip'   → user already has access; do nothing.
 */
export function planGrant(existing, { email, name, project }) {
  if (!email) throw new Error('email is required');
  if (!project) throw new Error('project is required');

  if (existing == null) {
    return {
      op: 'create',
      data: { email, name: name || nameFromEmail(email), isAdmin: false, projects: [project] },
      message: `no allowlist doc for ${email} — creating one scoped to ["${project}"]`,
    };
  }

  if (existing.isAdmin === true) {
    return { op: 'skip', message: `${email} is an admin (unrestricted) — already has "${project}"` };
  }

  const projects = existing.projects;
  // Absent or null `projects` means unrestricted — matches AuthService.loadAccount.
  if (projects == null) {
    return { op: 'skip', message: `${email} has unrestricted access (projects unset) — already has "${project}"` };
  }
  if (!Array.isArray(projects)) {
    throw new Error(`${email}: existing "projects" is neither null nor an array (${JSON.stringify(projects)})`);
  }
  if (projects.includes('*')) {
    return { op: 'skip', message: `${email} has "*" (unrestricted) — already has "${project}"` };
  }
  if (projects.includes(project)) {
    return { op: 'skip', message: `${email} already has "${project}"` };
  }

  const next = [...new Set([...projects, project])].sort();
  return {
    op: 'merge',
    data: { projects: next },
    message: `adding "${project}" to ${email}: [${projects.join(', ')}] → [${next.join(', ')}]`,
  };
}

async function main() {
  const [email, project] = process.argv.slice(2);
  if (!email || !project) {
    console.error('usage: node scripts/grant-project-access.mjs <email> <project>');
    console.error('   e.g. node scripts/grant-project-access.mjs dan@everbot.org dan');
    process.exit(1);
  }
  const name = process.env.NAME || nameFromEmail(email);
  const projectId = process.env.GCLOUD_PROJECT || DEFAULT_PROJECT_ID;
  const usingEmulator = !!process.env.FIRESTORE_EMULATOR_HOST;

  const { initializeApp, applicationDefault } = await import('firebase-admin/app');
  const { getFirestore } = await import('firebase-admin/firestore');
  // The emulator ignores credentials; production needs application-default creds
  // (GOOGLE_APPLICATION_CREDENTIALS or an authenticated gcloud/CI environment).
  initializeApp(usingEmulator ? { projectId } : { projectId, credential: applicationDefault() });
  const db = getFirestore();

  const ref = db.collection('commander_allowed_users').doc(docId(email));
  const snap = await ref.get();
  const plan = planGrant(snap.exists ? snap.data() : null, { email, name, project });

  console.log(`[${projectId}${usingEmulator ? ' · emulator' : ''}] ${plan.message}`);
  if (plan.op === 'create') {
    await ref.set(plan.data);
  } else if (plan.op === 'merge') {
    await ref.set(plan.data, { merge: true });
  }

  const after = (await ref.get()).data();
  const shown = after?.projects === undefined ? 'unrestricted' : JSON.stringify(after?.projects);
  console.log(`done — ${email} projects: ${shown}`);
}

// Only touch Firebase when run directly; importing this module (e.g. from tests)
// pulls in none of the admin SDK.
if (import.meta.url === `file://${process.argv[1]}`) {
  main().then(() => process.exit(0)).catch((err) => { console.error(err); process.exit(1); });
}
