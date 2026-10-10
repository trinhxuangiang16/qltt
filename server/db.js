const sql = require('mssql');

const config = {
  server: process.env.DB_SERVER || 'localhost',
  port: Number(process.env.DB_PORT || 1433),
  database: process.env.DB_NAME || 'QL_CHUYENBAY',
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  connectionTimeout: 8000,
  requestTimeout: 30000,
  pool: { min: 0, max: 8, idleTimeoutMillis: 30000 },
  options: {
    encrypt: String(process.env.DB_ENCRYPT || 'false').toLowerCase() === 'true',
    trustServerCertificate: true,
    enableArithAbort: true,
  },
};

let poolPromise;

function getPool() {
  if (!config.user || !config.password) {
    throw new Error('Thiếu DB_USER hoặc DB_PASSWORD trong file .env.');
  }
  if (!poolPromise) {
    const pool = new sql.ConnectionPool(config);
    pool.on('error', (error) => console.error('SQL pool error:', error.message));
    poolPromise = pool.connect().catch((error) => {
      poolPromise = undefined;
      throw error;
    });
  }
  return poolPromise;
}

module.exports = { sql, getPool };
