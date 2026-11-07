import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/config/env.dart';
import 'package:my_app/models/order_model.dart';
import 'package:my_app/repositories/auth_repository.dart';
import 'package:my_app/repositories/customer_repository.dart';
import 'package:my_app/repositories/order_repository.dart';
import 'package:my_app/repositories/service_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// tes integrasi: memanggil API Supabase sungguhan (butuh migration & seed sudah dijalankan)
// jalankan dengan: flutter test test/order_repository_test.dart --dart-define-from-file=.env
// Catatan: tes ini membuat pesanan sungguhan (tidak dihapus) sebagai bukti alur demo.
void main() {
  final skip = Env.isMissing ? 'Jalankan dengan --dart-define-from-file=.env' : false;

  const adminPhone = '081111111111';
  const prabowoPhone = '081234567890';
  const jokowiPhone = '089876543210';

  // client baru per pengguna agar sesi login tidak saling tercampur
  Future<SupabaseClient> loginAs(String phone) async {
    final client = SupabaseClient(
      Env.supabaseUrl,
      Env.supabasePublishableKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    await client.auth.signInWithPassword(email: AuthRepository.emailFromPhone(phone), password: 'ayamgoreng');
    return client;
  }

  Matcher postgrestError(String code, [String? hint]) => throwsA(
        isA<PostgrestException>()
            .having((e) => e.code, 'code', code)
            .having((e) => hint == null || e.hint == hint, 'hint $hint', isTrue),
      );

  late SupabaseClient admin;
  late SupabaseClient prabowo;
  late SupabaseClient jokowi;
  late String prabowoId;
  late String serviceId;

  setUpAll(() async {
    if (Env.isMissing) return;
    admin = await loginAs(adminPhone);
    prabowo = await loginAs(prabowoPhone);
    jokowi = await loginAs(jokowiPhone);
    prabowoId = prabowo.auth.currentUser!.id;
    final services = await ServiceRepository(admin).fetchServices();
    serviceId = services.firstWhere((s) => s.isActive).id;
  });

  tearDownAll(() async {
    if (Env.isMissing) return;
    for (final c in [admin, prabowo, jokowi]) {
      await c.auth.signOut();
    }
  });

  test('Alur demo: admin buat pesanan -> pelanggan lihat -> update status -> scan QR -> selesai', () async {
    final adminRepo = OrderRepository(admin);
    final prabowoRepo = OrderRepository(prabowo);
    final jokowiRepo = OrderRepository(jokowi);

    // admin membuat pesanan 2 item
    final created = await adminRepo.createOrder(
      customerId: prabowoId,
      items: [
        OrderItemInput(serviceId: serviceId, weightKg: 2.5),
        OrderItemInput(serviceId: serviceId, weightKg: 1),
      ],
      notes: 'tes integrasi flutter',
    );
    // ignore: avoid_print
    print('Pesanan tes integrasi: ${created.code} (${created.id})');
    expect(created.status, 'diterima');
    expect(created.items, hasLength(2));
    expect(created.totalPrice, created.items.fold(0.0, (s, i) => s + i.subtotal));
    expect(created.histories.single.toStatus, 'diterima');

    // RLS: pemilik melihat, pelanggan lain tidak
    expect((await prabowoRepo.fetchOrders()).any((o) => o.id == created.id), isTrue);
    expect((await jokowiRepo.fetchOrders()).any((o) => o.id == created.id), isFalse);
    await expectLater(jokowiRepo.fetchOrder(created.id), postgrestError('PGRST116'));
    await expectLater(jokowiRepo.fetchPickupToken(created.id), postgrestError('PT404', 'order_not_found'));

    // pelanggan tidak bisa mengubah status / membuat pesanan
    await expectLater(prabowoRepo.updateStatus(created.id, 'dicuci'), postgrestError('42501'));

    // transisi tidak valid ditolak
    await expectLater(adminRepo.updateStatus(created.id, 'siap_diambil'), postgrestError('PT409', 'invalid_transition'));
    await expectLater(adminRepo.updateStatus(created.id, 'diambil'), postgrestError('PT409', 'pickup_requires_qr'));

    // QR belum aktif sebelum siap diambil
    final token = (await prabowoRepo.fetchPickupToken(created.id))!;
    expect(token, matches(RegExp(r'^[0-9a-f]{32}$')));
    await expectLater(adminRepo.pickupByToken(token), postgrestError('PT409', 'not_ready'));

    // alur valid
    await adminRepo.updateStatus(created.id, 'dicuci');
    final ready = await adminRepo.updateStatus(created.id, 'siap_diambil');
    expect(ready.isReadyForPickup, isTrue);

    // dua scan QR bersamaan dari dua sesi admin: tepat satu yang berhasil (row lock)
    final admin2 = await loginAs(adminPhone);
    final results = await Future.wait([
      adminRepo.pickupByToken(OrderRepository.qrPayload(token)).then((o) => 'ok').catchError((Object e) => 'error:${(e as PostgrestException).hint}'),
      OrderRepository(admin2).pickupByToken(token).then((o) => 'ok').catchError((Object e) => 'error:${(e as PostgrestException).hint}'),
    ]);
    await admin2.auth.signOut();
    expect(results.where((r) => r == 'ok'), hasLength(1));
    expect(results.where((r) => r == 'error:token_used'), hasLength(1));

    // QR dipakai ulang ditolak, token tidak dikirim lagi
    await expectLater(adminRepo.pickupByToken(token), postgrestError('PT409', 'token_used'));
    expect(await prabowoRepo.fetchPickupToken(created.id), isNull);

    // riwayat status lengkap dari trigger, terlihat oleh pelanggan
    final finished = await prabowoRepo.fetchOrder(created.id);
    expect(finished.isCollected, isTrue);
    expect(finished.histories.map((h) => h.toStatus), ['diterima', 'dicuci', 'siap_diambil', 'diambil']);
  }, skip: skip);

  test('Transaksi: item kedua gagal -> seluruh pesanan dibatalkan (rollback)', () async {
    // select kolom eksplisit: select=* ditolak karena pickup_token tidak boleh dibaca
    Future<int> countOrders() async => (await admin.from('orders').select('id').count(CountOption.exact)).count;
    final before = await countOrders();
    await expectLater(
      OrderRepository(admin).createOrder(
        customerId: prabowoId,
        items: [
          OrderItemInput(serviceId: serviceId, weightKg: 3),
          OrderItemInput(serviceId: serviceId, weightKg: -1),
        ],
      ),
      postgrestError('22023', 'invalid_weight'),
    );
    final after = await countOrders();
    expect(after, before);
  }, skip: skip);

  test('Pelanggan tidak bisa membaca kolom pickup_token secara langsung', () async {
    await expectLater(
      prabowo.from('orders').select('pickup_token').limit(1),
      postgrestError('42501'),
    );
  }, skip: skip);

  test('Kelola pelanggan: buat akun, nomor ganda ditolak, lalu hapus', () async {
    final repo = CustomerRepository(admin);
    final phone = '0899${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final created = await repo.createCustomer('Pelanggan Integrasi', phone);
    try {
      expect(created.isAdmin, isFalse);
      await expectLater(repo.createCustomer('Ganda', phone), postgrestError('23505', 'phone_taken'));

      // akun baru langsung bisa login dengan password awal
      final client = await loginAs(phone);
      expect(client.auth.currentUser!.id, created.id);
      await client.auth.signOut();

      // pelanggan biasa tidak boleh memakai RPC admin
      await expectLater(CustomerRepository(prabowo).createCustomer('Penyusup', '089911112222'), postgrestError('42501'));
    } finally {
      await repo.deleteCustomer(created.id);
    }
    expect((await repo.fetchCustomers()).any((c) => c.id == created.id), isFalse);
  }, skip: skip);
}
