const sql = require('mssql/msnodesqlv8');

const sqlConfig = {
  connectionString: 'Driver={SQL Server Native Client 10.0};Server=ABDULLAH-LAP\\SQLEXPRESS;Database=AlAqaree7;Trusted_Connection=yes;',
  server: 'ABDULLAH-LAP\\SQLEXPRESS',
  database: 'AlAqaree7',
  driver: 'msnodesqlv8',
  options: {
    trustedConnection: true,
    trustServerCertificate: true,
    useUTC: false
  }
};

function sanitizeUaeMobile(rawMobile) {
  if (!rawMobile) return null;
  let primary = rawMobile.toString().split(/[\/,\s]+/)[0].trim();
  let digits = primary.replace(/\D/g, '');
  if (!digits) return null;
  if (digits.startsWith('009715') && digits.length === 14) {
    digits = digits.substring(2);
  } else if (digits.startsWith('05') && digits.length === 10) {
    digits = '971' + digits.substring(1);
  } else if (digits.startsWith('5') && digits.length === 9) {
    digits = '971' + digits;
  }
  if (digits.length === 12 && digits.startsWith('9715')) {
    return digits;
  }
  return null;
}

async function check() {
  let pool;
  try {
    pool = await new sql.ConnectionPool(sqlConfig).connect();
    const query = `
      SELECT 
          LTRIM(RTRIM(ContractNo))            AS contractCode,
          Number                              AS contractNumber,
          LTRIM(RTRIM(BuildingName))          AS buildingName,
          LTRIM(RTRIM(FlatNo))                AS unitNumber,
          LTRIM(RTRIM(CustName))              AS tenantName,
          LTRIM(RTRIM(CustomerMobile))        AS mobileNumber,
          FromDate                            AS startDate,
          ToDate                              AS endDate
      FROM vwLeaseApartment
      WHERE LTRIM(RTRIM(ContractState)) = 'valid'
        AND YEAR(ToDate) >= 2026;
    `;
    const res = await pool.request().query(query);
    const rows = res.recordset;

    const validPhones = new Set();
    const phoneToContracts = {};
    const skipped = [];

    for (const r of rows) {
      const sanitized = sanitizeUaeMobile(r.mobileNumber);
      if (sanitized) {
        validPhones.add(sanitized);
        if (!phoneToContracts[sanitized]) phoneToContracts[sanitized] = [];
        phoneToContracts[sanitized].push(r);
      } else {
        skipped.push(r);
      }
    }

    console.log('--- STATS ---');
    console.log('Total valid contract rows in SQL:', rows.length);
    console.log('Unique valid phone numbers (Tenants count):', validPhones.size);
    
    // Check multiple contracts per tenant
    const multiContractTenants = Object.entries(phoneToContracts).filter(([p, list]) => list.length > 1);
    console.log('Tenants with multiple apartments/contracts:', multiContractTenants.length);
    let totalMultiContracts = 0;
    multiContractTenants.forEach(([p, list]) => {
      totalMultiContracts += list.length;
    });
    console.log('Total contracts belonging to multi-contract tenants:', totalMultiContracts);
    console.log('Example multi-contract tenant:', multiContractTenants[0]?.[1][0]?.tenantName, 'has', multiContractTenants[0]?.[1].length, 'contracts');

    console.log('\n--- 14 SKIPPED RECORDS (Why were they skipped?) ---');
    skipped.forEach(s => {
      console.log(`Cust: ${s.tenantName} | Flat: ${s.unitNumber} | Raw Phone: "${s.mobileNumber}"`);
    });

  } catch (err) {
    console.error(err);
  } finally {
    if (pool) await pool.close();
  }
}

check();
