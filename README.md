# BukuKas Pintar

Aplikasi manajemen keuangan sederhana untuk UMKM — MVP tahap 1.

## Struktur proyek

```
bukukas-pintar/
├── backend/     # REST API (Node.js + Express + PostgreSQL)
└── mobile/      # Aplikasi mobile (Flutter)
```

## Menjalankan backend

1. Install PostgreSQL (lokal, atau pakai Supabase/Railway untuk langsung dapat DB terkelola)
2. Buat database, lalu jalankan skema:
   ```
   psql -d nama_database -f backend/schema.sql
   ```
3. Masuk ke folder backend:
   ```
   cd backend
   cp .env.example .env      # isi DATABASE_URL dan JWT_SECRET
   npm install
   npm run dev
   ```
4. Cek API berjalan: `GET http://localhost:3000/health`

## Menjalankan mobile app

1. Pastikan Flutter SDK sudah terpasang (`flutter --version`)
2. Masuk ke folder mobile:
   ```
   cd mobile
   flutter pub get
   ```
3. Sesuaikan `baseUrl` di `lib/services/api_service.dart` dengan alamat backend
   (kalau testing di emulator Android, `localhost` diganti `10.0.2.2`)
4. Jalankan:
   ```
   flutter run
   ```

## Status fitur MVP

| Fitur | Status |
|---|---|
| Autentikasi (nomor HP + password) | ✅ Selesai |
| Registrasi akun (UI), nama usaha wajib diisi | ✅ Selesai |
| Lupa/reset password | ✅ Selesai (metode sementara, lihat catatan di bawah) |
| Toggle lihat/sembunyikan password | ✅ Selesai (login, daftar, reset password) |
| Catat transaksi kas masuk/keluar | ✅ Selesai |
| Edit & hapus transaksi (dengan penyesuaian stok otomatis) | ✅ Selesai |
| Konfirmasi sebelum hapus (transaksi, produk, kategori) | ✅ Selesai |
| Halaman "Semua transaksi" + pencarian & filter | ✅ Selesai |
| Ringkasan kas (dashboard) | ✅ Selesai |
| Manajemen kategori | ✅ Selesai |
| Manajemen stok produk | ✅ Selesai |
| Validasi stok tidak boleh minus | ✅ Selesai |
| Validasi kategori cocok dengan tipe transaksi | ✅ Selesai (frontend + backend) |
| Peringatan saat harga produk belum diisi | ✅ Selesai |
| Validasi input backend (nomor HP, password, jumlah) | ✅ Selesai |
| Dropdown kategori & produk di form transaksi + auto-hitung jumlah | ✅ Selesai |
| Laporan grafik harian | ✅ Selesai |
| Invoice & share ke WhatsApp | ✅ Selesai (locale Indonesia sudah diinisialisasi) |
| Penanganan error koneksi + tombol coba lagi | ✅ Selesai |
| Auto-logout & redirect ke login saat sesi habis | ✅ Selesai |
| Deploy backend ke hosting | ⬜ Belum — butuh kamu setup akun Railway/Render (lihat bagian "Deploy" di bawah) |
| OTP SMS (ganti reset password sederhana) | ⬜ Belum — masih pakai verifikasi nama usaha |

## ⚠️ Catatan keamanan: reset password sementara

Metode reset password saat ini memverifikasi lewat **nomor HP + nama usaha** — bukan OTP. Ini cukup untuk tahap testing terbatas ke orang-orang yang kamu kenal, **tapi tidak aman untuk rilis publik** karena nama usaha bukan rahasia yang kuat. Wajib diganti ke OTP SMS/WhatsApp sebelum dipakai orang banyak.

Juga: kalau user tidak mengisi nama usaha saat daftar, mereka tidak akan bisa pakai fitur reset password ini. Pertimbangkan membuat field nama usaha wajib diisi, bukan opsional.

## Deploy backend (langkah yang perlu kamu lakukan sendiri)

1. Buat akun di [railway.app](https://railway.app) (ada free tier)
2. Push folder `backend/` ke repository GitHub
3. Di Railway: New Project → Deploy from GitHub → pilih repo
4. Tambahkan PostgreSQL dari marketplace Railway, lalu jalankan `schema.sql` ke database tersebut
5. Set environment variables di Railway: `DATABASE_URL` (otomatis terisi dari PostgreSQL Railway), `JWT_SECRET` (buat string acak sendiri)
6. Setelah deploy, salin URL publik yang diberikan Railway, lalu ganti `baseUrl` di `mobile/lib/services/api_service.dart`

## Langkah selanjutnya (disarankan urutannya)

1. Deploy backend ke Railway (lihat panduan di atas)
2. Testing dengan 5-10 pengguna UMKM asli
3. Kumpulkan feedback, lalu pertimbangkan: OTP SMS, onboarding singkat untuk user baru, export laporan ke PDF/Excel
4. Multi-user/karyawan dengan hak akses (fase 2, sesuai roadmap awal)

## Catatan keamanan sebelum go-live

- `JWT_SECRET` di `.env` wajib diganti dengan string acak yang kuat, jangan pernah commit `.env` ke git
- Tambahkan rate limiting di endpoint login untuk mencegah brute force
- Aktifkan HTTPS di hosting produksi (Railway/Render sudah otomatis menyediakan ini)
