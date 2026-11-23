# YALT — Yet Another Laundry Tracking

Aplikasi Android (Flutter + Material 3) untuk melacak pesanan laundry di satu outlet, dengan dua peran: **admin/kasir** dan **pelanggan**. Backend memakai **Supabase** (PostgreSQL, Auth, Row Level Security, Database Functions, Realtime). Pengujian API dilakukan dengan **Bruno**.

## Fitur

**Admin / kasir**
- Kasir POS: pilih/daftarkan pelanggan, isi beberapa layanan + berat per pesanan, lihat total, lalu simpan secara atomik dan tampilkan struk digital.
- Monitoring: daftar cucian aktif dan riwayat selesai, laporan ringkas (jumlah aktif, jumlah selesai, omzet), serta tombol *Mulai Cuci* dan *Siap Diambil*.
- **Scan QR pengambilan** dengan kamera (ada input manual sebagai cadangan). QR hanya bisa dipakai sekali.
- Kelola pelanggan (buat akun login, ubah, hapus) dan layanan (tarif per kg, estimasi jam, aktif/nonaktif, hapus aman).

**Pelanggan**
- Beranda: katalog layanan dan cucian yang sedang berjalan beserta estimasi selesai.
- Detail pesanan: **timeline status beranimasi** dengan waktu tiap langkah, **QR pengambilan** (aktif saat siap diambil), dan **struk digital**.
- Riwayat pesanan serta profil (jumlah pesanan, ganti password).
- Status diperbarui otomatis (Supabase Realtime), saat halaman dibuka, saat layar ditarik ke bawah, dan saat aplikasi dibuka kembali.

**Alur status**: `diterima → dicuci → siap_diambil → diambil`. Status `diambil` **hanya** bisa dicapai lewat scan QR. Semua aturan ini divalidasi di database.

## Struktur proyek

```
lib/
  config/env.dart            URL & key Supabase dari --dart-define-from-file=.env
  models/                    OrderModel, CustomerModel, ServiceModel
  repositories/              satu-satunya lapisan yang memanggil Supabase
  screens/admin/             POS, monitoring, scan QR, pelanggan, layanan
  screens/customer/          beranda, detail pesanan (timeline/QR/struk), profil
  widgets/                   badge status, struk, form pelanggan, state kosong/error
supabase/
  migrations/                semua objek SQL (tabel, RLS, fungsi, trigger, view)
  seed.sql                   layanan + akun demo
  tests/order_flow_test.sql  36 tes SQL (rollback otomatis)
bruno/                       koleksi API (48 request, 109 tes) + run-tests.mjs
docs/                        database.md, integrasi-api-supabase.md, diagram, evidence/
test/                        tes unit, widget (backend palsu), integrasi (Supabase asli)
```

## Akun demo

Login memakai **nomor HP + password**. Semua akun memakai password `ayamgoreng`.

| Peran | Nomor HP | Nama |
|---|---|---|
| Admin | 081111111111 | Admin YALT |
| Pelanggan | 081234567890 | Prabowo |
| Pelanggan | 089876543210 | Jokowi |

## 1. Konfigurasi Supabase

1. Buat proyek di [supabase.com](https://supabase.com).
2. Buka **SQL Editor**, lalu jalankan secara berurutan:
   1. `supabase/migrations/20261103000000_create_services.sql`
   2. `supabase/migrations/20261103010000_create_profiles_and_service_admin_policies.sql`
   3. `supabase/migrations/20261107000000_create_orders.sql`
   4. `supabase/migrations/20261107010000_customer_management_and_service_delete.sql`
   5. `supabase/migrations/20261107020000_security_hardening.sql`
   6. `supabase/migrations/20261118000000_require_customer_initial_password.sql`
   7. `supabase/migrations/20261118010000_block_public_signup.sql`
   8. `supabase/migrations/20261123000000_optimize_and_harden.sql`
   9. `supabase/seed.sql`
3. Verifikasi: jalankan `supabase/tests/order_flow_test.sql`. Semua 36 baris harus `LULUS`. Data tes dibatalkan otomatis.
4. Di **Authentication → Sign In / Providers**, matikan *Allow new users to sign up* (akun pelanggan dibuat oleh admin).

Penjelasan lengkap setiap objek database, termasuk backup/restore, ada di [docs/database.md](docs/database.md).

## 2. Menjalankan aplikasi

```bash
cp .env.example .env    # isi SUPABASE_URL dan SUPABASE_PUBLISHABLE_KEY (Project Settings → API Keys)
flutter pub get
flutter run --dart-define-from-file=.env
```

Jangan pernah mengisi *secret/service_role key* di `.env`. Aplikasi hanya memakai *publishable key*, dan semua hak akses dijaga oleh RLS serta fungsi database.

## 3. Pengujian

```bash
flutter analyze
flutter test test/model_test.dart test/widget_test.dart                       # tanpa internet (backend palsu)
flutter test test/order_repository_test.dart test/service_repository_test.dart --dart-define-from-file=.env --dart-define-from-file=.env.test
node bruno/run-tests.mjs                                                         # koleksi Bruno ke Supabase
```

- Tes integrasi dan Bruno butuh `.env.test` (salin dari `.env.test.example`) berisi `ADMIN_PASSWORD`. File ini terpisah dari `.env` agar password tidak ikut di-build ke aplikasi, dan tidak di-commit.
- Tes integrasi dan Bruno **membuat pesanan sungguhan** di database sebagai bukti alur demo (pesanan tidak dihapus).
- `bruno/run-tests.mjs` membaca `.env`, menjalankan `@usebruno/cli`, lalu menyimpan laporan (token login disensor) ke `docs/evidence/bruno-report.html|json`.
- Untuk membuka koleksi di aplikasi Bruno: *Open Collection → folder `bruno/`*, pilih environment **Supabase**, lalu isi secret `base_url` dan `publishable_key`.

Cakupan Bruno: login (sukses/gagal), CRUD layanan + RLS, pembuatan pesanan atomik, RLS antarpelanggan, kolom `pickup_token` yang tidak bisa dibaca, transisi status tidak valid, QR (token salah, belum siap, dipakai ulang, bukan admin), rollback transaksi, view/laporan, kelola pelanggan, dan akses tanpa login.

## 4. Build Android & kesiapan Play Store

Package aplikasi: `com.yalt.laundry`.

### Membuat upload keystore (sekali saja)

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Salin `android/key.properties.example` menjadi `android/key.properties`, lalu isi password keystore. Kedua file sudah di-*ignore* git. **Simpan cadangan keystore dan passwordnya di tempat aman**. Tanpa `key.properties`, build release memakai debug key dan ditolak Play Console (Gradle menampilkan peringatan).

### Build bundle

```bash
flutter build appbundle --release --dart-define-from-file=.env
```

Hasil: `build/app/outputs/bundle/release/app-release.aab`. Wajib memakai `--dart-define-from-file=.env`; tanpa itu aplikasi hanya menampilkan layar petunjuk konfigurasi.

### Daftar periksa

- [x] `applicationId` = `com.yalt.laundry` (bukan `com.example`).
- [x] Signing release dari `android/key.properties`, R8 minification & resource shrinking aktif, `android:allowBackup="false"`.
- [x] Tidak ada password bawaan untuk pelanggan baru: admin wajib mengisi password awal (migrasi `20261118000000_require_customer_initial_password.sql`).
- [x] Izin `INTERNET` ada di manifest utama. Izin `CAMERA` ditambahkan otomatis oleh `mobile_scanner` dengan `android.hardware.camera` `required=false`.
- [x] Orientasi portrait, nama aplikasi "Yalt", ikon launcher memakai logo YALT, sesi login otomatis diingat.
- [x] Draf kebijakan privasi: [docs/play-store/kebijakan-privasi.md](docs/play-store/kebijakan-privasi.md). Draf listing, Data safety, rating konten, dan App access: [docs/play-store/listing-dan-data-safety.md](docs/play-store/listing-dan-data-safety.md).
- [ ] Buat upload keystore dan `android/key.properties` (perintah di atas).
- [x] Terapkan migrasi `20261118000000_require_customer_initial_password.sql` (sudah diterapkan, terverifikasi: RPC tanpa `p_password` → 404).
- [x] Terapkan migrasi `20261118010000_block_public_signup.sql` (terverifikasi lewat Bruno `08 Tanpa Login/03`).
- [ ] Terapkan migrasi `20261123000000_optimize_and_harden.sql` di Supabase SQL Editor (perketat `sp_get_pickup_token`, batas panjang teks, fix `order_code` ≥ 100.000, optimasi RLS InitPlan, index, & publication Realtime tanpa `pickup_token`).
- [ ] Ganti password akun admin lewat SQL Editor: `update auth.users set encrypted_password = extensions.crypt('PASSWORD_BARU', extensions.gen_salt('bf')) where email = '081111111111@yalt.test';`, lalu isi `ADMIN_PASSWORD` di `.env.test`.
- [x] Matikan pendaftaran publik (*Allow new users to sign up* = off; `/auth/v1/signup` → 422 `signup_disabled`).
- [ ] Publikasikan kebijakan privasi ke URL publik dan isi kontak di dalamnya.
- [ ] Siapkan ikon 512 px, *feature graphic* 1024×500, dan minimal 2 screenshot.
- [ ] Buat akun khusus reviewer untuk bagian *App access*.
- [ ] Naikkan `version:` di `pubspec.yaml` setiap rilis.
- [ ] Akun developer pribadi baru: *closed testing* 12 tester selama 14 hari sebelum Production.

## 5. Alur demo

1. Login **admin** → tab *Kasir POS* → pilih *Prabowo*, tambah layanan & berat → **Buat Pesanan** → struk muncul (misalnya `ORD-000xx`).
2. Login **pelanggan** (081234567890) di perangkat lain → buka pesanan → timeline *Diterima* dan estimasi selesai.
3. Admin → *Monitoring* → **Mulai Cuci** → **Siap Diambil**. Timeline pelanggan ikut berubah (Realtime) dan QR menjadi aktif.
4. Admin → **Scan QR Pickup** → arahkan kamera ke QR pelanggan → *Pengambilan Berhasil*. Scan ulang QR yang sama ditolak: *QR Sudah Dipakai*.
5. Pesanan pindah ke *Riwayat Selesai* di sisi admin dan pelanggan.

## Keamanan sebelum rilis

- Supabase Security Advisor: 0 error. Sisa warning dijelaskan di [docs/database.md](docs/database.md#9-hardening-supabase-security-advisor).
- **Ganti password akun admin demo** (`081111111111` / `ayamgoreng` tertulis di repo) sebelum aplikasi dipakai publik. Pelanggan baru tidak lagi memakai password bawaan; admin mengisi password awal di form registrasi.
- **Matikan pendaftaran publik** (*Authentication → Sign In / Providers → Allow new users to sign up*), karena akun pelanggan dibuat oleh admin.
- Aktifkan *Leaked password protection* (*Authentication → Attack Protection*) bila paket proyek mendukung.

## Keterbatasan yang diketahui

- Akun pelanggan dibuat dengan menulis langsung ke `auth.users` dari fungsi database (pola yang sama dengan seed). Cara ini praktis tanpa Edge Function, tetapi bergantung pada struktur tabel internal Supabase Auth.
- Login nomor HP dipetakan ke email internal `<nomor>@yalt.test` (tanpa OTP SMS).
- Prosedur backup/restore sudah didokumentasikan tetapi belum diuji pada proyek terpisah.
- Scan QR lewat **kamera** belum diuji di HP sungguhan (pengujian memakai input manual karena kamera browser diblokir). QR yang ditampilkan sudah dipastikan bisa di-*decode*.
- Pesan error dari database memakai jam WIB, sedangkan aplikasi menampilkan jam sesuai zona waktu perangkat.

Bukti pengujian (screenshot alur demo ORD-00020, laporan Bruno, log tes) ada di [docs/evidence](docs/evidence/README.md).
