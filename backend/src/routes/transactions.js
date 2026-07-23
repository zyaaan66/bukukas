const express = require('express');
const pool = require('../db');
const authMiddleware = require('../middleware/auth');
const { isPositiveNumber } = require('../utils/validators');

const router = express.Router();
router.use(authMiddleware);

router.get('/', async (req, res) => {
  const { start_date, end_date } = req.query;
  let query = `
    SELECT t.*, c.name AS category_name, p.name AS product_name
    FROM transactions t
    LEFT JOIN categories c ON t.category_id = c.id
    LEFT JOIN products p ON t.product_id = p.id
    WHERE t.user_id = $1`;
  const params = [req.userId];

  if (start_date && end_date) {
    query += ' AND t.transaction_date BETWEEN $2 AND $3';
    params.push(start_date, end_date);
  }
  query += ' ORDER BY t.transaction_date DESC, t.created_at DESC';

  const result = await pool.query(query, params);
  res.json(result.rows);
});

// 'masuk' = penjualan barang -> stok berkurang
// 'keluar' = pembelian/restock barang -> stok bertambah
function stockDelta(type, quantity) {
  return type === 'masuk' ? -quantity : quantity;
}

// Pastikan kategori yang dipilih benar-benar milik user dan tipenya
// (masuk/keluar) cocok dengan tipe transaksi — mencegah data tercampur
// kalau ada bug di frontend atau panggilan API langsung dari luar UI.
async function validateCategoryType(userId, categoryId, type) {
  if (!categoryId) return null;
  const result = await pool.query('SELECT type FROM categories WHERE id = $1 AND user_id = $2', [categoryId, userId]);
  if (result.rows.length === 0) return 'Kategori tidak ditemukan';
  if (result.rows[0].type !== type) {
    return `Kategori ini untuk tipe "${result.rows[0].type}", tidak cocok dengan tipe transaksi "${type}"`;
  }
  return null;
}

router.post('/', async (req, res) => {
  const { category_id, product_id, type, amount, quantity, note, transaction_date } = req.body;

  if (!type || !['masuk', 'keluar'].includes(type)) {
    return res.status(400).json({ error: 'Tipe transaksi (masuk/keluar) wajib diisi' });
  }
  if (!isPositiveNumber(amount)) {
    return res.status(400).json({ error: 'Jumlah (Rp) harus berupa angka lebih dari 0' });
  }
  if (product_id && (!quantity || !isPositiveNumber(quantity))) {
    return res.status(400).json({ error: 'Jumlah barang wajib diisi kalau memilih produk' });
  }

  const categoryError = await validateCategoryType(req.userId, category_id, type);
  if (categoryError) {
    return res.status(400).json({ error: categoryError });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    if (product_id && quantity) {
      // Lock baris produk supaya aman dari transaksi lain yang jalan bersamaan
      const productResult = await client.query(
        'SELECT stock FROM products WHERE id = $1 AND user_id = $2 FOR UPDATE',
        [product_id, req.userId]
      );
      if (productResult.rows.length === 0) {
        await client.query('ROLLBACK');
        return res.status(404).json({ error: 'Produk tidak ditemukan' });
      }

      const currentStock = productResult.rows[0].stock;
      const delta = stockDelta(type, quantity);
      if (currentStock + delta < 0) {
        await client.query('ROLLBACK');
        return res.status(400).json({
          error: `Stok tidak mencukupi. Stok saat ini: ${currentStock}, dibutuhkan: ${quantity}`,
        });
      }

      await client.query(
        'UPDATE products SET stock = stock + $1, updated_at = NOW() WHERE id = $2 AND user_id = $3',
        [delta, product_id, req.userId]
      );
    }

    const result = await client.query(
      `INSERT INTO transactions (user_id, category_id, product_id, type, amount, quantity, note, transaction_date)
       VALUES ($1, $2, $3, $4, $5, $6, $7, COALESCE($8, CURRENT_DATE)) RETURNING *`,
      [req.userId, category_id || null, product_id || null, type, amount, quantity || null, note || null, transaction_date || null]
    );

    await client.query('COMMIT');
    res.status(201).json(result.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Gagal menyimpan transaksi' });
  } finally {
    client.release();
  }
});

router.put('/:id', async (req, res) => {
  const { category_id, product_id, type, amount, quantity, note, transaction_date } = req.body;

  if (!type || !['masuk', 'keluar'].includes(type)) {
    return res.status(400).json({ error: 'Tipe transaksi (masuk/keluar) wajib diisi' });
  }
  if (!isPositiveNumber(amount)) {
    return res.status(400).json({ error: 'Jumlah (Rp) harus berupa angka lebih dari 0' });
  }
  if (product_id && (!quantity || !isPositiveNumber(quantity))) {
    return res.status(400).json({ error: 'Jumlah barang wajib diisi kalau memilih produk' });
  }

  const categoryError = await validateCategoryType(req.userId, category_id, type);
  if (categoryError) {
    return res.status(400).json({ error: categoryError });
  }

  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const existingResult = await client.query(
      'SELECT * FROM transactions WHERE id = $1 AND user_id = $2 FOR UPDATE',
      [req.params.id, req.userId]
    );
    if (existingResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Transaksi tidak ditemukan' });
    }
    const old = existingResult.rows[0];

    // Kumpulkan produk yang perlu disesuaikan stoknya: produk lama (dibalikkan) dan produk baru (diterapkan)
    const affectedProductIds = new Set([old.product_id, product_id].filter(Boolean));

    for (const pid of affectedProductIds) {
      const productResult = await client.query(
        'SELECT stock FROM products WHERE id = $1 AND user_id = $2 FOR UPDATE',
        [pid, req.userId]
      );
      if (productResult.rows.length === 0) continue;

      let stock = productResult.rows[0].stock;

      // Balikkan efek transaksi lama kalau produk ini terkait transaksi lama
      if (old.product_id === pid && old.quantity) {
        stock -= stockDelta(old.type, old.quantity);
      }
      // Terapkan efek transaksi baru kalau produk ini terkait transaksi baru
      if (product_id === pid && quantity) {
        const delta = stockDelta(type, quantity);
        if (stock + delta < 0) {
          await client.query('ROLLBACK');
          return res.status(400).json({
            error: `Stok tidak mencukupi untuk perubahan ini. Stok tersedia: ${stock}, dibutuhkan: ${quantity}`,
          });
        }
        stock += delta;
      }

      await client.query(
        'UPDATE products SET stock = $1, updated_at = NOW() WHERE id = $2 AND user_id = $3',
        [stock, pid, req.userId]
      );
    }

    const result = await client.query(
      `UPDATE transactions SET category_id = $1, product_id = $2, type = $3, amount = $4,
       quantity = $5, note = $6, transaction_date = COALESCE($7, transaction_date)
       WHERE id = $8 AND user_id = $9 RETURNING *`,
      [category_id || null, product_id || null, type, amount, quantity || null, note || null, transaction_date || null, req.params.id, req.userId]
    );

    await client.query('COMMIT');
    res.json(result.rows[0]);
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Gagal memperbarui transaksi' });
  } finally {
    client.release();
  }
});

router.delete('/:id', async (req, res) => {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');

    const existingResult = await client.query(
      'SELECT * FROM transactions WHERE id = $1 AND user_id = $2 FOR UPDATE',
      [req.params.id, req.userId]
    );
    if (existingResult.rows.length === 0) {
      await client.query('ROLLBACK');
      return res.status(404).json({ error: 'Transaksi tidak ditemukan' });
    }
    const t = existingResult.rows[0];

    // Balikkan efek stok kalau transaksi ini terkait produk
    if (t.product_id && t.quantity) {
      await client.query(
        'UPDATE products SET stock = stock - $1, updated_at = NOW() WHERE id = $2 AND user_id = $3',
        [stockDelta(t.type, t.quantity), t.product_id, req.userId]
      );
    }

    await client.query('DELETE FROM transactions WHERE id = $1 AND user_id = $2', [req.params.id, req.userId]);

    await client.query('COMMIT');
    res.status(204).send();
  } catch (err) {
    await client.query('ROLLBACK');
    console.error(err);
    res.status(500).json({ error: 'Gagal menghapus transaksi' });
  } finally {
    client.release();
  }
});

module.exports = router;
