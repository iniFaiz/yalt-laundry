import 'package:flutter/material.dart';
import 'models/customer_model.dart';
import 'models/order_model.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/order_detail_screen.dart';

void main() {
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
      // inisialisasi rute awal aplikasi
      initialRoute: '/',
      // pendaftaran named route
      routes: {
        '/': (context) => const LoginScreen(),
        '/admin': (context) => const AdminDashboard(),
      },
      // handler named route dengan parameter data
      onGenerateRoute: (settings) {
        if (settings.name == '/home') {
          final user = settings.arguments as CustomerModel;
          return MaterialPageRoute(
            builder: (_) => HomeScreen(currentUser: user),
            settings: settings,
          );
        }
        if (settings.name == '/customer-home') {
          final user = settings.arguments as CustomerModel;
          return MaterialPageRoute(
            builder: (_) => CustomerHomeScreen(customer: user),
            settings: settings,
          );
        }
        if (settings.name == '/order-detail') {
          final order = settings.arguments as OrderModel;
          return MaterialPageRoute(
            builder: (_) => OrderDetailScreen(order: order),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
