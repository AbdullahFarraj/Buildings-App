const sql = require('mssql/msnodesqlv8');
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// 1. Initialize Firebase Admin SDK
let serviceAccountPath = path.resolve(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(serviceAccountPath)) {
  serviceAccountPath = path.resolve(__dirname, '../serviceAccountKey.json');
}
if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ Error: serviceAccountKey.json not found in sync_service or parent directory.');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const auth = admin.auth();

// 2. SQL Server Configuration
// 👇 غيّر اسم السيرفر واسم قاعدة البيانات هنا إذا نقلت الملف لكمبيوتر آخر 👇
const SQL_SERVER = process.env.SQL_SERVER || 'ABDULLAH-LAP\\SQLEXPRESS'; // مثال: 'localhost\\SQLEXPRESS' أو 'SERVER-NAME\\SQLEXPRESS' أو '.'
const SQL_DATABASE = process.env.SQL_DATABASE || 'AlAqaree7';

const sqlConfig = {
  connectionString: `Driver={SQL Server Native Client 10.0};Server=${SQL_SERVER};Database=${SQL_DATABASE};Trusted_Connection=yes;`,
  server: SQL_SERVER,
  database: SQL_DATABASE,
  driver: 'msnodesqlv8',
  requestTimeout: 120000,
  options: {
    trustedConnection: true,
    trustServerCertificate: true,
    useUTC: false,
    requestTimeout: 120000
  }
};

// 3. UAE Mobile Number Sanitizer (Target: 9715xxxxxxxx - 12 digits)
function sanitizeUaeMobile(rawMobile) {
  if (!rawMobile) return null;

  // First, if there are multiple numbers separated by slash or comma, take the first part
  let firstPart = rawMobile.toString().split(/[\/,;]+/)[0].trim();

  // Remove ALL non-digit characters (including spaces, newlines, tabs, dashes, plus)
  let digits = firstPart.replace(/\D/g, '');

  if (!digits) return null;

  // Handle common typos where digit '1' in '971' was omitted:
  // 975xxxxxxxx (11 digits) -> 9715xxxxxxxx (12 digits)
  if (digits.startsWith('975') && digits.length === 11) {
    digits = '9715' + digits.substring(3);
  }

  // 915xxxxxxxx (11 digits) -> 9715xxxxxxxx (12 digits)
  if (digits.startsWith('915') && digits.length === 11) {
    digits = '9715' + digits.substring(3);
  }

  // Handle accidental 97105xxxxxxx -> 9715xxxxxxx
  if (digits.startsWith('97105') && digits.length === 13) {
    digits = '9715' + digits.substring(5);
  }

  // Handle 009715...
  if (digits.startsWith('009715') && digits.length === 14) {
    digits = digits.substring(2);
  }

  // Handle 05xxxxxxxx -> 9715xxxxxxxx
  if (digits.startsWith('05') && digits.length === 10) {
    digits = '971' + digits.substring(1);
  }

  // Handle 5xxxxxxxx -> 9715xxxxxxxx
  if (digits.startsWith('5') && digits.length === 9) {
    digits = '971' + digits;
  }

  // Must be 12 digits and start with 9715
  if (digits.length === 12 && digits.startsWith('9715')) {
    return digits;
  }

  return null;
}

// 4. Email Extractor & Sanitizer
function extractValidEmail(rawEmail, fallbackIdentifier) {
  if (rawEmail) {
    const parts = rawEmail.toString().split(/[\/,;\s]+/);
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    for (const part of parts) {
      const trimmed = part.trim().toLowerCase();
      if (emailRegex.test(trimmed)) {
        return trimmed;
      }
    }
  }
  if (!fallbackIdentifier) return null;
  return `${fallbackIdentifier}@elitelivingre.ae`;
}

// 5. Main Synchronization Flow
async function runSync() {
  console.log('========================================================');
  console.log('🚀 بدء مزامنة عقود الإيجار مع Firebase (EliteLivingre / العقاري)...');
  console.log('========================================================');

  let pool;
  try {
    console.log(`⏳ جاري الاتصال بقاعدة بيانات SQL Server (${SQL_SERVER})...`);
    pool = await new sql.ConnectionPool(sqlConfig).connect();
    console.log('✅ تم الاتصال بقاعدة البيانات بنجاح.');

    const query = `
      SELECT 
          LTRIM(RTRIM(v.ContractNo))            AS contractCode,
          v.Number                              AS contractNumber,
          LTRIM(RTRIM(v.BuildingName))          AS buildingName,
          LTRIM(RTRIM(v.FlatNo))                AS unitNumber,
          LTRIM(RTRIM(v.ApartmentType))         AS unitType,
          LTRIM(RTRIM(v.CustName))              AS tenantName,
          LTRIM(RTRIM(v.CustomerMobile))        AS mobileNumber,
          LTRIM(RTRIM(c.EMail))                 AS customerEmail,
          v.FromDate                            AS startDate,
          v.ToDate                              AS endDate,
          v.Rent                                AS rentAmount,
          v.YearValue                           AS yearValue,
          LTRIM(RTRIM(v.ContractState))         AS contractState
      FROM vwLeaseApartment v
      LEFT JOIN Customer c ON v.CustomerGuid = c.Guid
      WHERE LTRIM(RTRIM(v.ContractState)) = 'valid'
        AND YEAR(v.ToDate) >= 2026
      ORDER BY v.CustName, v.BuildingName, v.FlatNo;
    `;

    console.log('⏳ جاري استرجاع العقود النشطة مع الإيميلات الحقيقية لسنة 2026 وما بعدها...');
    const result = await pool.request().query(query);
    const rows = result.recordset;
    console.log(`📋 تم استرجاع ${rows.length} عقداً من قاعدة البيانات.`);

    if (rows.length === 0) {
      console.log('ℹ️ لا توجد عقود تطابق الشروط حالياً.');
      return;
    }

    // Date & Timezone conversion helpers
    function toMiddayTimestamp(d) {
      if (!d) return null;
      const dt = new Date(d);
      const midday = new Date(dt.getFullYear(), dt.getMonth(), dt.getDate(), 12, 0, 0);
      return admin.firestore.Timestamp.fromDate(midday);
    }

    function toCalendarIsoString(d) {
      if (!d) return null;
      const dt = new Date(d);
      const y = dt.getFullYear();
      const m = String(dt.getMonth() + 1).padStart(2, '0');
      const day = String(dt.getDate()).padStart(2, '0');
      return `${y}-${m}-${day}T00:00:00.000`;
    }

    function normalizeTenantName(name) {
      if (!name) return 'مستأجر غير معروف';
      return name.toString().trim().replace(/\s+/g, ' ');
    }

    // Pre-fetch all Firebase Auth users in 1 call for blazing-fast in-memory lookup
    console.log('⏳ جاري تحميل حسابات المستخدمين من Firebase...');
    const allUsersResult = await auth.listUsers(1000);
    const userByPhone = new Map();
    const userByEmail = new Map();
    const userByName = new Map();

    for (const u of allUsersResult.users) {
      if (u.phoneNumber) userByPhone.set(u.phoneNumber, u);
      if (u.email) userByEmail.set(u.email.toLowerCase(), u);
      if (u.displayName) userByName.set(normalizeTenantName(u.displayName).toLowerCase(), u);
    }

    // Pre-fetch existing Firestore users to map Name -> UID
    const firestoreUsersSnap = await db.collection('users').get();
    for (const doc of firestoreUsersSnap.docs) {
      const data = doc.data();
      if (data.name) {
        const norm = normalizeTenantName(data.name).toLowerCase();
        if (!userByName.has(norm)) {
          userByName.set(norm, { uid: doc.id, ...data });
        }
      }
    }
    console.log(`👤 تم العثور على ${allUsersResult.users.length} حساب Auth و ${firestoreUsersSnap.size} مستخدم في Firestore.`);

    let processedCount = 0;
    let authCreatedCount = 0;
    let authExistingCount = 0;

    // We will collect batched operations (max 400 per batch)
    let currentBatch = db.batch();
    let currentBatchOps = 0;
    const batchPromises = [];

    async function commitBatchIfNeeded(force = false) {
      if ((currentBatchOps >= 400 || force) && currentBatchOps > 0) {
        console.log(`💾 جاري حفظ دفعة في فايرستور (${currentBatchOps} عملية)...`);
        batchPromises.push(currentBatch.commit());
        currentBatch = db.batch();
        currentBatchOps = 0;
      }
    }

    // Group rows by Normalized Tenant Name
    console.log('⏳ جاري تجميع كافة العقود حسب اسم المستأجر (Name Grouping)...');
    const tenantGroups = new Map();
    for (const row of rows) {
      const normName = normalizeTenantName(row.tenantName);
      if (!tenantGroups.has(normName)) {
        tenantGroups.set(normName, {
          name: normName,
          contracts: [],
          rawMobiles: [],
          customerEmails: []
        });
      }
      const group = tenantGroups.get(normName);
      group.contracts.push(row);
      if (row.mobileNumber) group.rawMobiles.push(row.mobileNumber);
      if (row.customerEmail) group.customerEmails.push(row.customerEmail);
    }
    console.log(`👥 تم العثور على ${tenantGroups.size} مستأجر فريد من أصل ${rows.length} عقداً نشطاً.`);

    console.log('⏳ جاري معالجة العقود، ربط العقارات بالحسابات، وتحديث الفايربيس...');
    for (const group of tenantGroups.values()) {
      // 1. Gather all unique valid UAE mobile numbers for this tenant
      const validMobiles = [];
      for (const rawM of group.rawMobiles) {
        const sanitized = sanitizeUaeMobile(rawM);
        if (sanitized && !validMobiles.includes(sanitized)) {
          validMobiles.push(sanitized);
        }
      }
      const primaryMobile = validMobiles[0] || null;
      const rawPhone = group.rawMobiles.find(m => m && String(m).trim().length > 0) || '';

      // 2. Resolve email (prefer real customer email, then phone@elitelivingre.ae, then slug)
      let email = null;
      for (const rawEmail of group.customerEmails) {
        const parsed = extractValidEmail(rawEmail, primaryMobile);
        if (parsed && !parsed.includes('nocode')) {
          email = parsed;
          break;
        }
      }
      if (!email) {
        if (primaryMobile) {
          email = `${primaryMobile}@elitelivingre.ae`;
        } else {
          const nameHash = Buffer.from(group.name).toString('hex').substring(0, 12);
          email = `tenant_${nameHash}@elitelivingre.ae`;
        }
      }

      // Default password: phone if available, else Elite@123456
      const defaultPassword = primaryMobile || 'Elite@123456';

      // 3. Build properties list for this tenant
      const properties = group.contracts.map(c => {
        const safeCode = (c.contractCode || `${c.unitNumber}_${c.contractNumber || 'nocode'}`)
          .toString()
          .replace(/[\/\\#\s]/g, '_');
        return {
          buildingName: (c.buildingName || 'غير محدد').trim(),
          unitNumber: (c.unitNumber || '').trim(),
          unitType: (c.unitType || '').trim(),
          contractCode: (c.contractCode || '').trim(),
          contractNumber: c.contractNumber || null,
          startDate: toCalendarIsoString(c.startDate),
          endDate: toCalendarIsoString(c.endDate),
          rentAmount: c.rentAmount || 0,
          yearValue: c.yearValue || 0,
          contractState: c.contractState || 'valid',
        };
      });

      // 4. In-Memory Lookup & Auth Sync (Priority: Name -> Phone -> Email)
      let uid;
      const nameKey = group.name.toLowerCase();
      const phoneKey = primaryMobile ? `+${primaryMobile}` : null;
      const emailKey = email.toLowerCase();

      let existingUser = userByName.get(nameKey) ||
                         (phoneKey ? userByPhone.get(phoneKey) : null) ||
                         userByEmail.get(emailKey);

      try {
        if (existingUser) {
          uid = existingUser.uid;
          const needsUpdate = existingUser.displayName !== group.name ||
                              (phoneKey && !existingUser.phoneNumber);
          if (needsUpdate && auth.getUser) {
            const updatePayload = {
              displayName: group.name,
              password: defaultPassword
            };
            if (phoneKey && !existingUser.phoneNumber) {
              updatePayload.phoneNumber = phoneKey;
            }
            try {
              await auth.updateUser(uid, updatePayload);
            } catch (upErr) {
              // Ignore harmless phone conflict during update
            }
          }
          authExistingCount++;
        } else {
          try {
            const createPayload = {
              email: email,
              password: defaultPassword,
              displayName: group.name
            };
            if (phoneKey) {
              createPayload.phoneNumber = phoneKey;
            }
            const newUser = await auth.createUser(createPayload);
            uid = newUser.uid;
            if (phoneKey) userByPhone.set(phoneKey, newUser);
            userByEmail.set(emailKey, newUser);
            userByName.set(nameKey, newUser);
            authCreatedCount++;
          } catch (createErr) {
            if (createErr.code === 'auth/email-already-exists') {
              const u = await auth.getUserByEmail(email);
              uid = u.uid;
              userByEmail.set(emailKey, u);
              userByName.set(nameKey, u);
              authExistingCount++;
            } else if (phoneKey && createErr.code === 'auth/phone-number-already-exists') {
              const u = await auth.getUserByPhoneNumber(phoneKey);
              uid = u.uid;
              userByPhone.set(phoneKey, u);
              userByName.set(nameKey, u);
              authExistingCount++;
            } else {
              const nameHash = Buffer.from(group.name).toString('hex').substring(0, 16);
              uid = `tenant_${nameHash}`;
              console.warn(`⚠️ تعذر إنشاء حساب Auth لـ (${group.name}):`, createErr.message);
            }
          }
        }
      } catch (err) {
        console.warn(`⚠️ خطأ في معالجة Auth لـ (${group.name}):`, err.message);
        const nameHash = Buffer.from(group.name).toString('hex').substring(0, 16);
        uid = uid || `tenant_${nameHash}`;
      }

      // 5. Save each contract to `contracts` collection with tenantUid = uid
      for (const c of group.contracts) {
        const safeCode = (c.contractCode || `${c.unitNumber}_${c.contractNumber || 'nocode'}`)
          .toString()
          .replace(/[\/\\#\s]/g, '_');
        const contractDocId = primaryMobile ? `${primaryMobile}_${safeCode}` : `contract_${safeCode}`;
        const contractRef = db.collection('contracts').doc(contractDocId);
        const contractData = {
          contractCode: c.contractCode || '',
          contractNumber: c.contractNumber || null,
          buildingName: (c.buildingName || '').trim(),
          unitNumber: (c.unitNumber || '').trim(),
          unitType: c.unitType || '',
          tenantName: group.name,
          mobileNumber: primaryMobile || (c.mobileNumber ? String(c.mobileNumber).trim() : ''),
          customerEmail: email,
          email: email,
          startDate: toMiddayTimestamp(c.startDate),
          endDate: toMiddayTimestamp(c.endDate),
          rentAmount: c.rentAmount || 0,
          yearValue: c.yearValue || 0,
          contractState: c.contractState || 'valid',
          tenantUid: uid,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        currentBatch.set(contractRef, contractData, { merge: true });
        currentBatchOps++;
        processedCount++;
      }

      // 6. Save unified tenant User document in `users/{uid}`
      const userRef = db.collection('users').doc(uid);
      const uniqueBuildings = [...new Set(properties.map(p => p.buildingName).filter(Boolean))];
      const allApartments = properties.map(p => p.unitNumber).filter(Boolean);

      const userData = {
        name: group.name,
        phone: primaryMobile || (rawPhone ? String(rawPhone).trim() : ''),
        allPhones: validMobiles,
        email: email,
        role: 'tenant',
        properties: properties,
        apartmentId: allApartments.join(', '),
        buildingId: uniqueBuildings.join(', '),
        contractStartDate: properties[0]?.startDate || null,
        contractEndDate: properties[0]?.endDate || null,
        contractCode: properties[0]?.contractCode || '',
        rentAmount: properties.reduce((sum, p) => sum + (p.rentAmount || 0), 0),
        yearValue: properties.reduce((sum, p) => sum + (p.yearValue || 0), 0),
        unitType: properties.map(p => p.unitType).filter(Boolean).join(', '),
        contractsCount: properties.length,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      currentBatch.set(userRef, userData, { merge: true });
      currentBatchOps++;

      // 7. Register ALL tenant phone numbers into `phone_index`
      for (const m of validMobiles) {
        const phoneIndexRef = db.collection('phone_index').doc(m);
        currentBatch.set(phoneIndexRef, { email: email, uid: uid }, { merge: true });
        currentBatchOps++;

        if (m.startsWith('9715') && m.length === 12) {
          const localPhone = '05' + m.substring(4);
          const localIndexRef = db.collection('phone_index').doc(localPhone);
          currentBatch.set(localIndexRef, { email: email, uid: uid }, { merge: true });
          currentBatchOps++;
        }
      }

      await commitBatchIfNeeded(false);
    }

    // Commit any remaining operations
    await commitBatchIfNeeded(true);
    await Promise.all(batchPromises);

    console.log('========================================================');
    console.log('🎉 تمت المزامنة بنجاح تام!');
    console.log(`✔️ إجمالي العقود المعالجة والمرفوعة: ${processedCount}`);
    console.log(`👤 حسابات مستأجرين جديدة تم إنشاؤها: ${authCreatedCount}`);
    console.log(`🔄 حسابات مستأجرين تم تحديثها: ${authExistingCount}`);
    console.log('========================================================');

  } catch (error) {
    console.error('❌ حدث خطأ أثناء المزامنة:', error);
  } finally {
    if (pool) {
      await pool.close();
      console.log('🔒 تم إغلاق الاتصال بقاعدة البيانات.');
    }
  }
}

// Execution: Single run by default, or looped if --loop <minutes> passed
const args = process.argv.slice(2);
const loopIndex = args.indexOf('--loop');

if (loopIndex !== -1) {
  const intervalMinutes = parseInt(args[loopIndex + 1], 10) || 60;
  console.log(`⏱️ تم تفعيل المزامنة التلقائية المتكررة كل ${intervalMinutes} دقيقة.`);
  
  // Run immediately, then repeat
  runSync().catch(console.error);
  setInterval(() => {
    console.log(`\n⏰ [${new Date().toLocaleString()}] بدء دورة المزامنة الدورية...`);
    runSync().catch(console.error);
  }, intervalMinutes * 60 * 1000);
} else {
  // Single execution (ideal for Windows Task Scheduler or manual run)
  runSync();
}
