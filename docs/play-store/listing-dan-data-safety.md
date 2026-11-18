# Materi Play Console YALT

Panduan isian Play Console. Ganti teks dalam `[...]` sebelum dipakai.

## Detail aplikasi

- **Nama aplikasi:** YALT - Lacak Laundry
- **Package / applicationId:** `com.yalt.laundry` (tidak bisa diubah setelah diunggah)
- **Kategori:** Gaya Hidup (alternatif: Alat)
- **Deskripsi singkat (maks. 80 karakter):**
  Pantau status cucian, total tagihan, dan ambil laundry dengan QR code.
- **Deskripsi lengkap:**

  YALT membantu pelanggan dan admin laundry memantau setiap pesanan dengan mudah.

  Untuk pelanggan:
  • Lihat pesanan aktif, total tagihan dalam rupiah, dan estimasi selesai
  • Timeline status animasi: Diterima → Dicuci → Siap Diambil → Diambil
  • Struk digital untuk setiap pesanan
  • QR code pengambilan sekali pakai, ditunjukkan saat mengambil cucian
  • Riwayat pesanan dan ganti password

  Untuk admin outlet:
  • Kelola pelanggan, layanan, dan harga per kilogram
  • Buat pesanan dengan beberapa layanan dan berat
  • Perbarui status cucian, pelanggan langsung melihat perubahannya
  • Pindai QR pelanggan untuk menyelesaikan pengambilan

  Akun pelanggan dibuat oleh admin outlet laundry.

## Aset grafis

| Aset | Ukuran | Status |
| --- | --- | --- |
| Ikon aplikasi | 512 × 512 PNG 32-bit | Ekspor dari logo YALT (`assets/images/`) |
| Feature graphic | 1024 × 500 PNG/JPG | Perlu dibuat |
| Screenshot ponsel | min. 2, rasio 9:16, sisi 320–3840 px | Ambil dari login, beranda pelanggan, timeline, struk, QR, dashboard admin |

## App access (akun untuk reviewer Google)

Semua fitur ada di balik login. Pilih *All or some functionality is restricted* lalu isi:

- Admin: nomor HP `[nomor admin]`, password `[password admin]`
- Pelanggan: nomor HP `[nomor pelanggan]`, password `[password pelanggan]`
- Instruksi: "Login dengan nomor HP dan password. Akun admin dapat membuat pesanan dan memindai QR; akun pelanggan melihat status pesanan."

Gunakan akun khusus reviewer, bukan password demo yang ada di repo.

## Data safety

| Pertanyaan | Jawaban |
| --- | --- |
| Mengumpulkan / membagikan data? | Mengumpulkan: Ya. Membagikan ke pihak ketiga: Tidak |
| Data dienkripsi saat dikirim? | Ya (HTTPS) |
| Pengguna dapat meminta penghapusan data? | Ya (lewat outlet / email, lihat kebijakan privasi) |
| Informasi pribadi → Nama | Dikumpulkan, wajib, untuk *Fungsi aplikasi* dan *Pengelolaan akun* |
| Informasi pribadi → Nomor telepon | Dikumpulkan, wajib, untuk *Fungsi aplikasi* dan *Pengelolaan akun* |
| Info aplikasi → Riwayat pembelian/transaksi (pesanan laundry) | Dikumpulkan, wajib, untuk *Fungsi aplikasi* |
| Foto & video (kamera) | Tidak dikumpulkan (QR diproses di perangkat) |
| Lokasi, kontak, ID iklan, info pembayaran | Tidak dikumpulkan |

## Kuesioner lain

- **Rating konten:** kategori *Utilitas/Produktivitas*; tidak ada kekerasan, konten seksual, perjudian, atau interaksi antarpengguna → hasilnya biasanya *Semua Umur / 3+*.
- **Target audiens:** 18+ (atau 13+). Jangan pilih anak-anak.
- **Iklan:** Tidak ada iklan.
- **Aplikasi pemerintah / berita / kesehatan / keuangan:** Tidak.
- **Kebijakan privasi:** URL publik dari `kebijakan-privasi.md` (misalnya GitHub Pages atau Google Sites).

## Jalur rilis

Akun developer **pribadi** yang dibuat setelah November 2023 wajib menjalankan *closed testing* minimal 12 tester selama 14 hari berturut-turut sebelum boleh mengajukan akses Production. Unggah AAB ke *Closed testing* terlebih dahulu.
