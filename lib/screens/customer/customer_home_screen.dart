import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../models/customer_model.dart';
import '../login_screen.dart';
import 'order_detail_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  final CustomerModel customer;

  const CustomerHomeScreen({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  // index untuk bottom navbar
  int _currentIndex = 0;

  //  logout dialog
  void _confirmLogout() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Keluar Akun'),
        content: const Text('Apakah kamu yakin ingin keluar dari akun ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
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
    // filter hanya ambil cucian milik nomor hp pelanggan yang sedang login
    final myOrders = OrderModel.dummyOrders
        .where((o) => o.customerPhone == widget.customer.phone)
        .toList();

    final activeOrders = myOrders.where((o) => o.status != 'diambil').toList();
    final pastOrders = myOrders.where((o) => o.status == 'diambil').toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // latar belakang abu sangat lembut
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF007BFF).withOpacity(0.12),
              child: const Icon(Icons.person, color: Color(0xFF007BFF), size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Halo, ${widget.customer.name} 👋',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                Text(
                  widget.customer.phone,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.black54),
            tooltip: 'Keluar',
            onPressed: _confirmLogout,
          ),
        ],
      ),

      // tampilkan halaman sesuai tab yang dipilih
      body: _currentIndex == 0
          ? _buildHomeTab(activeOrders)
          : _buildHistoryTab(pastOrders),

      // bottom navigation bar material 3
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          selectedIndex: _currentIndex,
          indicatorColor: const Color(0xFF007BFF).withOpacity(0.15),
          onDestinationSelected: (int index) {
            setState(() {
              _currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: Color(0xFF007BFF)),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: Color(0xFF007BFF)),
              label: 'Riwayat Pesanan',
            ),
          ],
        ),
      ),
    );
  }

  // tab home
  Widget _buildHomeTab(List<OrderModel> activeOrders) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // BANNER SAMBUTAN
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF007BFF), Color(0xFF0056B3)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lacak Cucian Lebih Praktis',
                style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 6),
              Text(
                'Tunjukkan QR Code saat cucian sudah siap diambil di outlet.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // JUDUL SECTION CUCIAN AKTIF
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cucian Sedang Berlangsung',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF007BFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${activeOrders.length} Aktif',
                style: const TextStyle(color: Color(0xFF007BFF), fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // daftar kartu pesanan aktif
        if (activeOrders.isEmpty)
          _buildEmptyState('Tidak ada cucian aktif saat ini.', Icons.dry_cleaning_outlined)
        else
          ...activeOrders.map((order) => _buildModernOrderCard(order, isActive: true)),
      ],
    );
  }

  // tab riwayat
  Widget _buildHistoryTab(List<OrderModel> pastOrders) {
    if (pastOrders.isEmpty) {
      return _buildEmptyState('Belum ada riwayat pesanan yang selesai.', Icons.history_rounded);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const Text(
          'Riwayat Transaksi',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        ...pastOrders.map((order) => _buildModernOrderCard(order, isActive: false)),
      ],
    );
  }

  // kartu pesanan
  Widget _buildModernOrderCard(OrderModel order, {required bool isActive}) {
    // Pewarnaan status yang lembut & elegan
    Color statusBg;
    Color statusTextColor;
    String statusLabel;

    switch (order.status) {
      case 'diterima':
        statusBg = const Color(0xFFE3F2FD);
        statusTextColor = const Color(0xFF1976D2);
        statusLabel = 'Diterima';
        break;
      case 'dicuci':
        statusBg = const Color(0xFFFFF3E0);
        statusTextColor = const Color(0xFFE65100);
        statusLabel = 'Sedang Dicuci';
        break;
      case 'siap_diambil':
        statusBg = const Color(0xFFE8F5E9);
        statusTextColor = const Color(0xFF2E7D32);
        statusLabel = 'Siap Diambil';
        break;
      default:
        statusBg = const Color(0xFFF5F5F5);
        statusTextColor = Colors.black54;
        statusLabel = 'Selesai';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // pindah ke detail & tracking
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // baris atas: Order ID & Badge Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.id,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(color: statusTextColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // baris layanan dan berat
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.local_laundry_service, color: Color(0xFF007BFF), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.serviceName,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${order.weight} kg',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.0),
                  child: Divider(height: 1, color: Color(0xFFEEEEEE)),
                ),

                // baris bawah: total biaya dan tombol detail
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Tagihan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        Text(
                          'Rp ${order.totalPrice.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF007BFF),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          isActive ? 'Lacak & QR' : 'Lihat Struk',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF007BFF)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF007BFF)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}