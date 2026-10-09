import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  final String role;

  const HomeScreen({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
