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
}
