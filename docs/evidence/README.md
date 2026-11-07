# Bukti pengujian YALT

Semua bukti di bawah ini diambil pada **7 November 2026** terhadap proyek Supabase YALT yang sungguhan.

## Alur demo lengkap: pesanan **ORD-00020**

Dijalankan lewat aplikasi Flutter (build web, ukuran layar 375×812) yang terhubung ke Supabase.

| No | Langkah | Bukti |
|---|---|---|
| 1 | Admin membuat pesanan untuk Prabowo: Cuci Setrika 3 kg + Cuci Kilat 1,5 kg → total **Rp 42.000**, estimasi selesai +48 jam, struk digital | [01-admin-struk-pesanan-baru.jpg](ORD-00020/01-admin-struk-pesanan-baru.jpg) |
| 2 | Admin mengubah status: Mulai Cuci → Siap Diambil (RPC `sp_update_order_status`) | [02-admin-status-siap-diambil.jpg](ORD-00020/02-admin-status-siap-diambil.jpg) |
| 3 | Pelanggan membuka detail: timeline 3 langkah dengan waktu dari trigger, QR aktif | [03-pelanggan-timeline-dan-qr.jpg](ORD-00020/03-pelanggan-timeline-dan-qr.jpg) |
| 4 | Admin memproses QR (`sp_pickup_order`) → *Pengambilan Berhasil*, laporan Selesai bertambah | [04-admin-scan-qr-berhasil.jpg](ORD-00020/04-admin-scan-qr-berhasil.jpg) |
| 5 | QR yang sama dipakai lagi → ditolak *QR Sudah Dipakai* (409 `token_used`) | [05-admin-qr-dipakai-ulang-ditolak.jpg](ORD-00020/05-admin-qr-dipakai-ulang-ditolak.jpg) |
| 6 | Supabase SQL Editor: 4 baris `order_status_histories` untuk ORD-00020 | [06-supabase-riwayat-status.jpg](ORD-00020/06-supabase-riwayat-status.jpg) |

Isi tabel pada langkah 6 (waktu WIB):

| from_status | to_status | waktu |
|---|---|---|
| NULL | diterima | 07-11 14:11:52 |
| diterima | dicuci | 07-11 14:12:16 |
| dicuci | siap_diambil | 07-11 14:12:26 |
| siap_diambil | diambil | 07-11 14:22:45 (`pickup_token_used_at` 14:22) |

Catatan:
- QR di layar pelanggan sudah di-*decode* dengan OpenCV menjadi `yalt:pickup:<token>`, jadi QR-nya valid untuk scanner.
- Kamera diblokir di browser pengujian, sehingga token dimasukkan lewat **input manual** di halaman scan (layar tersebut menampilkan pesan *permissionDenied* dengan benar). Scan kamera sungguhan perlu dicoba di HP Android.
- Aplikasi menampilkan waktu sesuai zona waktu perangkat (pengujian berjalan di UTC+8, jadi 15:11 di aplikasi = 14:11 WIB). Pesan error dari database memakai WIB.

## Pengujian otomatis

| Pengujian | Hasil | Bukti |
|---|---|---|
| Tes SQL `supabase/tests/order_flow_test.sql` di Supabase | 34/34 lulus | [supabase-sql-test-34-lulus.jpg](supabase-sql-test-34-lulus.jpg) |
| Koleksi Bruno (48 request) | 48/48 request, 109/109 tes lulus (dijalankan ulang setelah hardening). Pesanan bukti **ORD-00023** (`ceb84c31-392f-4dcc-b2e0-c9773e4dd885`) | [bruno-report.html](bruno-report.html), [bruno-report.json](bruno-report.json), [bruno-run.txt](bruno-run.txt) |
| Tes integrasi Flutter → Supabase | 8/8 lulus, termasuk dua scan QR bersamaan (tepat satu berhasil). Pesanan bukti **ORD-00021** | [flutter-integration-test.txt](flutter-integration-test.txt) |
| Tes unit + widget Flutter (backend palsu) | lulus semua | [flutter-unit-widget-test.txt](flutter-unit-widget-test.txt) |

Token login di laporan Bruno sudah disensor (`[REDACTED_JWT]`).
