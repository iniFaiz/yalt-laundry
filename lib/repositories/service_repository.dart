import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/service_model.dart';

// akses data layanan ke Supabase, terpisah dari UI
class ServiceRepository {
  final SupabaseClient _client;

  ServiceRepository([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  // GET /rest/v1/services?select=*&order=name.asc
  Future<List<ServiceModel>> fetchServices() async {
    final rows = await _client
        .from('services')
        .select('id, name, price_per_kg, is_active')
        .order('name', ascending: true);
    return rows.map(ServiceModel.fromJson).toList();
  }

  // POST /rest/v1/services (hanya admin, dicek RLS)
  Future<ServiceModel> addService(String name, double pricePerKG) async {
    final row = await _client
        .from('services')
        .insert({'name': name, 'price_per_kg': pricePerKG})
        .select('id, name, price_per_kg, is_active')
        .single();
    return ServiceModel.fromJson(row);
  }

  // PATCH /rest/v1/services?id=eq.<id> (hanya admin, dicek RLS)
  Future<ServiceModel> updateService(String id, {String? name, double? pricePerKG, bool? isActive}) async {
    final row = await _client
        .from('services')
        // kolom bertanda ? hanya dikirim jika nilainya tidak null
        .update({'name': ?name, 'price_per_kg': ?pricePerKG, 'is_active': ?isActive})
        .eq('id', id)
        .select('id, name, price_per_kg, is_active')
        .single();
    return ServiceModel.fromJson(row);
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
    return 'Gagal menyimpan layanan. Periksa koneksi internet lalu coba lagi.';
  }
}
