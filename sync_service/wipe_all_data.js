const admin = require('firebase-admin');
const path = require('path');

const serviceAccount = require(path.resolve(__dirname, 'serviceAccountKey.json'));
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();
const auth = admin.auth();

async function deleteCollection(collectionPath, batchSize = 100) {
  const collectionRef = db.collection(collectionPath);
  const query = collectionRef.limit(batchSize);

  return new Promise((resolve, reject) => {
    deleteQueryBatch(query, resolve, reject);
  });
}

async function deleteQueryBatch(query, resolve, reject) {
  const snapshot = await query.get();

  const batchSize = snapshot.size;
  if (batchSize === 0) {
    resolve();
    return;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    // If you wish to preserve the 3 fictional demo accounts, you can uncomment:
    // if (doc.data().isDemo === true) return;
    batch.delete(doc.ref);
  });
  await batch.commit();

  process.nextTick(() => {
    deleteQueryBatch(query, resolve, reject);
  });
}

async function wipeDatabase() {
  console.log('========================================================');
  console.log('⚠️  STARTING COMPLETE DATABASE CLEANUP FOR PRODUCTION');
  console.log('========================================================');

  const collections = [
    'tasks',
    'contracts',
    'cheques',
    'notifications',
    'phone_index',
    'direct_chats'
  ];

  for (const col of collections) {
    process.stdout.write(`Clearing collection: ${col}... `);
    await deleteCollection(col);
    console.log('DONE ✅');
  }

  console.log('Clearing users collection (preserving admin if needed)...');
  const usersSnap = await db.collection('users').get();
  for (const doc of usersSnap.docs) {
    const data = doc.data();
    // Keep test admin or demo accounts if desired, otherwise delete
    if (data.email === 'test@admin.com') {
      console.log(`Preserving master admin: ${data.email}`);
      continue;
    }
    await doc.ref.delete();
    try {
      await auth.deleteUser(doc.id);
    } catch (_) {}
  }
  console.log('Users collection wiped ✅');

  console.log('========================================================');
  console.log('🎉 DATABASE HAS BEEN COMPLETELY RESET FOR FRESH SYNC!');
  console.log('You can now run sync.js on your main PC with 100% confidence.');
  console.log('========================================================');
}

// Safety confirmation check
if (process.argv.includes('--confirm-wipe')) {
  wipeDatabase().then(() => process.exit(0)).catch(err => {
    console.error('Error during wipe:', err);
    process.exit(1);
  });
} else {
  console.log('⚠️ SAFETY SHIELD ACTIVE: To execute wipe, run with: node sync_service/wipe_all_data.js --confirm-wipe');
  process.exit(0);
}

