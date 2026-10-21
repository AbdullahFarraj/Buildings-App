const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.resolve(__dirname, '../serviceAccountKey.json'));
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();
const auth = admin.auth();

async function checkAdmin() {
  console.log('--- CHECKING USERS WITH NAME ABDULLAH OR ADMIN ---');
  const usersSnap = await db.collection('users').get();
  console.log(`Total users in Firestore: ${usersSnap.docs.length}`);
  
  usersSnap.docs.forEach(doc => {
    const data = doc.data();
    if (data.role === 'admin' || (data.name && data.name.toLowerCase().includes('abdullah'))) {
      console.log(`UID: ${doc.id} | Name: "${data.name}" | Email: "${data.email}" | Role: "${data.role}"`);
    }
  });

  const contractsSnap = await db.collection('contracts').get();
  console.log(`Total contracts in Firestore: ${contractsSnap.docs.length}`);
}

checkAdmin().catch(console.error);
