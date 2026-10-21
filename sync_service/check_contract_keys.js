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

async function testContractKeys() {
  const pool = await new sql.ConnectionPool(sqlConfig).connect();
  const query = `
    SELECT 
        LTRIM(RTRIM(ContractNo))            AS contractCode,
        Number                              AS contractNumber,
        LTRIM(RTRIM(BuildingName))          AS buildingName,
        LTRIM(RTRIM(FlatNo))                AS unitNumber,
        LTRIM(RTRIM(CustName))              AS tenantName,
        LTRIM(RTRIM(CustomerMobile))        AS mobileNumber
    FROM vwLeaseApartment
    WHERE LTRIM(RTRIM(ContractState)) = 'valid'
      AND YEAR(ToDate) >= 2026;
  `;
  const res = await pool.request().query(query);
  const rows = res.recordset;

  console.log('Total rows:', rows.length);

  const codes = new Set(rows.map(r => r.contractCode));
  console.log('Unique contractCode count:', codes.size);

  const numbers = new Set(rows.map(r => r.contractNumber));
  console.log('Unique contractNumber count:', numbers.size);

  // Check sample contract codes
  console.log('Sample contract codes:', rows.slice(0, 5).map(r => ({ code: r.contractCode, num: r.contractNumber, flat: r.unitNumber })));

  await pool.close();
}

testContractKeys().catch(console.error);
