import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/config/env.dart';
import 'package:my_app/repositories/auth_repository.dart';
import 'package:my_app/repositories/service_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'test_credentials.dart';

// tes integrasi: memanggil API Supabase sungguhan (butuh migration & seed sudah dijalankan)
// jalankan dengan: flutter test test/service_repository_test.dart --dart-define-from-file=.env
void main() {
  final skip = Env.isMissing || adminPassword.isEmpty
      ? 'Jalankan dengan --dart-define-from-file=.env --dart-define-from-file=.env.test'
      : false;

  // client baru per tes agar sesi login tidak saling tercampur
  SupabaseClient newClient() => SupabaseClient(
    Env.supabaseUrl,
    Env.supabasePublishableKey,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );

  Future<SupabaseClient> loginAs(String phone) async {
    final client = newClient();
    await client.auth.signInWithPassword(email: AuthRepository.emailFromPhone(phone), password: passwordFor(phone));
    return client;
  }

  test('fetchServices mengambil daftar layanan dari Supabase', () async {
    final services = await ServiceRepository(newClient()).fetchServices();

    expect(services, isNotEmpty);
    expect(services.every((s) => s.pricePerKG > 0), isTrue);
  }, skip: skip);

  test('RLS: pengguna tanpa login tidak bisa menambah layanan', () async {
    final repository = ServiceRepository(newClient());

    await expectLater(
      repository.addService('Tes Tanpa Login', 1000),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
  }, skip: skip);

  test('RLS: pelanggan tidak bisa menambah atau mengubah layanan', () async {
    final client = await loginAs('081234567890');
    final repository = ServiceRepository(client);
    final service = (await repository.fetchServices()).first;

    await expectLater(
      repository.addService('Tes Pelanggan', 1000),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    // update yang ditolak RLS tidak mengenai baris apa pun
    await expectLater(
      repository.updateService(service.id, pricePerKG: 1),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST116')),
    );
    await client.auth.signOut();
  }, skip: skip);

  test('RLS: admin bisa menambah, mengubah, dan menonaktifkan layanan', () async {
    final client = await loginAs('081111111111');
    final repository = ServiceRepository(client);
    final name = 'Tes Admin ${DateTime.now().millisecondsSinceEpoch}';

    final created = await repository.addService(name, 7000);
    try {
      expect(created.name, name);
      expect(created.isActive, isTrue);

      final updated = await repository.updateService(created.id, pricePerKG: 7500, isActive: false);
      expect(updated.pricePerKG, 7500);
      expect(updated.isActive, isFalse);
    } finally {
      // bersihkan data tes (layanan ini belum dipakai pesanan, jadi boleh dihapus)
      await client.from('services').delete().eq('id', created.id);
      await client.auth.signOut();
    }
  }, skip: skip);
}
