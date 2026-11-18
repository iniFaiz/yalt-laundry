import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_model.dart';
import 'api_error.dart';

// akses data pelanggan (akun login + profil) ke Supabase, khusus admin
class CustomerRepository {
  // instance yang dipakai aplikasi, bisa diganti versi palsu saat tes
  static CustomerRepository instance = CustomerRepository();

  final SupabaseClient? _injectedClient;

  CustomerRepository([this._injectedClient]);

  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  // GET /rest/v1/customer_summary_view?select=*&order=full_name.asc
  Future<List<CustomerModel>> fetchCustomers() async {
    final rows = await _client
        .from('customer_summary_view')
        .select('id, full_name, phone, order_count')
        .order('full_name', ascending: true);
    return rows.map(CustomerModel.fromJson).toList();
  }

  // POST /rest/v1/rpc/admin_create_customer — membuat akun login + profil
  // password awal wajib diisi admin, tidak ada password bawaan
  Future<CustomerModel> createCustomer(String name, String phone, String password) async {
    final row = await _client.rpc('admin_create_customer', params: {
      'p_full_name': name,
      'p_phone': phone,
      'p_password': password,
    }) as Map<String, dynamic>;
    return CustomerModel.fromJson(row);
  }

  // POST /rest/v1/rpc/admin_update_customer — nomor HP baru juga menjadi nomor login
  Future<CustomerModel> updateCustomer(String id, String name, String phone) async {
    final row = await _client.rpc('admin_update_customer', params: {
      'p_customer_id': id,
      'p_full_name': name,
      'p_phone': phone,
    }) as Map<String, dynamic>;
    return CustomerModel.fromJson(row);
  }

  // POST /rest/v1/rpc/admin_delete_customer — ditolak jika pelanggan sudah punya pesanan
  Future<void> deleteCustomer(String id) async {
    await _client.rpc('admin_delete_customer', params: {'p_customer_id': id});
  }

  static String errorMessage(Object error) =>
      apiErrorMessage(error, fallback: 'Gagal memproses data pelanggan. Periksa koneksi internet lalu coba lagi.');

  // true jika error karena nomor HP sudah dipakai akun lain
  static bool isPhoneTaken(Object error) => apiErrorHint(error) == 'phone_taken' ||
      (error is PostgrestException && error.code == '23505');
}
