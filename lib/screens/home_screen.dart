import 'package:flutter/material.dart';
import 'admin/admin_dashboard.dart'; 

class HomeScreen extends StatelessWidget {
  final String role;

  const HomeScreen({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    // if admin go admin
    if (role == 'Admin') {
      return const AdminDashboard();
    }

    // uiser
    return Scaffold(
      appBar: AppBar(
        title: const Text('Beranda Pelanggan'),
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          'Kamu adalah $role',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}