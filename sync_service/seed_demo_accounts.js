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

async function getOrCreateUser(email, password, displayName, role, phone) {
  let userRecord;
  try {
    userRecord = await auth.getUserByEmail(email);
    await auth.updateUser(userRecord.uid, {
      password: password,
      displayName: displayName
    });
  } catch (e) {
    if (e.code === 'auth/user-not-found') {
      userRecord = await auth.createUser({
        email: email,
        password: password,
        displayName: displayName,
        emailVerified: true
      });
    } else {
      throw e;
    }
  }

  await auth.setCustomUserClaims(userRecord.uid, { role: role, isDemo: true });
  return userRecord;
}

async function seed() {
  console.log('--- SEEDING 100% PURE FICTIONAL REALISTIC DEMO DATA ---');

  const password = 'Demo@123456';

  // 1. Tenant (Fictional: Alexander Wright)
  const tenantAuth = await getOrCreateUser(
    'demo.tenant@elitelivingre.ae',
    password,
    'Alexander Wright',
    'tenant',
    '0500000001'
  );

  const tenantData = {
    uid: tenantAuth.uid,
    name: 'Alexander Wright',
    email: 'demo.tenant@elitelivingre.ae',
    phone: '0500000001',
    role: 'tenant',
    isDemo: true,
    buildingId: 'Marina Crown Tower',
    apartmentId: '1404',
    properties: [
      {
        buildingName: 'Marina Crown Tower',
        unitNumber: '1404',
        startDate: '2026-01-01T00:00:00.000Z',
        endDate: '2026-12-31T23:59:59.000Z'
      }
    ],
    contractStartDate: admin.firestore.Timestamp.fromDate(new Date('2026-01-01')),
    contractEndDate: admin.firestore.Timestamp.fromDate(new Date('2026-12-31')),
    contractUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
    ledgerBalance: 0,
    totalDebit: 95000,
    totalCredit: 47500,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };
  await db.collection('users').doc(tenantAuth.uid).set(tenantData, { merge: true });

  // 1b. Additional Fictional Tenant 2: Sarah Jenkins
  const tenant2Auth = await getOrCreateUser(
    'demo.tenant2@elitelivingre.ae',
    password,
    'Sarah Jenkins',
    'tenant',
    '0500000004'
  );
  await db.collection('users').doc(tenant2Auth.uid).set({
    uid: tenant2Auth.uid,
    name: 'Sarah Jenkins',
    email: 'demo.tenant2@elitelivingre.ae',
    phone: '0500000004',
    role: 'tenant',
    isDemo: true,
    buildingId: 'Palm Views Residence',
    apartmentId: '802',
    properties: [
      {
        buildingName: 'Palm Views Residence',
        unitNumber: '802',
        startDate: '2026-02-01T00:00:00.000Z',
        endDate: '2027-01-31T23:59:59.000Z'
      }
    ],
    contractStartDate: admin.firestore.Timestamp.fromDate(new Date('2026-02-01')),
    contractEndDate: admin.firestore.Timestamp.fromDate(new Date('2027-01-31')),
    contractUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
    ledgerBalance: 0,
    totalDebit: 75000,
    totalCredit: 75000,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });

  // 1c. Additional Fictional Tenant 3: Marcus Vance
  const tenant3Auth = await getOrCreateUser(
    'demo.tenant3@elitelivingre.ae',
    password,
    'Marcus Vance',
    'tenant',
    '0500000005'
  );
  await db.collection('users').doc(tenant3Auth.uid).set({
    uid: tenant3Auth.uid,
    name: 'Marcus Vance',
    email: 'demo.tenant3@elitelivingre.ae',
    phone: '0500000005',
    role: 'tenant',
    isDemo: true,
    buildingId: 'Downtown Heights',
    apartmentId: '2105',
    properties: [
      {
        buildingName: 'Downtown Heights',
        unitNumber: '2105',
        startDate: '2026-03-01T00:00:00.000Z',
        endDate: '2027-02-28T23:59:59.000Z'
      }
    ],
    contractStartDate: admin.firestore.Timestamp.fromDate(new Date('2026-03-01')),
    contractEndDate: admin.firestore.Timestamp.fromDate(new Date('2027-02-28')),
    contractUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
    ledgerBalance: 0,
    totalDebit: 60000,
    totalCredit: 30000,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  }, { merge: true });

  // 2. Technician (Fictional: Rashid Al-Mansoor)
  const techAuth = await getOrCreateUser(
    'demo.technician@elitelivingre.ae',
    password,
    'Rashid Al-Mansoor',
    'technician',
    '0500000002'
  );

  const techData = {
    uid: techAuth.uid,
    name: 'Rashid Al-Mansoor',
    email: 'demo.technician@elitelivingre.ae',
    phone: '0500000002',
    role: 'technician',
    isDemo: true,
    isDefaultTechnician: true,
    profession: 'Senior HVAC & MEP Specialist',
    averageRating: 4.9,
    totalRatings: 28,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };
  await db.collection('users').doc(techAuth.uid).set(techData, { merge: true });

  // 3. Admin (Fictional: Property Manager)
  const adminAuth = await getOrCreateUser(
    'demo.admin@elitelivingre.ae',
    password,
    'Property Manager',
    'admin',
    '0500000003'
  );

  const adminData = {
    uid: adminAuth.uid,
    name: 'Property Manager',
    email: 'demo.admin@elitelivingre.ae',
    phone: '0500000003',
    role: 'admin',
    isDemo: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp()
  };
  await db.collection('users').doc(adminAuth.uid).set(adminData, { merge: true });

  // 4. Contract in contracts collection
  await db.collection('contracts').doc('DEMO-CTR-1404').set({
    contractCode: 'DEMO-CTR-1404',
    contractNumber: 1404,
    buildingName: 'Marina Crown Tower',
    unitNumber: '1404',
    unitType: '2-Bedroom Luxury Suite',
    tenantName: 'Alexander Wright',
    mobileNumber: '0500000001',
    customerEmail: 'demo.tenant@elitelivingre.ae',
    startDate: admin.firestore.Timestamp.fromDate(new Date('2026-01-01')),
    endDate: admin.firestore.Timestamp.fromDate(new Date('2026-12-31')),
    rentAmount: 95000,
    yearValue: 95000,
    contractState: 'Active',
    tenantUid: tenantAuth.uid,
    isDemo: true
  }, { merge: true });

  await db.collection('contracts').doc('DEMO-CTR-802').set({
    contractCode: 'DEMO-CTR-802',
    contractNumber: 802,
    buildingName: 'Palm Views Residence',
    unitNumber: '802',
    unitType: '1-Bedroom Sea View',
    tenantName: 'Sarah Jenkins',
    mobileNumber: '0500000004',
    customerEmail: 'demo.tenant2@elitelivingre.ae',
    startDate: admin.firestore.Timestamp.fromDate(new Date('2026-02-01')),
    endDate: admin.firestore.Timestamp.fromDate(new Date('2027-01-31')),
    rentAmount: 75000,
    yearValue: 75000,
    contractState: 'Active',
    tenantUid: tenant2Auth.uid,
    isDemo: true
  }, { merge: true });

  await db.collection('contracts').doc('DEMO-CTR-2105').set({
    contractCode: 'DEMO-CTR-2105',
    contractNumber: 2105,
    buildingName: 'Downtown Heights',
    unitNumber: '2105',
    unitType: 'Studio Executive',
    tenantName: 'Marcus Vance',
    mobileNumber: '0500000005',
    customerEmail: 'demo.tenant3@elitelivingre.ae',
    startDate: admin.firestore.Timestamp.fromDate(new Date('2026-03-01')),
    endDate: admin.firestore.Timestamp.fromDate(new Date('2027-02-28')),
    rentAmount: 60000,
    yearValue: 60000,
    contractState: 'Active',
    tenantUid: tenant3Auth.uid,
    isDemo: true
  }, { merge: true });

  // 5. Four Quarterly Cheques
  const cheques = [
    {
      id: 'demo_chq_1',
      chequeNumber: '000841',
      bankName: 'Emirates NBD',
      amount: 23750,
      dueDate: admin.firestore.Timestamp.fromDate(new Date('2026-01-01')),
      status: 'paid',
      notes: 'Quarter 1 Rent - Cleared on time'
    },
    {
      id: 'demo_chq_2',
      chequeNumber: '000842',
      bankName: 'Emirates NBD',
      amount: 23750,
      dueDate: admin.firestore.Timestamp.fromDate(new Date('2026-04-01')),
      status: 'paid',
      notes: 'Quarter 2 Rent - Cleared on time'
    },
    {
      id: 'demo_chq_3',
      chequeNumber: '000843',
      bankName: 'Emirates NBD',
      amount: 23750,
      dueDate: admin.firestore.Timestamp.fromDate(new Date('2026-07-01')),
      status: 'due_soon',
      notes: 'Quarter 3 Rent - Deposited for collection'
    },
    {
      id: 'demo_chq_4',
      chequeNumber: '000844',
      bankName: 'Emirates NBD',
      amount: 23750,
      dueDate: admin.firestore.Timestamp.fromDate(new Date('2026-10-01')),
      status: 'pending',
      notes: 'Quarter 4 Rent - Post-dated cheque in safe'
    },
    {
      id: 'demo_chq_5',
      tenantUid: tenant2Auth.uid,
      tenantName: 'Sarah Jenkins',
      chequeNumber: '001920',
      bankName: 'Abu Dhabi Commercial Bank (ADCB)',
      amount: 37500,
      dueDate: admin.firestore.Timestamp.fromDate(new Date('2026-02-01')),
      status: 'paid',
      contractCode: 'DEMO-CTR-802',
      buildingName: 'Palm Views Residence',
      unitNumber: '802',
      notes: 'Payment 1/2 - Cleared'
    },
    {
      id: 'demo_chq_6',
      tenantUid: tenant2Auth.uid,
      tenantName: 'Sarah Jenkins',
      chequeNumber: '001921',
      bankName: 'Abu Dhabi Commercial Bank (ADCB)',
      amount: 37500,
      dueDate: admin.firestore.Timestamp.fromDate(new Date('2026-08-01')),
      status: 'due_soon',
      contractCode: 'DEMO-CTR-802',
      buildingName: 'Palm Views Residence',
      unitNumber: '802',
      notes: 'Payment 2/2 - In hand'
    },
    {
      id: 'demo_chq_7',
      tenantUid: tenant3Auth.uid,
      tenantName: 'Marcus Vance',
      chequeNumber: '003101',
      bankName: 'Dubai Islamic Bank (DIB)',
      amount: 15000,
      dueDate: admin.firestore.Timestamp.fromDate(new Date('2026-03-01')),
      status: 'paid',
      contractCode: 'DEMO-CTR-2105',
      buildingName: 'Downtown Heights',
      unitNumber: '2105',
      notes: 'Installment 1/4 - Cleared'
    },
    {
      id: 'demo_chq_8',
      tenantUid: tenant3Auth.uid,
      tenantName: 'Marcus Vance',
      chequeNumber: '003102',
      bankName: 'Dubai Islamic Bank (DIB)',
      amount: 15000,
      dueDate: admin.firestore.Timestamp.fromDate(new Date('2026-06-01')),
      status: 'overdue',
      contractCode: 'DEMO-CTR-2105',
      buildingName: 'Downtown Heights',
      unitNumber: '2105',
      notes: 'Installment 2/4 - Contacted tenant for clearance'
    }
  ];

  for (const chq of cheques) {
    await db.collection('cheques').doc(chq.id).set({
      tenantUid: chq.tenantUid || tenantAuth.uid,
      tenantName: chq.tenantName || 'Alexander Wright',
      chequeNumber: chq.chequeNumber,
      bankName: chq.bankName,
      amount: chq.amount,
      dueDate: chq.dueDate,
      status: chq.status,
      contractCode: chq.contractCode || 'DEMO-CTR-1404',
      buildingName: chq.buildingName || 'Marina Crown Tower',
      unitNumber: chq.unitNumber || '1404',
      notes: chq.notes,
      isDemo: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });
  }

  // 6. Realistic Tasks
  const task1Ref = db.collection('tasks').doc('demo_task_1');
  await task1Ref.set({
    tenantId: tenantAuth.uid,
    apartmentNumber: '1404',
    buildingId: 'Marina Crown Tower',
    title: 'Chilled Water AC Leakage in Living Room',
    description: 'Noticeable condensation dripping from the ceiling diffuser grill. Needs coil cleaning and drain line inspection.',
    category: 'HVAC',
    status: 'in_progress',
    technicianId: techAuth.uid,
    technicianName: 'Rashid Al-Mansoor',
    createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3600000 * 5)),
    preferredVisitSlot: '10:00 AM - 12:00 PM',
    isDemo: true,
    photoUrls: [
      'https://images.unsplash.com/photo-1621905251189-08b45d6a269e?auto=format&fit=crop&w=800&q=80'
    ]
  }, { merge: true });

  const task2Ref = db.collection('tasks').doc('demo_task_2');
  await task2Ref.set({
    tenantId: tenantAuth.uid,
    apartmentNumber: '1404',
    buildingId: 'Marina Crown Tower',
    title: 'Water Heater Pressure Valve Replacement',
    description: 'Minor water seepage from the safety pressure relief valve inside the secondary bathroom ceiling access.',
    category: 'Plumbing',
    status: 'pending',
    createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3600000 * 18)),
    preferredVisitSlot: '02:00 PM - 04:00 PM',
    isDemo: true,
    photoUrls: [
      'https://images.unsplash.com/photo-1584622650111-993a426fbf0a?auto=format&fit=crop&w=800&q=80'
    ]
  }, { merge: true });

  const task3Ref = db.collection('tasks').doc('demo_task_3');
  await task3Ref.set({
    tenantId: tenantAuth.uid,
    apartmentNumber: '1404',
    buildingId: 'Marina Crown Tower',
    title: 'Video Intercom Screen Not Displaying Feed',
    description: 'Intercom chime works normally but the video screen remains black when lobby visitors call.',
    category: 'Electrical',
    status: 'completed',
    technicianId: techAuth.uid,
    technicianName: 'Rashid Al-Mansoor',
    createdAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3600000 * 72)),
    completedAt: admin.firestore.Timestamp.fromDate(new Date(Date.now() - 3600000 * 24)),
    completionNotes: 'Power cable connection re-seated and display controller firmware reset. Audio and video feed tested clear with security lobby.',
    rating: 5,
    tenantFeedback: 'Excellent and quick resolution by technician Rashid!',
    isDemo: true,
    photoUrls: [
      'https://images.unsplash.com/photo-1558002038-1055907df827?auto=format&fit=crop&w=800&q=80'
    ],
    completionProofUrl: 'https://images.unsplash.com/photo-1544717305-2782549b5136?auto=format&fit=crop&w=800&q=80'
  }, { merge: true });

  // 7. Phone Index for direct phone logins
  await db.collection('phone_index').doc('971500000001').set({ email: 'demo.tenant@elitelivingre.ae', uid: tenantAuth.uid, isDemo: true }, { merge: true });
  await db.collection('phone_index').doc('971500000002').set({ email: 'demo.technician@elitelivingre.ae', uid: techAuth.uid, isDemo: true }, { merge: true });
  await db.collection('phone_index').doc('971500000003').set({ email: 'demo.admin@elitelivingre.ae', uid: adminAuth.uid, isDemo: true }, { merge: true });

  console.log('✅ 100% FICTIONAL REALISTIC DEMO DATA SUCCESSFULLY WRITTEN!');
}

seed().then(() => process.exit(0)).catch(err => {
  console.error('Error seeding demo accounts:', err);
  process.exit(1);
});
