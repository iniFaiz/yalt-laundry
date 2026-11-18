# Kebijakan Privasi YALT (Yet Another Laundry Tracking)

Terakhir diperbarui: 18 November 2026

YALT adalah aplikasi pelacakan pesanan laundry untuk satu outlet laundry. Kebijakan ini menjelaskan data apa yang dikumpulkan aplikasi, untuk apa data dipakai, dan bagaimana pengguna dapat meminta penghapusan data.

> Ganti semua teks dalam tanda `[...]` sebelum dipublikasikan.

## 1. Pengelola

Aplikasi dikelola oleh [nama pengelola / outlet laundry]. Kontak: [email kontak].

## 2. Data yang dikumpulkan

| Data | Sumber | Tujuan |
| --- | --- | --- |
| Nama lengkap | Diisi admin outlet saat mendaftarkan pelanggan | Identitas pada pesanan dan struk |
| Nomor HP | Diisi admin outlet | Nomor login dan identitas pelanggan |
| Password | Diisi admin (password awal) lalu dapat diganti pelanggan | Autentikasi; disimpan dalam bentuk hash oleh Supabase Auth, tidak dapat dibaca siapa pun |
| Data pesanan (layanan, berat, harga, status, waktu) | Dibuat admin outlet | Menampilkan status, estimasi selesai, riwayat, dan struk digital |

Aplikasi **tidak** mengumpulkan lokasi, kontak, foto, data iklan, maupun data pembayaran.

## 3. Izin kamera

Izin kamera hanya dipakai di akun admin untuk memindai QR pengambilan pesanan. Gambar kamera diproses langsung di perangkat dan tidak disimpan maupun dikirim ke server. Hanya isi token QR yang dikirim untuk verifikasi.

## 4. Penyimpanan dan keamanan

- Data disimpan di layanan cloud Supabase (PostgreSQL) dan dikirim melalui koneksi terenkripsi (HTTPS).
- Akses data dibatasi dengan Row Level Security: pelanggan hanya dapat melihat pesanannya sendiri; pengelolaan data hanya dapat dilakukan admin.
- Data tidak dijual dan tidak dibagikan ke pihak ketiga selain penyedia infrastruktur (Supabase) yang memproses data atas nama pengelola.

## 5. Masa simpan

Data akun dan riwayat pesanan disimpan selama akun aktif, untuk keperluan riwayat transaksi outlet.

## 6. Penghapusan akun dan data

Pelanggan dapat meminta penghapusan akun dengan menghubungi outlet secara langsung atau mengirim email ke [email kontak] dengan menyertakan nomor HP yang terdaftar. Permintaan diproses paling lambat 30 hari. Akun login dan data profil akan dihapus; catatan transaksi yang wajib disimpan untuk pembukuan outlet dapat dianonimkan.

## 7. Anak-anak

Aplikasi tidak ditujukan untuk anak di bawah 13 tahun.

## 8. Perubahan kebijakan

Perubahan kebijakan akan diumumkan melalui halaman ini dengan memperbarui tanggal di atas.
