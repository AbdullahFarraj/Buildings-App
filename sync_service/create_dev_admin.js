const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.resolve(__dirname, 'serviceAccountKey.dev.json'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const auth = admin.auth();
const db = admin.firestore();

async function createDevAdmin() {
  const email = 'admin@test.com';
  const password = '123456';
  const name = 'Admin';
  const role = 'admin';

  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    console.log(`User ${email} already exists in Auth. Updating password...`);
    await auth.updateUser(userRecord.uid, {
      password: password,
      displayName: name,
      emailVerified: true
    });
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      console.log(`Creating new user ${email} in Auth...`);
      userRecord = await auth.createUser({
        email: email,
        password: password,
        displayName: name,
        emailVerified: true
      });
    } else {
      throw err;
    }
  }

  // Set custom user claims
  await auth.setCustomUserClaims(userRecord.uid, { role: role });

  // Create Firestore document in 'users'
  const userData = {
    uid: userRecord.uid,
    name: name,
    email: email,
    role: role,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };

  await db.collection('users').doc(userRecord.uid).set(userData, { merge: true });

  console.log('========================================================');
  console.log('✅ Successfully created Admin user in Dev project:');
  console.log(`   Project : ${serviceAccount.project_id}`);
  console.log(`   UID     : ${userRecord.uid}`);
  console.log(`   Email   : ${email}`);
  console.log(`   Password: ${password}`);
  console.log(`   Role    : ${role}`);
  console.log('========================================================');
}

createDevAdmin().catch(err => {
  console.error('❌ Error creating admin user:', err);
  process.exit(1);
});

