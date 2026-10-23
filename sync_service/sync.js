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
function extractValidEmail(rawEmail, fallbackPhone) {
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
  return `${fallbackPhone}@elitelivingre.ae`;
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
      ORDER BY v.BuildingName, v.FlatNo;
    `;

    console.log('⏳ جاري استرجاع العقود النشطة مع الإيميلات الحقيقية لسنة 2026 وما بعدها...');
    const result = await pool.request().query(query);
    const rows = result.recordset;
    console.log(`📋 تم استرجاع ${rows.length} عقداً من قاعدة البيانات.`);

    if (rows.length === 0) {
      console.log('ℹ️ لا توجد عقود تطابق الشروط حالياً.');
      return;
    }

    // Pre-fetch all Firebase Auth users in 1 call for blazing-fast in-memory lookup
    console.log('⏳ جاري تحميل حسابات المستخدمين من Firebase...');
    const allUsersResult = await auth.listUsers(1000);
    const userByPhone = new Map();
    const userByEmail = new Map();
    for (const u of allUsersResult.users) {
      if (u.phoneNumber) userByPhone.set(u.phoneNumber, u);
      if (u.email) userByEmail.set(u.email.toLowerCase(), u);
    }
    console.log(`👤 تم العثور على ${allUsersResult.users.length} حساب موجود مسبقاً.`);

    let processedCount = 0;
    let skippedCount = 0;
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

    console.log('⏳ جاري معالجة العقود وتحديث الحسابات...');
    for (const row of rows) {
      const sanitizedPhone = sanitizeUaeMobile(row.mobileNumber);
      if (!sanitizedPhone) {
        skippedCount++;
        continue;
      }

      const tenantName = row.tenantName || 'مستأجر';
      const buildingName = row.buildingName || 'غير محدد';
      const unitNumber = row.unitNumber || '';
      const email = extractValidEmail(row.customerEmail, sanitizedPhone);
      const defaultPassword = sanitizedPhone; // الباسوورد هو رقم هاتف المستأجر

      // Timezone-safe date helpers (avoid UTC midnight shifting the day backwards)
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

      const startTimestamp = toMiddayTimestamp(row.startDate);
      const endTimestamp = toMiddayTimestamp(row.endDate);
      const startIso = toCalendarIsoString(row.startDate);
      const endIso = toCalendarIsoString(row.endDate);

      // 1. Fast In-Memory Lookup & Auth Sync
      let uid;
      try {
        const phoneKey = `+${sanitizedPhone}`;
        const emailKey = email.toLowerCase();
        let existingUser = userByPhone.get(phoneKey) || userByEmail.get(emailKey);

        if (existingUser) {
          uid = existingUser.uid;
          const needsUpdate = existingUser.email !== email || 
                              !existingUser.phoneNumber || 
                              existingUser.displayName !== tenantName;
          
          if (needsUpdate) {
            const updatePayload = {
              displayName: tenantName,
              password: defaultPassword
            };
            if (existingUser.email !== email) updatePayload.email = email;
            if (!existingUser.phoneNumber) updatePayload.phoneNumber = phoneKey;
            
            await auth.updateUser(uid, updatePayload);
          }
          authExistingCount++;
        } else {
          try {
            const newUser = await auth.createUser({
              email: email,
              password: defaultPassword,
              displayName: tenantName,
              phoneNumber: phoneKey
            });
            uid = newUser.uid;
            userByPhone.set(phoneKey, newUser);
            userByEmail.set(emailKey, newUser);
            authCreatedCount++;
          } catch (createErr) {
            if (createErr.code === 'auth/email-already-exists') {
              const u = await auth.getUserByEmail(email);
              uid = u.uid;
              userByEmail.set(emailKey, u);
              authExistingCount++;
            } else if (createErr.code === 'auth/phone-number-already-exists') {
              const u = await auth.getUserByPhoneNumber(phoneKey);
              uid = u.uid;
              userByPhone.set(phoneKey, u);
              authExistingCount++;
            } else {
              throw createErr;
            }
          }
        }
      } catch (err) {
        console.warn(`⚠️ تعذر تحديث/إنشاء حساب Auth للرقم ${sanitizedPhone} (${email}):`, err.message);
      }

      // 2. Prepare Contract Document in `contracts`
      const safeContractCode = (row.contractCode || `${row.unitNumber}_${row.contractNumber || ''}`)
        .toString()
        .replace(/[\/\\#\s]/g, '_');
      const contractDocId = `${sanitizedPhone}_${safeContractCode}`;
      const contractRef = db.collection('contracts').doc(contractDocId);
      const contractData = {
        contractCode: row.contractCode || '',
        contractNumber: row.contractNumber || null,
        buildingName: buildingName,
        unitNumber: unitNumber,
        unitType: row.unitType || '',
        tenantName: tenantName,
        mobileNumber: sanitizedPhone,
        customerEmail: email,
        email: email,
        startDate: startTimestamp,
        endDate: endTimestamp,
        rentAmount: row.rentAmount || 0,
        yearValue: row.yearValue || 0,
        contractState: row.contractState || 'valid',
        tenantUid: uid || null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      currentBatch.set(contractRef, contractData, { merge: true });
      currentBatchOps++;

      // 3. Prepare User Document in `users/{uid}` so Flutter App & Admin display it immediately!
      if (uid) {
        const userRef = db.collection('users').doc(uid);
        const userData = {
          name: tenantName,
          phone: sanitizedPhone,
          email: email,
          role: 'tenant',
          apartmentId: unitNumber,
          buildingId: buildingName,
          contractStartDate: startIso,
          contractEndDate: endIso,
          contractCode: row.contractCode || '',
          rentAmount: row.rentAmount || 0,
          yearValue: row.yearValue || 0,
          unitType: row.unitType || '',
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        currentBatch.set(userRef, userData, { merge: true });
        currentBatchOps++;

        // 4. Set phone_index mapping for secure, fast login by phone
        const phoneIndexRef = db.collection('phone_index').doc(sanitizedPhone);
        currentBatch.set(phoneIndexRef, { email: email }, { merge: true });
        currentBatchOps++;

        if (sanitizedPhone.startsWith('9715') && sanitizedPhone.length === 12) {
          const localPhone = '05' + sanitizedPhone.substring(4);
          const localIndexRef = db.collection('phone_index').doc(localPhone);
          currentBatch.set(localIndexRef, { email: email }, { merge: true });
          currentBatchOps++;
        }
      }

      processedCount++;
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
    console.log(`⚠️ عقود تم استبعادها (رقم هاتف غير إماراتي/غير صالح): ${skippedCount}`);
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
