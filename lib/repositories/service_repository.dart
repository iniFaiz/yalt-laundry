import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_model.dart';
import 'api_error.dart';

// hasil hapus layanan: dihapus permanen, atau dinonaktifkan karena sudah dipakai pesanan
enum ServiceDeleteAction { deleted, deactivated }

// akses data layanan ke Supabase, terpisah dari UI
class ServiceRepository {
  // instance yang dipakai aplikasi, bisa diganti versi palsu saat tes
  static ServiceRepository instance = ServiceRepository();

  final SupabaseClient? _injectedClient;

  ServiceRepository([this._injectedClient]);

  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  static const _columns = 'id, name, price_per_kg, is_active, duration_hours';

  // GET /rest/v1/services?select=...&order=name.asc
  Future<List<ServiceModel>> fetchServices() async {
    final rows = await _client.from('services').select(_columns).order('name', ascending: true);
    return rows.map(ServiceModel.fromJson).toList();
  }

  // POST /rest/v1/services (hanya admin, dicek RLS)
  Future<ServiceModel> addService(String name, double pricePerKG, {int durationHours = 48}) async {
    final row = await _client
        .from('services')
        .insert({'name': name, 'price_per_kg': pricePerKG, 'duration_hours': durationHours})
        .select(_columns)
        .single();
    return ServiceModel.fromJson(row);
  }

  // PATCH /rest/v1/services?id=eq.<id> (hanya admin, dicek RLS)
  Future<ServiceModel> updateService(
    String id, {
    String? name,
    double? pricePerKG,
    bool? isActive,
    int? durationHours,
  }) async {
    final row = await _client
        .from('services')
        // kolom bertanda ? hanya dikirim jika nilainya tidak null
        .update({
          'name': ?name,
          'price_per_kg': ?pricePerKG,
          'is_active': ?isActive,
          'duration_hours': ?durationHours,
        })
        .eq('id', id)
        .select(_columns)
        .single();
    return ServiceModel.fromJson(row);
  }

  // POST /rest/v1/rpc/sp_delete_service
  // layanan yang sudah dipakai pesanan hanya dinonaktifkan agar riwayat tetap utuh
  Future<ServiceDeleteAction> deleteService(String id) async {
    final result = await _client.rpc('sp_delete_service', params: {'p_service_id': id}) as Map<String, dynamic>;
    return result['action'] == 'deleted' ? ServiceDeleteAction.deleted : ServiceDeleteAction.deactivated;
  }

  // ubah error dari Supabase menjadi pesan yang mudah dipahami pengguna
  static String errorMessage(Object error) {
    if (error is PostgrestException) {
      switch (error.code) {
        case '23505':
          return 'Nama layanan sudah dipakai';
        case '23514':
          return 'Data layanan tidak valid';
        // 42501: ditolak RLS saat insert, PGRST116: update tidak mengenai baris (ditolak RLS)
        case '42501':
        case 'PGRST116':
          return 'Hanya admin yang dapat mengubah layanan';
      }
    }
    return apiErrorMessage(error, fallback: 'Gagal menyimpan layanan. Periksa koneksi internet lalu coba lagi.');
  }
}
