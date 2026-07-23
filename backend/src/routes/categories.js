const express = require('express');
const pool = require('../db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  const result = await pool.query('SELECT * FROM categories WHERE user_id = $1 ORDER BY name', [req.userId]);
  res.json(result.rows);
});

router.post('/', async (req, res) => {
  const { name, type } = req.body;
  if (!name || !['masuk', 'keluar'].includes(type)) {
    return res.status(400).json({ error: 'Nama dan tipe kategori (masuk/keluar) wajib diisi' });
  }
  const result = await pool.query(
    'INSERT INTO categories (user_id, name, type) VALUES ($1, $2, $3) RETURNING *',
    [req.userId, name, type]
  );
  res.status(201).json(result.rows[0]);
});

router.delete('/:id', async (req, res) => {
  await pool.query('DELETE FROM categories WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
  res.status(204).send();
});

module.exports = router;
