import 'package:flutter/material.dart';
import '../../repositories/auth_repository.dart';
import '../login_screen.dart';
import 'service_screen.dart';
import 'order_entry_screen.dart';
import 'order_monitoring_screen.dart';
import 'customer_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  // var index tab aktif
  int _currentIndex = 0;

  // tab dibuat saat pertama kali dibuka lalu dipertahankan di IndexedStack
  // agar draft Kasir POS tidak hilang saat pindah tab dan tidak boros request di awal
  final Set<int> _visitedTabs = {0};

  final _posKey = GlobalKey<OrderEntryScreenState>();
  final _monitoringKey = GlobalKey<OrderMonitoringScreenState>();
  final _customerKey = GlobalKey<CustomerScreenState>();

  void _selectTab(int index) {
    final alreadyVisited = _visitedTabs.contains(index);
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
    });
    if (!alreadyVisited) return;
    // segarkan data referensi secara ringan tanpa menghapus isian form
    switch (index) {
      case 0:
        _posKey.currentState?.refreshReferenceData();
      case 1:
        _monitoringKey.currentState?.refresh();
      case 2:
        _customerKey.currentState?.refresh();
    }
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah kamu yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              // hapus sesi Supabase Auth, lalu kembali ke login
              await AuthRepository.instance.signOut();
              if (!context.mounted) return;
              // kembali ke Login pakai push & bersihkan riwayat halaman
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel Kasir / Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Keluar Akun',
            onPressed: () => _showLogoutDialog(context),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          OrderEntryScreen(key: _posKey),
          _visitedTabs.contains(1) ? OrderMonitoringScreen(key: _monitoringKey) : const SizedBox.shrink(),
          _visitedTabs.contains(2) ? CustomerScreen(key: _customerKey) : const SizedBox.shrink(),
          _visitedTabs.contains(3) ? const ServiceScreen() : const SizedBox.shrink(),
        ],
      ),
      // navbarnya
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.point_of_sale_outlined),
            label: 'Kasir POS',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes_outlined),
            selectedIcon: Icon(Icons.track_changes),
            label: 'Monitoring',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Pelanggan',
          ),
          NavigationDestination(
            icon: Icon(Icons.local_laundry_service_outlined),
            selectedIcon: Icon(Icons.local_laundry_service),
            label: 'Layanan',
          ),
        ],
      ),
    );
  }
}
