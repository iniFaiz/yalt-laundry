import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/main.dart';

// login dengan mengisi nomor hp & password lalu tekan tombol login
Future<void> _login(WidgetTester tester, String phone, String password) async {
  await tester.enterText(find.byType(TextField).at(0), phone);
  await tester.enterText(find.byType(TextField).at(1), password);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
  await tester.pumpAndSettle();
}

void main() {
  // ukuran layar seperti hp (360 x 800)
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 3.0;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset();
  });

  testWidgets('Halaman login tampil dan toggle password berfungsi', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Yalt'), findsOneWidget);
    expect(find.text('Nomor HP (Contoh: 081234567890)'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);

    // ikon mata untuk tampilkan / sembunyikan password
    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility_off_outlined));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
  });

  testWidgets('Login gagal menampilkan pesan error', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await _login(tester, '081234567890', 'salah');

    expect(find.text('Nomor HP atau password salah'), findsOneWidget);
  });

  testWidgets('Login admin masuk ke panel admin', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await _login(tester, '081111111111', 'ayamgoreng');

    expect(find.text('Panel Kasir / Admin'), findsOneWidget);

    // semua tab admin bisa dibuka tanpa error tampilan
    await tester.tap(find.text('Monitoring'));
    await tester.pumpAndSettle();
    expect(find.text('Monitoring & Laporan'), findsOneWidget);

    await tester.tap(find.text('Layanan'));
    await tester.pumpAndSettle();
    expect(find.text('Master Layanan & Tarif'), findsOneWidget);
  });

  testWidgets('Login pelanggan, buka detail pesanan (push) lalu kembali (pop)', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await _login(tester, '081234567890', 'ayamgoreng');
    expect(find.text('Halo, Prabowo 👋'), findsOneWidget);

    // push ke halaman detail pesanan
    await tester.tap(find.text('ORD-001'));
    await tester.pumpAndSettle();
    expect(find.text('Detail ORD-001'), findsOneWidget);
    expect(find.text('Rp 24.000'), findsOneWidget);

    // pop kembali ke beranda pelanggan
    await tester.tap(find.byTooltip('Kembali'));
    await tester.pumpAndSettle();
    expect(find.text('Halo, Prabowo 👋'), findsOneWidget);
  });

  testWidgets('Admin menambah pelanggan baru di tab Pelanggan', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await _login(tester, '081111111111', 'ayamgoreng');

    // buka tab data pelanggan
    await tester.tap(find.text('Pelanggan'));
    await tester.pumpAndSettle();
    expect(find.text('Data Pelanggan'), findsOneWidget);
    expect(find.text('Prabowo'), findsOneWidget);

    // nomor hp salah format memunculkan pesan validasi
    await tester.tap(find.text('Tambah Pelanggan'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Gibran');
    await tester.enterText(find.byType(TextFormField).at(1), '123');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nomor HP harus diawali 08 dan berisi 10-13 angka'), findsOneWidget);

    // nomor hp benar, pelanggan tersimpan dan tampil di daftar
    await tester.enterText(find.byType(TextFormField).at(1), '085700000001');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Gibran'), findsOneWidget);
    expect(find.text('085700000001 • 0 pesanan'), findsOneWidget);
  });

  testWidgets('Kasir POS registrasi pelanggan baru lalu langsung buat pesanan', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await _login(tester, '081111111111', 'ayamgoreng');

    // buka dialog registrasi dari tab Kasir POS (dialog yang sama dengan tab Pelanggan)
    await tester.tap(find.byTooltip('Registrasi Pelanggan Baru'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Kaesang');

    // nomor hp yang sudah dipakai pelanggan lain ditolak
    await tester.enterText(find.byType(TextFormField).at(1), '081234567890');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Nomor HP sudah terdaftar'), findsOneWidget);

    // nomor hp baru tersimpan dan pelanggan langsung terpilih di dropdown
    await tester.enterText(find.byType(TextFormField).at(1), '085700000002');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Kaesang (085700000002)'), findsOneWidget);

    // pilih layanan dan isi berat
    await tester.tap(find.text('Pilih Layanan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuci Kering (Rp 6.000 / kg)').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Contoh: 3.5'), '2');
    await tester.pumpAndSettle();
    // total dicek di kotak Total Tagihan saja (pesanan lama ORD-002 juga Rp 12.000)
    final totalRow = find.ancestor(of: find.text('Total Tagihan:'), matching: find.byType(Row));
    expect(find.descendant(of: totalRow, matching: find.text('Rp 12.000')), findsOneWidget);

    // simpan pesanan, form kembali kosong
    final submitButton = find.text('Buat Pesanan & Cetak Bukti');
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();
    expect(find.text('Pesanan untuk "Kaesang" berhasil dibuat!'), findsOneWidget);
    expect(find.text('-- Pilih Pelanggan --'), findsOneWidget);
    expect(find.text('Pilih Layanan'), findsOneWidget);
  });

  testWidgets('Pelanggan ganti password di tab Profil lalu login dengan password baru', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await _login(tester, '089876543210', 'ayamgoreng');

    // buka tab profil
    await tester.tap(find.text('Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Ganti Password'), findsOneWidget);
    expect(find.text('CUST-02'), findsOneWidget);

    final saveButton = find.text('Simpan Password Baru');

    // password lama salah dan konfirmasi tidak sama memunculkan pesan validasi
    await tester.enterText(find.byType(TextFormField).at(0), 'salah123');
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');
    await tester.enterText(find.byType(TextFormField).at(2), 'rahasia999');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Password lama salah'), findsOneWidget);
    expect(find.text('Konfirmasi password tidak sama'), findsOneWidget);

    // input benar, password tersimpan dan form kosong lagi
    await tester.enterText(find.byType(TextFormField).at(0), 'ayamgoreng');
    await tester.enterText(find.byType(TextFormField).at(2), 'rahasia123');
    await tester.ensureVisible(saveButton);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(
      find.text('Password berhasil diubah. Gunakan password baru saat login berikutnya.'),
      findsOneWidget,
    );

    // logout, password lama ditolak dan password baru diterima
    await tester.tap(find.byTooltip('Keluar'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Keluar'));
    await tester.pumpAndSettle();

    await _login(tester, '089876543210', 'ayamgoreng');
    expect(find.text('Nomor HP atau password salah'), findsOneWidget);

    await _login(tester, '089876543210', 'rahasia123');
    expect(find.text('Halo, Jokowi 👋'), findsOneWidget);
  });
}
