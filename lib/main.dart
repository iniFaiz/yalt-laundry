import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';

Future<void> main() async {
  // binding harus siap sebelum memanggil SystemChrome
  WidgetsFlutterBinding.ensureInitialized();
  // kunci orientasi layar hanya vertikal (portrait), mode horizontal dimatikan
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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
