// konfigurasi Supabase dibaca saat build dari file .env
// jalankan dengan: flutter run --dart-define-from-file=.env
class Env {
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabasePublishableKey = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  // true jika app dijalankan tanpa --dart-define-from-file=.env
  static bool get isMissing => supabaseUrl.isEmpty || supabasePublishableKey.isEmpty;
}
