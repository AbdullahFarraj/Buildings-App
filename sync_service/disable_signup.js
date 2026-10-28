// One-off admin script: disables client-side self sign-up (createUserWithEmailAndPassword)
// for the Firebase project. Accounts can still be created by the Admin SDK (sync.js, Cloud Functions).
// Usage: node disable_signup.js            -> disable sign-up
//        node disable_signup.js --status   -> show current setting only
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

let keyPath = path.resolve(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(keyPath)) keyPath = path.resolve(__dirname, '../serviceAccountKey.json');
const serviceAccount = require(keyPath);
const projectId = serviceAccount.project_id;
const credential = admin.credential.cert(serviceAccount);
const base = `https://identitytoolkit.googleapis.com/admin/v2/projects/${projectId}/config`;

(async () => {
  const { access_token } = await credential.getAccessToken();
  const headers = { Authorization: `Bearer ${access_token}`, 'Content-Type': 'application/json' };

  const showStatus = async (label) => {
    const res = await fetch(base, { headers });
    const body = await res.json();
    if (!res.ok) throw new Error(JSON.stringify(body));
    console.log(`${label}: disabledUserSignup =`, body.client?.permissions?.disabledUserSignup === true);
  };

  await showStatus('Before');
  if (process.argv.includes('--status')) return;

  const res = await fetch(`${base}?updateMask=client.permissions.disabledUserSignup`, {
    method: 'PATCH',
    headers,
    body: JSON.stringify({ client: { permissions: { disabledUserSignup: true } } }),
  });
  if (!res.ok) throw new Error(JSON.stringify(await res.json()));
  await showStatus('After');
})().catch((e) => {
  console.error('❌ Failed:', e.message);
  process.exit(1);
});

