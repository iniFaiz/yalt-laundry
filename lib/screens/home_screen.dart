import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import 'admin/admin_dashboard.dart';
import 'customer/customer_home_screen.dart';

class HomeScreen extends StatelessWidget {
  final CustomerModel currentUser;

  const HomeScreen({
    super.key,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context) {
    // if admin go admin page
    if (currentUser.role == 'Admin') {
      return const AdminDashboard();
    }

    // if user
    return CustomerHomeScreen(customer: currentUser);
  }
}