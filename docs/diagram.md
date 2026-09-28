# Diagram YALT

Sumber kebutuhan: `AGENTS.md`. Diagram mengikuti bentuk sederhana pada gambar referensi: aktor dan oval untuk use case, serta tabel dengan kolom PK/FK untuk ERD. Gambar referensi hanya dipakai sebagai contoh tampilan.

## File

- `../usecase.drawio`: dua aktor, 13 use case, dan batas sistem YALT.
- `../erd.drawio`: lima tabel inti dan lima relasi.
- `diagram-preview/usecase.drawio.png` dan `diagram-preview/erd.drawio.png`: pratinjau hasil render draw.io; XML diagram disertakan di dalam PNG.

## Ruang lingkup dan asumsi

- Satu outlet; Admin dan Pelanggan memakai aplikasi yang sama.
- Login dan logout tersedia untuk kedua peran. Akun pelanggan dikelola admin; registrasi mandiri tidak termasuk MVP.
- Pelanggan hanya melihat pesanannya sendiri. Admin membuat pesanan, mengelola layanan/harga, memperbarui status proses, dan memindai QR pengambilan.
- `users.role` bernilai `admin` atau `customer`. `orders.customer_id` merujuk pengguna dengan peran `customer`; `order_status_histories.changed_by` merujuk admin pelaksana perubahan. Pemeriksaan peran dilakukan di API.
- Lima tabel merupakan rancangan domain. Tabel internal Supabase (`auth.users`) dan kolom audit tambahan tidak ditampilkan agar ERD ringkas. Backend belum tersedia dalam proyek saat diagram dibuat; dokumen ini bukan bukti implementasi atau pengujian database.

## Relasi

| Kunci utama | Kunci asing | Makna |
| --- | --- | --- |
| `users.user_id` | `orders.customer_id` | Satu pelanggan dapat memiliki banyak pesanan. |
| `orders.order_id` | `order_items.order_id` | Satu pesanan memiliki satu atau lebih item. |
| `services.service_id` | `order_items.service_id` | Satu layanan dapat digunakan pada banyak item pesanan. |
| `orders.order_id` | `order_status_histories.order_id` | Satu pesanan memiliki riwayat status sejak diterima. |
| `users.user_id` | `order_status_histories.changed_by` | Satu admin dapat mencatat banyak perubahan status. |

`PK` berarti kunci utama, `FK` kunci asing, dan `UK` nilai unik. Simbol lingkaran pada sisi banyak berarti boleh belum ada data anak. `order_items` menjadi tabel penghubung pesanan dan layanan.

## Ketentuan untuk implementasi

- ID memakai `BIGINT` atau `UUID`; tipe FK sama dengan PK yang dirujuk. Seluruh tabel dikelola dalam PostgreSQL Supabase.
- `weight_kg` memakai `DECIMAL(8,2)` dan harus lebih besar dari nol. Harga, `subtotal`, dan `total_price` memakai `DECIMAL(14,2)` dengan nilai tidak negatif. `estimated_hours` harus positif; `is_active` berupa boolean.
- `users.email`, `orders.order_code`, dan `orders.pickup_qr_token` memiliki indeks unik. Password disimpan sebagai hash. Kolom waktu memakai `DATETIME`; `pickup_qr_used_at` dapat bernilai `NULL` sebelum token dipakai.
- Indeks yang disarankan: `orders(customer_id, created_at)`, `orders(status, estimated_completion_at)`, `order_items(order_id)`, `order_items(service_id)`, `order_status_histories(order_id, changed_at)`, dan `order_status_histories(changed_by)`.
- Harga pada `order_items.price_per_kg_snapshot` disalin dari layanan ketika pesanan dibuat. Subtotal dihitung melalui `fn_item_total(weight_kg, price_per_kg_snapshot)`; total pesanan adalah jumlah subtotal. Supabase menyimpan pesanan dan seluruh item dalam satu operasi atomik / RPC transaction.
- Layanan yang pernah digunakan dinonaktifkan melalui `is_active`. Penghapusan layanan, pengguna, atau pesanan yang akan merusak riwayat dicegah dengan kebijakan referensial `RESTRICT`; penghapusan fisik layanan hanya untuk yang belum digunakan.
- `orders.status` dan `order_status_histories.status` dibatasi pada `diterima`, `dicuci`, `siap_diambil`, dan `diambil`. API menggunakan `sp_update_order_status`; trigger mencatat perubahan beserta admin pelaksana dan waktunya, termasuk status awal saat pesanan dibuat.
- Token QR bersifat acak, unik, dan sekali pakai. Dari `siap_diambil`, API mengunci baris pesanan, memvalidasi token, menandai waktu penggunaan, dan mengubah status menjadi `diambil` dalam satu transaksi. Pembaruan status biasa tidak dapat langsung memilih `diambil`.

## Verifikasi diagram

Verifikasi meliputi validitas XML, keunikan ID bentuk, keberadaan semua ujung relasi, kesesuaian aktor dan tabel dengan `AGENTS.md`, serta pemeriksaan visual PNG yang dirender langsung oleh draw.io Desktop. Hasil pemeriksaan dicatat dalam `diagram-preview/verifikasi.txt`.

## Hasil tinjauan dan revisi — 10 September 2026

- Sesuai arahan terbaru pengguna, alur final adalah `diterima → dicuci → siap_diambil → diambil`. `AGENTS.md`, kedua diagram, dan pratinjau mengikuti alur ini. Status tidak boleh dilompati atau dimundurkan; `diambil` hanya melalui pengambilan QR.
- Bentuk tabel, PK/FK/UK, lima relasi ERD, aktor di luar batas sistem, oval use case, dan asosiasi tanpa panah sudah sesuai. ERD ini memakai Crow's Foot, sehingga tidak memerlukan belah ketupat relasi dan oval atribut seperti notasi Chen.
- Sisi induk ERD diperjelas menjadi dua garis (tepat satu). Sisi anak pelanggan–pesanan, layanan–item, dan admin–riwayat adalah `0..N`; pesanan–item dan pesanan–riwayat adalah `1..N`. Seluruh FK wajib terisi. Relasi admin–riwayat diberi titik keluar tersendiri agar tidak tampak sebagai percabangan relasi pelanggan–pesanan.
- Relasi `1..N` menggambarkan pesanan yang berhasil disimpan. FK saja tidak menjamin induk mempunyai anak: API harus menolak item kosong, menyimpan pesanan beserta item dan riwayat awal dalam satu transaksi, serta membatalkan transaksi bila salah satu langkah gagal.
- Use case membuat pesanan dan melihat semua pesanan dipisahkan karena merupakan dua tujuan yang dapat dijalankan sendiri. Kini ada 2 aktor, 13 use case, dan 15 asosiasi.
- Login menjadi prasyarat fitur yang dilindungi. Tidak ditambahkan `«include»` ke Login karena pengguna tidak perlu menjalankan login ulang setiap membuka fitur. `«include»` dan `«extend»` tidak wajib ada; diagram ini cukup memakai asosiasi dan catatan prasyarat. Garis asosiasi tidak menyatakan urutan proses.
- Pembaruan status oleh admin hanya sampai `siap_diambil`. Use case pengambilan melalui QR terpisah, dengan syarat token valid dan belum dipakai. QR ditampilkan kepada pemilik pesanan saat `siap_diambil`; pemeriksaan akhir tetap dilakukan API dalam transaksi dengan penguncian baris.
- Token acak unik diasumsikan dibuat ketika pesanan dibuat; kolom token wajib terisi, sedangkan `pickup_qr_used_at` boleh `NULL` sampai pengambilan. Peran `customer_id` dan `changed_by` harus diperiksa backend karena FK hanya memastikan pengguna ada, bukan memastikan perannya.
- Trigger pencatatan status perlu mencakup INSERT untuk status awal dan UPDATE untuk perubahan berikutnya. API/prosedur menyediakan identitas admin pelaksana agar `changed_by` selalu terisi. Rincian mekanisme ini belum diimplementasikan.
- Penggunaan nama PK khusus (`user_id`, `order_id`, dan seterusnya) tetap dipertahankan saat integrasi dengan Supabase dan model Flutter.
- PNG lama tidak lagi identik dengan sumber `.drawio` saat tinjauan dimulai. Keduanya diekspor ulang; catatan verifikasi lama diganti dengan hasil untuk berkas terbaru.

Acuan simbol: [Crow's Foot draw.io](https://www.drawio.com/docs/tutorials/crows-foot-notation/) dan [bentuk UML use case draw.io](https://www.drawio.com/docs/diagram-types/uml/use-case-diagrams/). Aturan bisnis mengikuti kebutuhan YALT dan arahan pengguna.
