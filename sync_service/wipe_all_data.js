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

async function deleteNonDemoDocs(collectionName) {
  const snap = await db.collection(collectionName).get();
  const toDelete = snap.docs.filter(doc => doc.data().isDemo !== true);

  if (toDelete.length === 0) {
    console.log(`Clearing ${collectionName}... 0 non-demo docs to delete. ✅`);
    return;
  }

  process.stdout.write(`Clearing ${toDelete.length} non-demo documents from ${collectionName}... `);
  
  // Batch delete in chunks of 400
  for (let i = 0; i < toDelete.length; i += 400) {
    const chunk = toDelete.slice(i, i + 400);
    const batch = db.batch();
    for (const doc of chunk) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
  console.log('DONE ✅');
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
    await deleteNonDemoDocs(col);
  }

  console.log('Auditing users collection (preserving Admins, Technicians, and Demo accounts)...');
  const usersSnap = await db.collection('users').get();
  let deletedTenants = 0;
  let keptUsers = 0;

  for (const doc of usersSnap.docs) {
    const data = doc.data();

    // 1. Keep demo accounts
    if (data.isDemo === true || (data.email && data.email.toLowerCase().startsWith('demo.'))) {
      console.log(`  [Keep] Demo Account: ${data.name || data.email || doc.id}`);
      keptUsers++;
      continue;
    }

    // 2. Keep Admin accounts
    if (data.role === 'admin' || data.email === 'test@admin.com') {
      console.log(`  [Keep] Admin Account: ${data.email || data.name || doc.id}`);
      keptUsers++;
      continue;
    }

    // 3. Keep Technicians
    if (data.role === 'technician') {
      console.log(`  [Keep] Technician Account: ${data.name || data.email || doc.id}`);
      keptUsers++;
      continue;
    }

    // 4. Delete only test tenant accounts from Firestore & Auth
    console.log(`  [Delete] Test Tenant: ${data.name || data.phone || doc.id} (${data.email})`);
    await doc.ref.delete();
    try {
      await auth.deleteUser(doc.id);
    } catch (_) {}
    deletedTenants++;
  }

  console.log(`\nUsers audit completed: ${keptUsers} kept, ${deletedTenants} test tenants deleted. ✅`);

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
