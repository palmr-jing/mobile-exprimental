// Add accepted ASC team users to Emma's internal TestFlight group.
// Run AFTER the invitees accept their App Store Connect invitation:
//   ASC_ISSUER_ID=<uuid> node scripts/add-internal-testers.mjs dan@palmr.ai jing@palmr.ai tim@palmr.ai
import { asc } from './asc.mjs';

const APP = '6780673334';            // Emma by Palmr
const GROUP_NAME = 'Beta Testers';   // internal group
const emails = process.argv.slice(2);
if (!emails.length) { console.error('usage: node add-internal-testers.mjs <email> [email...]'); process.exit(1); }

const g = await asc('GET', `/v1/betaGroups?filter%5Bapp%5D=${APP}&fields%5BbetaGroups%5D=name,isInternalGroup`);
const group = (g.json.data || []).find(x => x.attributes.name === GROUP_NAME && x.attributes.isInternalGroup);
if (!group) { console.error(`internal group "${GROUP_NAME}" not found`); process.exit(1); }

for (const email of emails) {
  const r = await asc('POST', '/v1/betaTesters', { data: {
    type: 'betaTesters', attributes: { email },
    relationships: { betaGroups: { data: [{ type: 'betaGroups', id: group.id }] } } } });
  console.log(email, '->', r.status, r.json?.errors?.[0]?.detail || 'added to internal group');
}
