const express = require('express');
const pool = require('../db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

// Ringkasan kas masuk/keluar untuk rentang tanggal (default: bulan berjalan)
router.get('/summary', async (req, res) => {
  const { start_date, end_date } = req.query;
  const start = start_date || new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10);
  const end = end_date || new Date().toISOString().slice(0, 10);

  const result = await pool.query(
    `SELECT type, COALESCE(SUM(amount), 0) AS total
     FROM transactions
     WHERE user_id = $1 AND transaction_date BETWEEN $2 AND $3
     GROUP BY type`,
    [req.userId, start, end]
  );

  const summary = { masuk: 0, keluar: 0 };
  result.rows.forEach((row) => {
    summary[row.type] = parseFloat(row.total);
  });
  summary.saldo = summary.masuk - summary.keluar;
  summary.period = { start, end };

  res.json(summary);
});

// Grafik harian untuk periode tertentu (dipakai untuk chart di aplikasi)
router.get('/daily', async (req, res) => {
  const { start_date, end_date } = req.query;
  const start = start_date || new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().slice(0, 10);
  const end = end_date || new Date().toISOString().slice(0, 10);

  const result = await pool.query(
    `SELECT transaction_date, type, COALESCE(SUM(amount), 0) AS total
     FROM transactions
     WHERE user_id = $1 AND transaction_date BETWEEN $2 AND $3
     GROUP BY transaction_date, type
     ORDER BY transaction_date`,
    [req.userId, start, end]
  );

  res.json(result.rows);
});

module.exports = router;
