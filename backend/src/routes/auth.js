const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const pool = require('../db');
const { isValidPhoneNumber, isValidPassword } = require('../utils/validators');

const router = express.Router();

// Catatan MVP: pakai nomor HP + password dulu untuk kesederhanaan.
// Fase berikutnya: ganti/lengkapi dengan OTP SMS (Twilio/Vonage) untuk UX yang lebih familiar bagi UMKM.

router.post('/register', async (req, res) => {
  const { phone_number, password, business_name } = req.body;

  if (!phone_number || !password || !business_name || !business_name.trim()) {
    return res.status(400).json({ error: 'Nomor HP, password, dan nama usaha wajib diisi' });
  }
  if (!isValidPhoneNumber(phone_number)) {
    return res.status(400).json({ error: 'Format nomor HP tidak valid. Contoh: 081234567890' });
  }
  if (!isValidPassword(password)) {
    return res.status(400).json({ error: 'Password minimal 6 karakter' });
  }

  try {
    const existing = await pool.query('SELECT id FROM users WHERE phone_number = $1', [phone_number]);
    if (existing.rows.length > 0) {
      return res.status(409).json({ error: 'Nomor HP sudah terdaftar' });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const result = await pool.query(
      'INSERT INTO users (phone_number, password_hash, business_name) VALUES ($1, $2, $3) RETURNING id, phone_number, business_name',
      [phone_number, passwordHash, business_name || null]
    );

    const user = result.rows[0];
    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '30d' });

    res.status(201).json({ user, token });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Gagal mendaftarkan akun' });
  }
});

router.post('/login', async (req, res) => {
  const { phone_number, password } = req.body;
  if (!phone_number || !password) {
    return res.status(400).json({ error: 'Nomor HP dan password wajib diisi' });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE phone_number = $1', [phone_number]);
    if (result.rows.length === 0) {
      return res.status(401).json({ error: 'Nomor HP atau password salah' });
    }

    const user = result.rows[0];
    const valid = await bcrypt.compare(password, user.password_hash);
    if (!valid) {
      return res.status(401).json({ error: 'Nomor HP atau password salah' });
    }

    const token = jwt.sign({ userId: user.id }, process.env.JWT_SECRET, { expiresIn: '30d' });
    res.json({
      user: { id: user.id, phone_number: user.phone_number, business_name: user.business_name },
      token,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Gagal login' });
  }
});

// Reset password sederhana untuk tahap MVP/testing terbatas.
// PENTING: metode ini TIDAK aman untuk rilis publik — nama usaha bukan
// verifikasi identitas yang kuat. Wajib diganti ke OTP SMS/WhatsApp
// sebelum aplikasi dipakai oleh publik luas.
router.post('/reset-password', async (req, res) => {
  const { phone_number, business_name, new_password } = req.body;

  if (!phone_number || !business_name || !new_password) {
    return res.status(400).json({ error: 'Nomor HP, nama usaha, dan password baru wajib diisi' });
  }
  if (!isValidPassword(new_password)) {
    return res.status(400).json({ error: 'Password baru minimal 6 karakter' });
  }

  try {
    const result = await pool.query('SELECT * FROM users WHERE phone_number = $1', [phone_number]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Nomor HP tidak terdaftar' });
    }

    const user = result.rows[0];
    const storedName = (user.business_name || '').trim().toLowerCase();
    const inputName = business_name.trim().toLowerCase();

    if (storedName === '' || storedName !== inputName) {
      return res.status(401).json({ error: 'Nama usaha tidak cocok dengan data terdaftar' });
    }

    const passwordHash = await bcrypt.hash(new_password, 10);
    await pool.query('UPDATE users SET password_hash = $1 WHERE id = $2', [passwordHash, user.id]);

    res.json({ message: 'Password berhasil direset, silakan login dengan password baru' });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Gagal mereset password' });
  }
});

module.exports = router;
