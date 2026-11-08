const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Check target environment
const isDev = process.argv.includes('--env=dev') || process.argv.includes('--dev');
let serviceAccountPath;

if (isDev) {
  serviceAccountPath = path.resolve(__dirname, 'serviceAccountKey.dev.json');
  if (!fs.existsSync(serviceAccountPath)) {
    serviceAccountPath = path.resolve(__dirname, 'serviceAccountKey.json');
  }
} else {
  serviceAccountPath = path.resolve(__dirname, 'serviceAccountKey.prod.json');
  if (!fs.existsSync(serviceAccountPath)) {
    serviceAccountPath = path.resolve(__dirname, 'serviceAccountKey.json');
  }
}

const serviceAccount = require(serviceAccountPath);
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
    // Preserve demo items if marked
    if (doc.data().isDemo === true) return;
    batch.delete(doc.ref);
  });
  await batch.commit();

  process.nextTick(() => {
    deleteQueryBatch(query, resolve, reject);
  });
}

async function wipeDatabase() {
  console.log('========================================================');
  console.log(`⚠️  CLEANUP TARGET: [${serviceAccount.project_id}] (${isDev ? 'DEVELOPMENT' : 'PRODUCTION'})`);
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
    process.stdout.write(`Clearing non-demo documents from: ${col}... `);
    await deleteCollection(col);
    console.log('DONE ✅');
  }

  console.log('Auditing users collection (preserving Admins, Technicians, and Demo accounts)...');
  const usersSnap = await db.collection('users').get();
  for (const doc of usersSnap.docs) {
    const data = doc.data();

    // 1. Keep demo accounts
    if (data.isDemo === true) {
      console.log(`  [Keep] Demo Account: ${data.name || data.email || doc.id}`);
      continue;
    }

    // 2. Keep Admin accounts
    if (data.role === 'admin' || data.email === 'test@admin.com') {
      console.log(`  [Keep] Admin Account: ${data.email || data.name || doc.id}`);
      continue;
    }

    // 3. Keep Technicians
    if (data.role === 'technician') {
      console.log(`  [Keep] Technician Account: ${data.name || data.email || doc.id}`);
      continue;
    }

    // 4. Delete only test tenant accounts
    console.log(`  [Delete] Test Tenant: ${data.name || data.phone || doc.id}`);
    await doc.ref.delete();
    try {
      await auth.deleteUser(doc.id);
    } catch (_) {}
  }
  console.log('Users audit completed ✅');

  console.log('========================================================');
  console.log(`🎉 Database [${serviceAccount.project_id}] is clean and ready for fresh sync!`);
  console.log('========================================================');
}

// Safety confirmation check
if (process.argv.includes('--confirm-wipe')) {
  wipeDatabase().then(() => process.exit(0)).catch(err => {
    console.error('Error during wipe:', err);
    process.exit(1);
  });
} else {
  console.log('⚠️ SAFETY SHIELD ACTIVE: To execute wipe, run with:');
  console.log('   node sync_service/wipe_all_data.js --confirm-wipe');
  process.exit(0);
}
