import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/env.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  // binding harus siap sebelum memanggil SystemChrome
  WidgetsFlutterBinding.ensureInitialized();
  // kunci orientasi layar hanya vertikal (portrait), mode horizontal dimatikan
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // tampilkan petunjuk di layar (bukan crash) jika app dijalankan tanpa .env
  if (Env.isMissing) {
    runApp(const _MissingConfigApp());
    return;
  }
  // inisialisasi client Supabase sekali di awal, dipakai lewat Supabase.instance.client
  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabasePublishableKey,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yalt',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007BFF),
          primary: const Color(0xFF007BFF),
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      // halaman awal aplikasi, perpindahan halaman memakai Navigator push/pop
      home: const LoginScreen(),
    );
  }
}

// layar petunjuk saat SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY tidak terisi
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings_suggest_outlined, size: 64, color: Color(0xFF007BFF)),
                SizedBox(height: 16),
                Text(
                  'Konfigurasi Supabase belum terisi',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 12),
                Text(
                  'Jalankan aplikasi dengan file .env:\n\nflutter run --dart-define-from-file=.env',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
