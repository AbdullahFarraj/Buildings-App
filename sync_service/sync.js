const sql = require('mssql/msnodesqlv8');
const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');
const os = require('os');
const crypto = require('crypto');

// 1. Initialize Firebase Admin SDK (Supports --env=dev or --env=prod)
const isDev = process.argv.includes('--env=dev') || process.argv.includes('--dev');
let serviceAccountPath;

if (isDev) {
  serviceAccountPath = path.resolve(__dirname, 'serviceAccountKey.dev.json');
} else {
  serviceAccountPath = path.resolve(__dirname, 'serviceAccountKey.prod.json');
  if (!fs.existsSync(serviceAccountPath)) {
    serviceAccountPath = path.resolve(__dirname, 'serviceAccountKey.json');
  }
  if (!fs.existsSync(serviceAccountPath)) {
    serviceAccountPath = path.resolve(__dirname, '../serviceAccountKey.json');
  }
}

if (!fs.existsSync(serviceAccountPath)) {
  console.error(`❌ Error: Service account key file not found (${serviceAccountPath}).`);
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);
const expectedProjectId = isDev ? 'binshafar-properties-dev' : 'building-app1';
if (serviceAccount.project_id !== expectedProjectId) {
  console.error(`❌ Error: Environment mismatch! Expected project "${expectedProjectId}" but key has "${serviceAccount.project_id}".`);
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

console.log('========================================================');
console.log(`🚀 [Sync Engine] Active Project: ${serviceAccount.project_id} [${isDev ? 'DEVELOPMENT / DEV' : 'PRODUCTION / PROD'}]`);
console.log('========================================================');

const db = admin.firestore();
const auth = admin.auth();

// 2. SQL Server Configuration (Auto-detects local SQL Server & Driver, or reads sql_config.json)
let fileSqlConfig = {};
const sqlConfigPath = path.resolve(__dirname, 'sql_config.json');
if (fs.existsSync(sqlConfigPath)) {
  try {
    fileSqlConfig = JSON.parse(fs.readFileSync(sqlConfigPath, 'utf8'));
  } catch (_) {}
}

const configuredServer = process.env.SQL_SERVER || fileSqlConfig.server || 'AUTO';
const SQL_DATABASE = process.env.SQL_DATABASE || fileSqlConfig.database || 'AlAqaree7';

async function connectToSqlServer() {
  const host = os.hostname();
  const serverCandidates = configuredServer && configuredServer.toUpperCase() !== 'AUTO'
    ? [configuredServer, `${host}\\SQLEXPRESS`, '.\\SQLEXPRESS', host, '.']
    : [`${host}\\SQLEXPRESS`, '.\\SQLEXPRESS', 'localhost\\SQLEXPRESS', host, '.', 'ABDULLAH-LAP\\SQLEXPRESS'];

  const uniqueServers = [...new Set(serverCandidates.filter(Boolean))];
  const driverCandidates = [
    '{SQL Server Native Client 10.0}',
    '{SQL Server Native Client 11.0}',
    '{ODBC Driver 17 for SQL Server}',
    '{ODBC Driver 18 for SQL Server}',
    '{SQL Server}'
  ];

  let lastErr = null;
  for (const srv of uniqueServers) {
    for (const drv of driverCandidates) {
      const connStr = `Driver=${drv};Server=${srv};Database=${SQL_DATABASE};Trusted_Connection=yes;Encrypt=no;TrustServerCertificate=yes;`;
      const cfg = {
        connectionString: connStr,
        server: srv,
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
      try {
        const pool = await new sql.ConnectionPool(cfg).connect();
        console.log(`✅ تم الاتصال بقاعدة البيانات بنجاح: السيرفر (${srv}) | قاعدة البيانات (${SQL_DATABASE})`);
        return pool;
      } catch (err) {
        lastErr = err;
        const msg = String(err.message || '');
        // If driver itself is not installed on this machine, skip to next driver immediately
        if (msg.includes('Data source name not found') || msg.includes('IM002')) {
          continue;
        }
        // If server wasn't found, no need to try other drivers for the same non-existent server name
        if (msg.includes('Error Locating Server') || msg.includes('Server is not found')) {
          break;
        }
      }
    }
  }
  throw lastErr || new Error('تعذر الاتصال بقاعدة بيانات SQL Server.');
}

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
  console.log('🚀 بدء مزامنة عقود الإيجار مع Firebase (Saeed BinShafar Properties / العقاري)...');
  console.log('========================================================');

  let pool;
  try {
    console.log(`⏳ جاري البحث والاتصال بقاعدة بيانات SQL Server (${SQL_DATABASE})...`);
    pool = await connectToSqlServer();

    // Fetch active & renewed contracts for the current year and upcoming years
    // Filter strictly by ContractState = 'valid' to match the system's exact active contracts count
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
          LTRIM(RTRIM(v.ContractState))         AS contractState,
          v.CustomerGuid                        AS customerGuid,
          c.AcGuid                              AS customerAcGuid,
          v.Guid                                AS contractGuid
      FROM vwLeaseApartment v
      LEFT JOIN Customer c ON v.CustomerGuid = c.Guid
      WHERE LTRIM(RTRIM(v.ContractState)) = 'valid'
        AND YEAR(v.ToDate) >= YEAR(GETDATE())
      ORDER BY v.CustName, v.BuildingName, v.FlatNo, v.ToDate DESC, v.FromDate DESC;
    `;

    console.log('⏳ جاري استرجاع العقود السارية والمجددة للسنة الحالية والسنوات القادمة...');
    const result = await pool.request().query(query);
    const rows = result.recordset;
    console.log(`📋 تم استرجاع ${rows.length} عقداً نشطاً من قاعدة البيانات.`);

    console.log('⏳ جاري استرجاع الشيكات وحالاتها الدقيقة (صرف، إرجاع، إعادة إيداع، سداد كاش)...');
    const chequesQuery = `
      WITH CollectionAgg AS (
        SELECT 
          col.CheckGuid,
          MAX(CASE WHEN ISNULL(col.FixReturn, 0) = 1 OR ISNULL(col.Finished, 0) = 1 THEN 1 ELSE 0 END) AS hasFixReturn,
          MAX(CASE WHEN col.Kind = 3 THEN 1 ELSE 0 END) AS hasColReturn,
          MAX(CASE WHEN 
               col.Note LIKE '%cash%' OR col.Note LIKE '%كاش%' OR col.Note LIKE '%نقد%' OR col.Note LIKE '%سداد%' OR col.Note LIKE '%تسديد%' OR col.Note LIKE '%بدل%' OR col.Note LIKE '%استبدال%' OR col.Note LIKE '%replace%' OR col.Note LIKE '%rplc%'
            OR col.ReturnCause LIKE '%cash%' OR col.ReturnCause LIKE '%كاش%' OR col.ReturnCause LIKE '%نقد%' OR col.ReturnCause LIKE '%سداد%' OR col.ReturnCause LIKE '%تسديد%' OR col.ReturnCause LIKE '%بدل%' OR col.ReturnCause LIKE '%استبدال%' OR col.ReturnCause LIKE '%replace%' OR col.ReturnCause LIKE '%rplc%'
            OR col.FixReturnNote LIKE '%cash%' OR col.FixReturnNote LIKE '%كاش%' OR col.FixReturnNote LIKE '%نقد%' OR col.FixReturnNote LIKE '%سداد%' OR col.FixReturnNote LIKE '%تسديد%' OR col.FixReturnNote LIKE '%بدل%' OR col.FixReturnNote LIKE '%استبدال%' OR col.FixReturnNote LIKE '%replace%' OR col.FixReturnNote LIKE '%rplc%'
          THEN 1 ELSE 0 END) AS hasCashNote
        FROM ChecksCollection col
        GROUP BY col.CheckGuid
      ),
      LatestCollection AS (
        SELECT 
          col.CheckGuid,
          col.Kind,
          col.Date AS actionDate,
          col.Finished,
          col.FixReturn,
          col.FixReturnNote,
          col.ReturnCause,
          col.Note AS colNote,
          ROW_NUMBER() OVER (PARTITION BY col.CheckGuid ORDER BY col.Date DESC) AS rn
        FROM ChecksCollection col
      )
      SELECT 
          c.Guid                         AS checkGuid,
          LTRIM(RTRIM(c.NO))             AS chequeNumber,
          c.Value                        AS amount,
          c.DueDate                      AS dueDate,
          c.Date                         AS date,
          LTRIM(RTRIM(c.BankName))       AS bankName,
          LTRIM(RTRIM(c.Note))           AS notes,
          LTRIM(RTRIM(c.Note2))          AS notes2,
          LTRIM(RTRIM(c.Note3))          AS notes3,
          LTRIM(RTRIM(c.Note4))          AS notes4,
          c.ObverseAccount               AS obverseAccount,
          LTRIM(RTRIM(lc.colNote))       AS colNote,
          LTRIM(RTRIM(lc.ReturnCause))   AS returnCause,
          LTRIM(RTRIM(lc.FixReturnNote)) AS fixReturnNote,
          ISNULL(ca.hasFixReturn, 0)     AS hasFixReturn,
          ISNULL(ca.hasColReturn, 0)     AS hasColReturn,
          ISNULL(ca.hasCashNote, 0)      AS hasCashNote,
          lc.Kind                        AS latestColKind,
          c.ContractGuid                 AS contractGuid,
          c.Deposition                   AS deposition,
          CASE 
            WHEN ISNULL(ca.hasFixReturn, 0) = 1 OR ISNULL(ca.hasCashNote, 0) = 1
                 OR ISNULL(lc.FixReturn, 0) = 1 OR ISNULL(lc.Finished, 0) = 1 
                 OR lc.colNote LIKE '%cash%' OR lc.colNote LIKE '%كاش%' OR lc.colNote LIKE '%نقد%' OR lc.colNote LIKE '%سداد%' OR lc.colNote LIKE '%تسديد%' OR lc.colNote LIKE '%replace%' OR lc.colNote LIKE '%rplc%'
                 OR lc.ReturnCause LIKE '%cash%' OR lc.ReturnCause LIKE '%كاش%' OR lc.ReturnCause LIKE '%نقد%' OR lc.ReturnCause LIKE '%سداد%' OR lc.ReturnCause LIKE '%تسديد%' OR lc.ReturnCause LIKE '%replace%' OR lc.ReturnCause LIKE '%rplc%'
                 OR lc.FixReturnNote LIKE '%cash%' OR lc.FixReturnNote LIKE '%كاش%' OR lc.FixReturnNote LIKE '%نقد%' OR lc.FixReturnNote LIKE '%سداد%' OR lc.FixReturnNote LIKE '%تسديد%' OR lc.FixReturnNote LIKE '%replace%' OR lc.FixReturnNote LIKE '%rplc%'
              THEN 'paid_cash'
            WHEN lc.Kind = 1 OR (c.Deposition = 1 AND (lc.Kind IS NULL OR lc.Kind != 3))
              THEN 'paid'
            WHEN lc.Kind = 3
              THEN 'bounced'
            ELSE 'pending'
          END                            AS chequeStatus,
          CASE 
            WHEN lc.Kind = 1 THEN lc.actionDate
            ELSE NULL
          END                            AS depositDate
      FROM Checks c
      INNER JOIN vwLeaseApartment v ON c.ContractGuid = v.Guid
      LEFT JOIN LatestCollection lc ON lc.CheckGuid = c.Guid AND lc.rn = 1
      LEFT JOIN CollectionAgg ca ON ca.CheckGuid = c.Guid
      WHERE LTRIM(RTRIM(v.ContractState)) = 'valid'
        AND YEAR(v.ToDate) >= YEAR(GETDATE())
        AND (c.DueDate IS NULL OR YEAR(c.DueDate) >= YEAR(GETDATE()))
      ORDER BY c.DueDate ASC, c.NO ASC;
    `;
    const chequesResult = await pool.request().query(chequesQuery);
    const chequesRows = chequesResult.recordset;
    console.log(`💳 تم استرجاع ${chequesRows.length} شيكاً من قاعدة البيانات.`);

    console.log('⏳ جاري فحص قيود اليومية (Journal Entries) لتتبع إعادة الإيداع والسداد النقدي والتحويلات للشيكات...');
    const journalQuery = `
      SELECT 
          h.Number             AS headerNum,
          h.Date               AS entryDate,
          d.AcGuid             AS acGuid,
          d.ObverseAcGuid      AS obverseAcGuid,
          d.Debit              AS debit,
          d.Credit             AS credit,
          LTRIM(RTRIM(d.Note)) AS note
      FROM DEntry d
      INNER JOIN HEntry h ON d.ParentGuid = h.Guid
      WHERE h.Date >= '2025-01-01'
        AND d.Note IS NOT NULL
        AND (
          d.Note LIKE '%Cheque%' OR d.Note LIKE '%CHQ%' OR d.Note LIKE '%RTC%' 
          OR d.Note LIKE '%RTRN%' OR d.Note LIKE '%RTN%' OR d.Note LIKE '%DPST%' 
          OR d.Note LIKE '%RPLC%' OR d.Note LIKE '%كاش%' OR d.Note LIKE '%شيك%'
        );
    `;
    const journalResult = await pool.request().query(journalQuery);
    const journalByChqNo = new Map();
    const journalWithoutChqNo = [];
    for (const jRow of journalResult.recordset) {
      if (!jRow.note) continue;
      const noteStr = String(jRow.note).trim();
      const mNo = noteStr.match(/Cheque No\.\s*([0-9A-Za-z]+)/i) || noteStr.match(/CHQ\s*#?\s*([0-9]{2,})/i);
      const item = {
        date: jRow.entryDate ? new Date(jRow.entryDate).toISOString().substring(0, 10) : '',
        rawDate: jRow.entryDate || null,
        headerNum: Number(jRow.headerNum) || 0,
        acGuid: jRow.acGuid ? String(jRow.acGuid).toLowerCase() : '',
        obverseAcGuid: jRow.obverseAcGuid ? String(jRow.obverseAcGuid).toLowerCase() : '',
        debit: Number(jRow.debit) || 0,
        credit: Number(jRow.credit) || 0,
        note: noteStr
      };
      if (mNo) {
        const chqNoNorm = mNo[1].trim().replace(/^0+/, '') || '0';
        if (!journalByChqNo.has(chqNoNorm)) journalByChqNo.set(chqNoNorm, []);
        journalByChqNo.get(chqNoNorm).push(item);
      } else {
        journalWithoutChqNo.push(item);
      }
    }
    console.log(`📑 تم تحليل ${journalResult.recordset.length} قيد يومية مرتبط بالشيكات.`);

    function resolveChequeLifecycle(ch, tenantName, customerAcGuid) {
      const chqNoNorm = String(ch.chequeNumber || '').trim().replace(/^0+/, '') || '0';
      const candidates = journalByChqNo.get(chqNoNorm) || [];
      const custNameUpper = String(tenantName || '').trim().toUpperCase();
      const custAc = String(customerAcGuid || ch.obverseAccount || '').trim().toLowerCase();
      const chqNoteCore = String(ch.notes || '').trim();
      const val = Number(ch.amount) || 0;
      const dueMs = ch.dueDate ? new Date(ch.dueDate).getTime() : 0;

      const matched = candidates.filter(j => {
        if (chqNoteCore && j.note.includes(chqNoteCore)) return true;
        if (custAc && (j.acGuid === custAc || j.obverseAcGuid === custAc)) return true;
        if (custNameUpper && j.note.toUpperCase().includes(custNameUpper)) return true;
        return false;
      });

      // Fallback for long notes where Cheque No. at the end was truncated
      if (dueMs > 0) {
        for (const j of journalWithoutChqNo) {
          const sameTenant = (custAc && (j.acGuid === custAc || j.obverseAcGuid === custAc)) ||
                             (custNameUpper && j.note.toUpperCase().includes(custNameUpper));
          if (!sameTenant) continue;
          const sameAmt = Math.abs(j.debit - val) < 1 || Math.abs(j.credit - val) < 1;
          if (!sameAmt) continue;
          const jMs = j.rawDate ? new Date(j.rawDate).getTime() : 0;
          const diffDays = (jMs - dueMs) / (1000 * 60 * 60 * 24);
          if (diffDays >= -15 && diffDays <= 90) {
            matched.push(j);
          }
        }
      }

      matched.sort((a, b) => (a.date || '').localeCompare(b.date || '') || (a.headerNum - b.headerNum));

      let hasDeposit = ch.latestColKind === 1 || ch.deposition === 1 || ch.deposition === true;
      let hasReturn = ch.latestColKind === 3 || ch.hasColReturn === 1;
      let hasRedeposit = ch.latestColKind === 1 && ch.hasColReturn === 1;
      let hasCashSettle = ch.chequeStatus === 'paid_cash' || ch.hasFixReturn === 1 || ch.hasCashNote === 1;
      let hasBankTrf = false;
      let isCancelledOrReplaced = false;
      let maxReturnDate = '';
      let maxReturnNum = -1;
      let maxDepDate = '';
      let maxDepNum = -1;
      let effectiveDepositDate = ch.depositDate || null;
      let returnReasonText = '';

      for (const j of matched) {
        const idx = j.note.indexOf('Cheque received from');
        const prefix = (idx > 0 ? j.note.substring(0, idx) : j.note).trim().toUpperCase();
        if (!prefix || idx === 0) continue;

        // Ignore penalty, VAT, and replacement fee lines
        if (/^(5%\s*VAT|TAXABLE|TAXALBE|PENALT|5%\s*PENALT|CASH RCVD FOR (PENALTY|CHQ|EJARI|ADMIN)|CASH DPSTD FOR (PENALTY|CHQ|EJARI|ADMIN)|CASH RCVD\s*-\s*PENALTY|CASH DPSTD\s*-\s*PENALTY|CHQ RCVD FOR CHQ RTRN PENALTY|CHQ RPLCD CHARGES)/i.test(prefix)) {
          continue;
        }

        const firstPart = prefix.split('-')[0].trim();

        if (/^(CASH RCVD|CASH DPSTD|DPSTD-CASH RCVD|PARTIAL CASH|BALANCE CASH|BLC CASH|BALANCE DPSTD|CASH TFRD|FULL SETLMNT)/i.test(prefix)) {
          hasCashSettle = true;
          if (j.rawDate) effectiveDepositDate = j.rawDate;
        } else if (/^(FUND TRF|FUN TRF|FUND RCVD|PARTIAL FUND|BALANCE FUND|BT\b|PARTIAL AMOUNT TRANSFER)/i.test(prefix)) {
          hasBankTrf = true;
          hasCashSettle = true;
          if (j.rawDate) effectiveDepositDate = j.rawDate;
        } else if (/REDPST|REDEPOSIT|RE-DPST/i.test(prefix)) {
          hasRedeposit = true;
          if (j.rawDate) effectiveDepositDate = j.rawDate;
        } else if (/RPLC NEW CHQ|RPLC WITH NEW CHQ|RPLC CHQ \(|REPLACE 5 CHQS|RPLCED WITH NEW CHQ|EARLY VACAT|EALRY VACAT|DUE TO TERMINATION|GUARANTEE CANCLED/i.test(prefix)) {
          isCancelledOrReplaced = true;
        } else if (/^(CHQ DPSTD|CHQ DSPTD|CHQ DPTSD|CHQ DPTD|CHQ DPST|CHQ DPTS|DPSTD|DPSTED)$/i.test(firstPart) && !/RTRN|RTC|RTN/i.test(prefix)) {
          hasDeposit = true;
          if (j.rawDate) effectiveDepositDate = j.rawDate;
          if (j.date > maxDepDate || (j.date === maxDepDate && j.headerNum > maxDepNum)) {
            maxDepDate = j.date;
            maxDepNum = j.headerNum;
          }
        } else if (/RTRN|RTC|RTN|XLD|CNCLD|RETURN/i.test(prefix)) {
          hasReturn = true;
          if (/INF/i.test(prefix)) returnReasonText = 'Returned - Insufficient Funds';
          else if (/SIGN/i.test(prefix)) returnReasonText = 'Returned - Signature Mismatch';
          else if (/CLOSED|FROZEN|BLOCKED/i.test(prefix)) returnReasonText = 'Returned - Account Closed';
          else if (/TECH|ALTER/i.test(prefix)) returnReasonText = 'Returned - Technical Error';
          if (j.date > maxReturnDate || (j.date === maxReturnDate && j.headerNum > maxReturnNum)) {
            maxReturnDate = j.date;
            maxReturnNum = j.headerNum;
          }
        }
      }

      if (maxReturnDate && maxDepDate && (maxDepDate > maxReturnDate || (maxDepDate === maxReturnDate && maxDepNum > maxReturnNum))) {
        hasRedeposit = true;
      }

      const n34 = ((ch.notes3 || '') + ' ' + (ch.notes4 || '')).toUpperCase();
      if (n34.includes('ALREADY TRANSFER')) {
        hasBankTrf = true;
        hasCashSettle = true;
      }

      let status = 'pending';
      let conciseNote = null;

      if (hasCashSettle) {
        status = 'paid_cash';
        conciseNote = hasBankTrf
          ? (hasReturn ? 'Bounced - Settled via Bank Transfer' : 'Settled via Bank Transfer')
          : (hasReturn ? 'Bounced - Settled in Cash' : 'Settled in Cash');
      } else if (hasRedeposit) {
        status = 'paid';
        conciseNote = 'Bounced & Re-deposited (Cleared)';
      } else if (isCancelledOrReplaced) {
        status = 'cancelled';
        conciseNote = 'Replaced / Cancelled';
      } else if (hasReturn) {
        status = 'bounced';
        conciseNote = returnReasonText || 'Returned from Bank';
      } else if (hasDeposit) {
        status = 'paid';
        conciseNote = 'Deposited & Cleared';
      } else {
        status = 'pending';
        conciseNote = null;
      }

      return { status, conciseNote, depositDate: effectiveDepositDate };
    }

    console.log('⏳ جاري استرجاع أرصدة المستأجرين من دفتر الأستاذ (General Ledger)...');
    const ledgerQuery = `
      SELECT 
          c.Guid AS customerGuid,
          ROUND(ISNULL(SUM(de.DDebit), 0) - ISNULL(SUM(de.DCredit), 0), 2) AS ledgerBalance,
          ROUND(ISNULL(SUM(de.DDebit), 0), 2) AS totalDebit,
          ROUND(ISNULL(SUM(de.DCredit), 0), 2) AS totalCredit
      FROM Customer c
      INNER JOIN vwDetailEntry de ON de.AcGuid = c.AcGuid
      GROUP BY c.Guid;
    `;
    const ledgerResult = await pool.request().query(ledgerQuery);
    const ledgerByCustomerGuid = new Map();
    for (const row of ledgerResult.recordset) {
      if (!row.customerGuid) continue;
      ledgerByCustomerGuid.set(String(row.customerGuid).toLowerCase(), {
        ledgerBalance: Number(row.ledgerBalance) || 0,
        totalDebit: Number(row.totalDebit) || 0,
        totalCredit: Number(row.totalCredit) || 0,
      });
    }
    console.log(`📒 تم استرجاع أرصدة دفتر الأستاذ لـ ${ledgerByCustomerGuid.size} عميلاً.`);

    // Group cheques by contractGuid (deduplicated by checkGuid / chequeNumber)
    const chequesByContractGuid = new Map();
    const seenCheckGuids = new Set();
    for (const ch of chequesRows) {
      if (!ch.contractGuid) continue;
      const chkKey = ch.checkGuid ? String(ch.checkGuid).toLowerCase() : `${ch.contractGuid}_${ch.chequeNumber}`;
      if (seenCheckGuids.has(chkKey)) continue;
      seenCheckGuids.add(chkKey);

      const key = String(ch.contractGuid).toLowerCase();
      if (!chequesByContractGuid.has(key)) {
        chequesByContractGuid.set(key, []);
      }
      chequesByContractGuid.get(key).push(ch);
    }

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

    // Pre-fetch ALL Firebase Auth users (paginated, 1000 per page) for fast in-memory lookup
    console.log('⏳ جاري تحميل حسابات المستخدمين من Firebase...');
    const allAuthUsers = [];
    let pageToken;
    do {
      const page = await auth.listUsers(1000, pageToken);
      allAuthUsers.push(...page.users);
      pageToken = page.pageToken;
    } while (pageToken);
    const allUsersResult = { users: allAuthUsers };
    const userByPhone = new Map();
    const userByEmail = new Map();
    const userByName = new Map();

    // Pre-fetch existing Firestore users FIRST so we know which UIDs are admin/technician/demo
    const firestoreUsersSnap = await db.collection('users').get();
    const firestoreDataByUid = new Map();
    const nonTenantUids = new Set();
    const protectedUids = new Set();
    for (const doc of firestoreUsersSnap.docs) {
      const data = doc.data();
      firestoreDataByUid.set(doc.id, data);
      if (data.role === 'admin' || data.role === 'technician' || data.isDemo === true) {
        protectedUids.add(doc.id);
      }
      if (data.role === 'admin' || data.role === 'technician') {
        nonTenantUids.add(doc.id);
      }
    }

    for (const u of allUsersResult.users) {
      // Never match a real tenant contract onto an Admin, Technician, or Demo account
      if (protectedUids.has(u.uid)) continue;
      if (u.phoneNumber) userByPhone.set(u.phoneNumber, u);
      if (u.email) userByEmail.set(u.email.toLowerCase(), u);
      if (u.displayName) userByName.set(normalizeTenantName(u.displayName).toLowerCase(), u);
    }

    for (const [docId, data] of firestoreDataByUid.entries()) {
      if (protectedUids.has(docId)) continue;
      const syntheticUser = { uid: docId, ...data };
      const sanitizedDocPhone = sanitizeUaeMobile(data.phone);
      if (sanitizedDocPhone && !userByPhone.has(`+${sanitizedDocPhone}`)) {
        userByPhone.set(`+${sanitizedDocPhone}`, syntheticUser);
      }
      if (data.email && !userByEmail.has(String(data.email).toLowerCase())) {
        userByEmail.set(String(data.email).toLowerCase(), syntheticUser);
      }
      if (data.name) {
        const norm = normalizeTenantName(data.name).toLowerCase();
        if (!userByName.has(norm)) {
          userByName.set(norm, syntheticUser);
        }
      }
    }
    console.log(`👤 تم العثور على ${allUsersResult.users.length} حساب Auth و ${firestoreUsersSnap.size} مستخدم في Firestore.`);

    // Load user-requested account deletions (deleted_accounts) so sync never re-creates opted-out users
    const deletedEmails = new Set();
    const deletedPhones = new Set();
    const deletedAccountsSnap = await db.collection('deleted_accounts').get();
    for (const dDoc of deletedAccountsSnap.docs) {
      const dData = dDoc.data() || {};
      if (dData.email) deletedEmails.add(String(dData.email).trim().toLowerCase());
      if (Array.isArray(dData.phones)) {
        for (const ph of dData.phones) {
          const san = sanitizeUaeMobile(ph);
          if (san) deletedPhones.add(san);
        }
      }
    }
    if (deletedAccountsSnap.size > 0) {
      console.log(`🛡️ تم تحميل ${deletedAccountsSnap.size} سجل لحسابات محذوفة بناءً على طلب أصحابها (سيتم استثناؤها من المزامنة).`);
    }

    let processedCount = 0;
    let chequesSyncedCount = 0;
    let authCreatedCount = 0;
    let authExistingCount = 0;

    // Sets to track active documents for post-sync cleanup of old/terminated/duplicate records
    const activeContractDocIds = new Set();
    const activeChequeDocIds = new Set();
    const activeTenantUids = new Set();
    const activePhoneIndexIds = new Set();

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

    // Group rows by customer identity (CustomerGuid + shared valid mobile number)
    // Also deduplicate contracts by contractCode/contractGuid in case a view returns duplicate rows
    console.log('⏳ جاري تجميع كافة العقود حسب هوية العميل (CustomerGuid + رقم الهاتف)...');
    const rawGroups = new Map();
    const seenContractKeys = new Set();
    for (const row of rows) {
      const uniqueContractKey = row.contractGuid
        ? String(row.contractGuid).toLowerCase()
        : String(row.contractCode || `${row.buildingName}_${row.unitNumber}_${row.contractNumber}`).toLowerCase();
      if (seenContractKeys.has(uniqueContractKey)) continue;
      seenContractKeys.add(uniqueContractKey);

      const normName = normalizeTenantName(row.tenantName);
      const key = row.customerGuid
        ? `guid:${String(row.customerGuid).toLowerCase()}`
        : `name:${normName.toLowerCase()}`;
      if (!rawGroups.has(key)) {
        rawGroups.set(key, { key, name: normName, contracts: [], rawMobiles: [], customerEmails: [] });
      }
      const g = rawGroups.get(key);
      g.contracts.push(row);
      if (row.mobileNumber) g.rawMobiles.push(row.mobileNumber);
      if (row.customerEmail) g.customerEmails.push(row.customerEmail);
    }

    // Union-find: merge groups sharing a sanitized mobile number
    const parent = new Map([...rawGroups.keys()].map(k => [k, k]));
    const find = (k) => { while (parent.get(k) !== k) { parent.set(k, parent.get(parent.get(k))); k = parent.get(k); } return k; };
    const mobileToKey = new Map();
    for (const g of rawGroups.values()) {
      for (const m of g.rawMobiles) {
        const s = sanitizeUaeMobile(m);
        if (!s) continue;
        if (mobileToKey.has(s)) parent.set(find(g.key), find(mobileToKey.get(s)));
        else mobileToKey.set(s, g.key);
      }
    }
    const tenantGroups = new Map();
    for (const g of rawGroups.values()) {
      const root = find(g.key);
      if (!tenantGroups.has(root)) {
        tenantGroups.set(root, { key: root, name: rawGroups.get(root).name, contracts: [], rawMobiles: [], customerEmails: [] });
      }
      const target = tenantGroups.get(root);
      target.contracts.push(...g.contracts);
      target.rawMobiles.push(...g.rawMobiles);
      target.customerEmails.push(...g.customerEmails);
    }
    console.log(`👥 تم العثور على ${tenantGroups.size} مستأجر فريد من أصل ${seenContractKeys.size} عقداً نشطاً.`);

    // Report names shared by more than one distinct tenant
    const nameCounts = new Map();
    for (const g of tenantGroups.values()) {
      const n = g.name.toLowerCase();
      nameCounts.set(n, (nameCounts.get(n) || 0) + 1);
    }
    const sharedNames = [...nameCounts.entries()].filter(([, c]) => c > 1);
    if (sharedNames.length) {
      console.log(`⚠️ ${sharedNames.length} اسم مشترك بين أكثر من مستأجر مختلف (تم فصلهم):`);
      for (const [n, c] of sharedNames) console.log(`   - ${n} (${c} مستأجرين)`);
    }

    // Tracks which tenant group already claimed a uid or email in this run
    const claimedUids = new Map();
    const claimedEmails = new Set();

    // Pre-analyze shared emails across different tenantGroups so the tenant whose name matches the email gets priority
    const emailOwners = new Map();
    for (const g of tenantGroups.values()) {
      const pMob = g.rawMobiles.map(sanitizeUaeMobile).find(Boolean) || null;
      for (const rawEm of g.customerEmails) {
        const parsed = extractValidEmail(rawEm, pMob);
        if (parsed && !parsed.includes('nocode') && !parsed.endsWith('@elitelivingre.ae')) {
          if (!emailOwners.has(parsed)) emailOwners.set(parsed, []);
          emailOwners.get(parsed).push(g);
        }
      }
    }
    const preferredGroupForEmail = new Map();
    for (const [em, groups] of emailOwners.entries()) {
      if (groups.length === 1) {
        preferredGroupForEmail.set(em, groups[0].key);
      } else {
        const localPart = em.split('@')[0].replace(/[^a-z]/gi, '').toLowerCase();
        let bestGroup = groups[0];
        for (const grp of groups) {
          const nameWords = grp.name.toLowerCase().split(/\s+/).filter(w => w.length >= 3);
          if (nameWords.some(w => localPart.includes(w))) {
            bestGroup = grp;
            break;
          }
        }
        preferredGroupForEmail.set(em, bestGroup.key);
      }
    }

    console.log('⏳ جاري معالجة العقود، ربط العقارات بالحسابات، وتحديث الفايربيس...');
    for (const group of tenantGroups.values()) {
      // Sort tenant's contracts so the newest/renewed contract (highest endDate) comes first
      group.contracts.sort((a, b) => {
        const endA = a.endDate ? new Date(a.endDate).getTime() : 0;
        const endB = b.endDate ? new Date(b.endDate).getTime() : 0;
        if (endB !== endA) return endB - endA;
        const startA = a.startDate ? new Date(a.startDate).getTime() : 0;
        const startB = b.startDate ? new Date(b.startDate).getTime() : 0;
        return startB - startA;
      });

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

      // 2. Resolve email (prefer real customer email if not claimed by another tenant, else phone@elitelivingre.ae, else slug)
      let email = null;
      for (const rawEmail of group.customerEmails) {
        const parsed = extractValidEmail(rawEmail, primaryMobile);
        if (parsed && !parsed.includes('nocode')) {
          const preferredKey = preferredGroupForEmail.get(parsed);
          if ((!preferredKey || preferredKey === group.key) && !claimedEmails.has(parsed)) {
            email = parsed;
            break;
          }
        }
      }
      if (!email) {
        if (primaryMobile && !claimedEmails.has(`${primaryMobile}@elitelivingre.ae`)) {
          email = `${primaryMobile}@elitelivingre.ae`;
        } else {
          const nameHash = crypto.createHash('sha256').update(group.key).digest('hex').substring(0, 16);
          email = `tenant_${nameHash}@elitelivingre.ae`;
        }
      }
      claimedEmails.add(email.toLowerCase());

      // Default password: phone if available, else SYNC_DEFAULT_PASSWORD or a random temporary password
      const defaultPassword = primaryMobile || process.env.SYNC_DEFAULT_PASSWORD || crypto.randomBytes(16).toString('base64url');

      // Respect user-initiated account deletion: skip if email or any phone belongs to deleted_accounts
      if (deletedEmails.has(email.toLowerCase()) || validMobiles.some(m => deletedPhones.has(m))) {
        console.log(`⏭️ تخطي المستأجر (${group.name}) لأنه قام بحذف حسابه مسبقاً.`);
        continue;
      }

      // 3. Build deduplicated physical properties list for this tenant (1 entry per Building + Unit)
      // If a unit has both a 2026 contract and a 2027 renewed contract, keep the latest contract data
      // so the unit is never duplicated in `apartmentId`, `properties`, or `rentAmount`.
      const propertiesByUnitKey = new Map();
      for (const c of group.contracts) {
        const bName = (c.buildingName || 'غير محدد').trim();
        const uNum = (c.unitNumber || '').trim();
        const unitKey = `${bName.toLowerCase()}||${uNum.toLowerCase()}`;
        const startIso = toCalendarIsoString(c.startDate);
        const endIso = toCalendarIsoString(c.endDate);

        if (!propertiesByUnitKey.has(unitKey)) {
          // Since group.contracts is sorted by endDate DESC, this first entry is the newest/renewed contract
          propertiesByUnitKey.set(unitKey, {
            buildingName: bName,
            unitNumber: uNum,
            unitType: (c.unitType || '').trim(),
            contractCode: (c.contractCode || '').trim(),
            contractNumber: c.contractNumber || null,
            startDate: startIso,
            endDate: endIso,
            rentAmount: c.rentAmount || 0,
            yearValue: c.yearValue || 0,
            contractState: c.contractState || 'valid',
          });
        }
      }
      const properties = [...propertiesByUnitKey.values()];

      // 4. In-Memory Lookup & Auth Sync (Priority: Phone -> Email -> Name if unclaimed)
      let uid;
      const nameKey = group.name.toLowerCase();
      const phoneKey = primaryMobile ? `+${primaryMobile}` : null;
      const emailKey = email.toLowerCase();

      // Look up existing user, but prioritize Phone and Email over Name to avoid false merges
      let existingUser = (phoneKey ? userByPhone.get(phoneKey) : null) ||
                         userByEmail.get(emailKey);

      // If matched by phone/email, verify it wasn't claimed by a different tenant in this run
      if (existingUser && claimedUids.has(existingUser.uid) && claimedUids.get(existingUser.uid) !== group.key) {
        existingUser = null;
      }

      // Fallback: match by name ONLY if no conflicting claim exists
      if (!existingUser) {
        const byName = userByName.get(nameKey);
        if (byName && (!claimedUids.has(byName.uid) || claimedUids.get(byName.uid) === group.key)) {
          existingUser = byName;
        }
      }

      try {
        if (existingUser) {
          uid = existingUser.uid;
          const needsUpdate = existingUser.displayName !== group.name ||
                              (existingUser.email && existingUser.email.toLowerCase() !== emailKey) ||
                              (phoneKey && !existingUser.phoneNumber);
          if (needsUpdate && auth.getUser) {
            // ⚠️ لا نعيد تعيين كلمة المرور للحسابات الموجودة حتى لا نلغي كلمة المرور التي غيّرها المستأجر
            const updatePayload = {
              displayName: group.name,
              email: email
            };
            if (phoneKey && !existingUser.phoneNumber) {
              updatePayload.phoneNumber = phoneKey;
            }
            try {
              await auth.updateUser(uid, updatePayload);
              existingUser.email = email;
              userByEmail.set(emailKey, existingUser);
            } catch (upErr) {
              // Ignore harmless phone/email conflict during update
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
              if (!protectedUids.has(u.uid) && !claimedUids.has(u.uid)) {
                uid = u.uid;
                userByEmail.set(emailKey, u);
                userByName.set(nameKey, u);
                authExistingCount++;
              } else {
                // Email belongs to another tenant; create with fallback phone/hash email
                const fallbackEmail = primaryMobile
                  ? `${primaryMobile}@elitelivingre.ae`
                  : `tenant_${crypto.createHash('sha256').update(group.key).digest('hex').substring(0, 16)}@elitelivingre.ae`;
                email = fallbackEmail;
                try {
                  const newUser = await auth.createUser({
                    email: fallbackEmail,
                    password: defaultPassword,
                    displayName: group.name,
                    ...(phoneKey ? { phoneNumber: phoneKey } : {})
                  });
                  uid = newUser.uid;
                  authCreatedCount++;
                } catch (_) {
                  const nameHash = crypto.createHash('sha256').update(group.key).digest('hex').substring(0, 16);
                  uid = `tenant_${nameHash}`;
                }
              }
            } else if (phoneKey && createErr.code === 'auth/phone-number-already-exists') {
              const u = await auth.getUserByPhoneNumber(phoneKey);
              if (!protectedUids.has(u.uid) && !claimedUids.has(u.uid)) {
                uid = u.uid;
                userByPhone.set(phoneKey, u);
                userByName.set(nameKey, u);
                authExistingCount++;
              } else {
                const nameHash = crypto.createHash('sha256').update(group.key).digest('hex').substring(0, 16);
                uid = `tenant_${nameHash}`;
              }
            } else {
              const nameHash = crypto.createHash('sha256').update(group.key).digest('hex').substring(0, 16);
              uid = `tenant_${nameHash}`;
              console.warn(`⚠️ تعذر إنشاء حساب Auth لـ (${group.name}):`, createErr.message);
            }
          }
        }
      } catch (err) {
        console.warn(`⚠️ خطأ في معالجة Auth لـ (${group.name}):`, err.message);
        const nameHash = crypto.createHash('sha256').update(group.key).digest('hex').substring(0, 16);
        uid = uid || `tenant_${nameHash}`;
      }

      claimedUids.set(uid, group.key);
      activeTenantUids.add(uid);

      // 5. Save each active/renewed contract to `contracts` collection with tenantUid = uid
      for (const c of group.contracts) {
        const safeCode = (c.contractCode || `${c.unitNumber}_${c.contractNumber || 'nocode'}`)
          .toString()
          .replace(/[\/\\#\s]/g, '_');
        const contractDocId = primaryMobile ? `${primaryMobile}_${safeCode}` : `contract_${safeCode}`;
        activeContractDocIds.add(contractDocId);

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
        await commitBatchIfNeeded(false);

        // 5.5. Save cheques belonging to this contract
        const contractCheques = chequesByContractGuid.get(String(c.contractGuid || '').toLowerCase()) || [];
        for (const ch of contractCheques) {
          const safeChqNo = (ch.chequeNumber || 'nochq').toString().replace(/[\/\\#\s]/g, '_');
          const chequeDocId = `chq_${safeCode}_${safeChqNo}`;
          activeChequeDocIds.add(chequeDocId);

          const chequeRef = db.collection('cheques').doc(chequeDocId);
          const lifecycle = resolveChequeLifecycle(ch, group.name, c.customerAcGuid);

          const chequeData = {
            tenantUid: uid,
            tenantName: group.name,
            chequeNumber: ch.chequeNumber || '',
            bankName: ch.bankName || 'Bank',
            amount: ch.amount || 0,
            dueDate: toMiddayTimestamp(ch.dueDate),
            date: toMiddayTimestamp(ch.date),
            status: lifecycle.status,
            depositDate: toMiddayTimestamp(lifecycle.depositDate),
            contractCode: c.contractCode || '',
            contractNumber: c.contractNumber || null,
            buildingName: (c.buildingName || '').trim(),
            unitNumber: (c.unitNumber || '').trim(),
            notes: lifecycle.conciseNote || null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          };
          currentBatch.set(chequeRef, chequeData, { merge: true });
          currentBatchOps++;
          chequesSyncedCount++;
          await commitBatchIfNeeded(false);
        }
      }

      // Calculate tenant ledger totals across all their customerGuids
      const customerGuids = [...new Set(group.contracts.map(c => c.customerGuid ? String(c.customerGuid).toLowerCase() : null).filter(Boolean))];
      let tenantLedgerBalance = 0;
      let tenantTotalDebit = 0;
      let tenantTotalCredit = 0;
      for (const cg of customerGuids) {
        const l = ledgerByCustomerGuid.get(cg);
        if (l) {
          tenantLedgerBalance += l.ledgerBalance;
          tenantTotalDebit += l.totalDebit;
          tenantTotalCredit += l.totalCredit;
        }
      }

      // 6. Save unified tenant User document in `users/{uid}` (with deduplicated units/properties)
      const userRef = db.collection('users').doc(uid);
      const uniqueBuildings = [...new Set(properties.map(p => p.buildingName).filter(Boolean))];
      const uniqueApartments = [...new Set(properties.map(p => p.unitNumber).filter(Boolean))];
      const uniqueUnitTypes = [...new Set(properties.map(p => p.unitType).filter(Boolean))];

      // Check if user already changed their password or updated their phone in the app
      const existingFirestoreUser = firestoreDataByUid.get(uid);
      const mustChangePassword = existingFirestoreUser?.passwordChangedAt ? false : (existingFirestoreUser?.mustChangePassword ?? true);
      const existingSavedMobile = sanitizeUaeMobile(existingFirestoreUser?.phone);
      if (existingSavedMobile && !validMobiles.includes(existingSavedMobile)) {
        validMobiles.push(existingSavedMobile);
      }
      const effectivePhone = primaryMobile || existingSavedMobile || (rawPhone ? String(rawPhone).trim() : (existingFirestoreUser?.phone || ''));
      const effectiveRole = (existingFirestoreUser?.role === 'admin' || existingFirestoreUser?.role === 'technician')
        ? existingFirestoreUser.role
        : 'tenant';
      const effectiveName = (existingFirestoreUser?.profileEditedAt && existingFirestoreUser?.name && String(existingFirestoreUser.name).trim().length > 0)
        ? String(existingFirestoreUser.name).trim()
        : group.name;

      const userData = {
        name: effectiveName,
        phone: effectivePhone,
        allPhones: validMobiles,
        email: email,
        role: effectiveRole,
        mustChangePassword: mustChangePassword,
        properties: properties,
        apartmentId: uniqueApartments.join(', '),
        buildingId: uniqueBuildings.join(', '),
        contractStartDate: properties[0]?.startDate || null,
        contractEndDate: properties[0]?.endDate || null,
        contractCode: properties[0]?.contractCode || '',
        rentAmount: properties.reduce((sum, p) => sum + (p.rentAmount || 0), 0),
        yearValue: properties.reduce((sum, p) => sum + (p.yearValue || 0), 0),
        unitType: uniqueUnitTypes.join(', '),
        contractsCount: group.contracts.length,
        ledgerBalance: Math.round(tenantLedgerBalance * 100) / 100,
        totalDebit: Math.round(tenantTotalDebit * 100) / 100,
        totalCredit: Math.round(tenantTotalCredit * 100) / 100,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      currentBatch.set(userRef, userData, { merge: true });
      currentBatchOps++;
      await commitBatchIfNeeded(false);

      // 7. Register ALL tenant phone numbers into `phone_index`
      for (const m of validMobiles) {
        activePhoneIndexIds.add(m);
        const phoneIndexRef = db.collection('phone_index').doc(m);
        currentBatch.set(phoneIndexRef, { email: email, uid: uid }, { merge: true });
        currentBatchOps++;

        if (m.startsWith('9715') && m.length === 12) {
          const localPhone = '05' + m.substring(4);
          activePhoneIndexIds.add(localPhone);
          const localIndexRef = db.collection('phone_index').doc(localPhone);
          currentBatch.set(localIndexRef, { email: email, uid: uid }, { merge: true });
          currentBatchOps++;
        }
        await commitBatchIfNeeded(false);
      }

      await commitBatchIfNeeded(false);
    }

    // 8. Reconciliation & Clean-up Pass:
    // Automatically remove old/terminated/replaced contracts, cheques, and inactive tenant profiles
    // while strictly preserving all Demo data (`isDemo === true`), Admins, and Technicians.
    let staleContractsRemoved = 0;
    let staleChequesRemoved = 0;
    let staleTenantsRemoved = 0;

    if (processedCount >= 50) {
      console.log('🧹 جاري فحص وتنظيف العقود والشيكات القديمة/المنتهية أو المكررة...');

      // 8.1 Clean up stale contracts
      const existingContractsSnap = await db.collection('contracts').get();
      for (const doc of existingContractsSnap.docs) {
        const data = doc.data();
        if (data.isDemo === true) continue;
        if (!activeContractDocIds.has(doc.id)) {
          currentBatch.delete(doc.ref);
          currentBatchOps++;
          staleContractsRemoved++;
          await commitBatchIfNeeded(false);
        }
      }

      // 8.2 Clean up stale cheques
      const existingChequesSnap = await db.collection('cheques').get();
      for (const doc of existingChequesSnap.docs) {
        const data = doc.data();
        if (data.isDemo === true) continue;
        if (!activeChequeDocIds.has(doc.id)) {
          currentBatch.delete(doc.ref);
          currentBatchOps++;
          staleChequesRemoved++;
          await commitBatchIfNeeded(false);
        }
      }

      // 8.3 Clean up former/inactive tenant profiles & obsolete phone_index entries
      for (const [docId, data] of firestoreDataByUid.entries()) {
        if (protectedUids.has(docId)) continue; // Never touch admin, technician, or demo users
        if (!activeTenantUids.has(docId)) {
          currentBatch.delete(db.collection('users').doc(docId));
          currentBatchOps++;
          staleTenantsRemoved++;
          await commitBatchIfNeeded(false);
        }
      }

      const existingPhoneIndexSnap = await db.collection('phone_index').get();
      for (const doc of existingPhoneIndexSnap.docs) {
        const data = doc.data();
        if (data.uid && protectedUids.has(data.uid)) continue;
        if (!activePhoneIndexIds.has(doc.id) || (data.uid && !activeTenantUids.has(data.uid))) {
          currentBatch.delete(doc.ref);
          currentBatchOps++;
          await commitBatchIfNeeded(false);
        }
      }
    }

    // Commit any remaining operations
    await commitBatchIfNeeded(true);
    await Promise.all(batchPromises);

    console.log('========================================================');
    console.log('🎉 تمت المزامنة بنجاح تام!');
    console.log(`✔️ إجمالي العقود النشطة المرفوعة والمحدثة: ${processedCount}`);
    console.log(`💳 إجمالي الشيكات المرفوعة والمحدثة: ${chequesSyncedCount}`);
    console.log(`👤 حسابات مستأجرين جديدة تم إنشاؤها: ${authCreatedCount}`);
    console.log(`🔄 حسابات مستأجرين حالية تم تحديثها: ${authExistingCount}`);
    console.log(`🧹 عقود قديمة/منتهية تم تنظيفها: ${staleContractsRemoved}`);
    console.log(`🧹 شيكات قديمة/منتهية تم تنظيفها: ${staleChequesRemoved}`);
    console.log(`🧹 حسابات مستأجرين منتهية تم تنظيفها: ${staleTenantsRemoved}`);
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
