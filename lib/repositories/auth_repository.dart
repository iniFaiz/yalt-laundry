import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_model.dart';

// error login / ganti password yang pesannya siap ditampilkan ke pengguna
class AuthFailure implements Exception {
  final String message;

  const AuthFailure(this.message);

  @override
  String toString() => message;
}

// akses Supabase Auth + tabel profiles, terpisah dari UI
class AuthRepository {
  // instance yang dipakai aplikasi, bisa diganti versi palsu saat tes
  static AuthRepository instance = AuthRepository();

  SupabaseClient get _client => Supabase.instance.client;

  // Supabase Auth memakai email, jadi nomor HP diubah menjadi email internal
  static String emailFromPhone(String phone) => '${phone.trim()}@yalt.test';

  // POST /auth/v1/token?grant_type=password lalu GET /rest/v1/profiles
  Future<CustomerModel> signIn(String phone, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(email: emailFromPhone(phone), password: password);
      return await _fetchProfile(response.user!.id);
    } on AuthApiException catch (e) {
      if (e.code == 'invalid_credentials') {
        throw const AuthFailure('Nomor HP atau password salah');
      }
      throw AuthFailure('Login gagal: ${e.message}');
    } on AuthException catch (_) {
      throw const AuthFailure('Tidak dapat terhubung ke server. Periksa koneksi internet.');
    }
  }

  // hapus sesi; jika server tidak terjangkau, cukup hapus sesi di perangkat
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } catch (_) {
      await _client.auth.signOut(scope: SignOutScope.local);
    }
  }

  // cek password lama dengan login ulang, lalu simpan password baru
  Future<void> changePassword(String phone, String oldPassword, String newPassword) async {
    try {
      await _client.auth.signInWithPassword(email: emailFromPhone(phone), password: oldPassword);
    } on AuthApiException catch (e) {
      if (e.code == 'invalid_credentials') {
        throw const AuthFailure('Password lama salah');
      }
      rethrow;
    }
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<CustomerModel> _fetchProfile(String userId) async {
    final row = await _client.from('profiles').select('id, full_name, phone, role').eq('id', userId).maybeSingle();
    if (row == null) {
      await _client.auth.signOut();
      throw const AuthFailure('Profil akun tidak ditemukan. Hubungi admin.');
    }
    // password tidak pernah diambil dari server
    return CustomerModel.fromJson(row);
  }
}
