const express = require('express');
const pool = require('../db');
const authMiddleware = require('../middleware/auth');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  const result = await pool.query('SELECT * FROM products WHERE user_id = $1 ORDER BY name', [req.userId]);
  res.json(result.rows);
});

router.post('/', async (req, res) => {
  const { name, stock, buy_price, sell_price } = req.body;
  if (!name) return res.status(400).json({ error: 'Nama produk wajib diisi' });

  const result = await pool.query(
    `INSERT INTO products (user_id, name, stock, buy_price, sell_price)
     VALUES ($1, $2, $3, $4, $5) RETURNING *`,
    [req.userId, name, stock || 0, buy_price || 0, sell_price || 0]
  );
  res.status(201).json(result.rows[0]);
});

router.put('/:id', async (req, res) => {
  const { name, stock, buy_price, sell_price } = req.body;
  const result = await pool.query(
    `UPDATE products SET name = COALESCE($1, name), stock = COALESCE($2, stock),
     buy_price = COALESCE($3, buy_price), sell_price = COALESCE($4, sell_price), updated_at = NOW()
     WHERE id = $5 AND user_id = $6 RETURNING *`,
    [name, stock, buy_price, sell_price, req.params.id, req.userId]
  );
  if (result.rows.length === 0) return res.status(404).json({ error: 'Produk tidak ditemukan' });
  res.json(result.rows[0]);
});

router.delete('/:id', async (req, res) => {
  await pool.query('DELETE FROM products WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);
  res.status(204).send();
});

module.exports = router;
