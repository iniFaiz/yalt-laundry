import 'package:supabase_flutter/supabase_flutter.dart';

/// Mengubah error dari Supabase menjadi pesan yang siap ditampilkan ke pengguna.
///
/// Fungsi RPC di database sudah mengirim pesan berbahasa Indonesia dengan kode:
/// 42501 (403, tidak berhak), 22023 (400, input salah), 23505 (409, data ganda),
/// PT404 (404, tidak ditemukan), PT409 (409, konflik status / QR sudah dipakai).
String apiErrorMessage(Object error, {required String fallback}) {
  if (error is PostgrestException) {
    switch (error.code) {
      case 'PT404':
      case 'PT409':
      case '22023':
        return error.message;
      case '23505':
        return error.message.contains('duplicate key') ? 'Data sudah terdaftar' : error.message;
      case '23503':
        return 'Data masih dipakai oleh data lain';
      case '23514':
        return 'Data tidak valid';
      case '42501':
        return error.message.startsWith('permission denied') ? 'Akses ditolak' : error.message;
      case 'PGRST116':
        return 'Data tidak ditemukan atau akses ditolak';
    }
  }
  return fallback;
}

/// hint dari RAISE ... USING hint = '...' (contoh: token_used, phone_taken)
String? apiErrorHint(Object error) => error is PostgrestException ? error.hint : null;
