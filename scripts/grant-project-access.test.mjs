// Unit tests for the pure allowlist-merge logic in grant-project-access.mjs.
// Run with: node --test scripts/grant-project-access.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { docId, nameFromEmail, planGrant } from './grant-project-access.mjs';

const DAN = { email: 'dan@palmr.ai', name: 'Dan', project: 'dan' };

test('docId mirrors Access.emailToDocId', () => {
  assert.equal(docId('Dan@Palmr.ai'), 'dan_palmr_ai');
  assert.equal(docId('tim@everbot.org'), 'tim_everbot_org');
});

test('nameFromEmail title-cases the local part', () => {
  assert.equal(nameFromEmail('dan@palmr.ai'), 'Dan');
  assert.equal(nameFromEmail('jing@palmr.ai'), 'Jing');
});

test('absent doc → create scoped to the project', () => {
  const plan = planGrant(null, DAN);
  assert.equal(plan.op, 'create');
  assert.deepEqual(plan.data, { email: 'dan@palmr.ai', name: 'Dan', isAdmin: false, projects: ['dan'] });
});

test('create falls back to a derived name when none passed', () => {
  const plan = planGrant(null, { email: 'dan@palmr.ai', project: 'dan' });
  assert.equal(plan.data.name, 'Dan');
});

test('scoped user gains the project (sorted, de-duped)', () => {
  const plan = planGrant({ email: 'dan@palmr.ai', projects: ['palmr-ios'] }, DAN);
  assert.equal(plan.op, 'merge');
  assert.deepEqual(plan.data.projects, ['dan', 'palmr-ios']);
});

test('already has the project → skip', () => {
  const plan = planGrant({ projects: ['dan', 'palmr-ios'] }, DAN);
  assert.equal(plan.op, 'skip');
});

test('admin is left untouched (never narrowed)', () => {
  const plan = planGrant({ isAdmin: true, projects: null }, DAN);
  assert.equal(plan.op, 'skip');
});

test('unrestricted (projects unset) is left untouched', () => {
  assert.equal(planGrant({ email: 'dan@palmr.ai' }, DAN).op, 'skip');
  assert.equal(planGrant({ projects: null }, DAN).op, 'skip');
});

test('wildcard "*" is treated as unrestricted → skip', () => {
  assert.equal(planGrant({ projects: ['*'] }, DAN).op, 'skip');
});

test('merge does not mutate the caller\'s existing array', () => {
  const existing = { projects: ['palmr-ios'] };
  planGrant(existing, DAN);
  assert.deepEqual(existing.projects, ['palmr-ios']);
});

test('malformed projects (non-array, non-null) throws rather than corrupting', () => {
  assert.throws(() => planGrant({ projects: 'dan' }, DAN), /neither null nor an array/);
});

test('missing email/project are rejected', () => {
  assert.throws(() => planGrant(null, { email: '', project: 'dan' }), /email is required/);
  assert.throws(() => planGrant(null, { email: 'dan@palmr.ai', project: '' }), /project is required/);
});
