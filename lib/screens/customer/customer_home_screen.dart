import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../models/customer_model.dart';
import '../../models/service_model.dart';
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

// WidgetsBindingObserver dipakai untuk memantau lifecycle aplikasi (on pause / on resume)
class _CustomerHomeScreenState extends State<CustomerHomeScreen> with WidgetsBindingObserver {
  // index untuk bottom navbar
  int _currentIndex = 0;
  bool _isLoading = true; // status loading data awal

  // inisialisasi awal saat widget pertama kali dimuat (lifecycle on start)
  @override
  void initState() {
    super.initState();
    // daftarkan observer lifecycle aplikasi
    WidgetsBinding.instance.addObserver(this);
    _loadInitialOrders();
  }

  // observer dilepas saat halaman ditutup (lifecycle on destroy)
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // dipanggil otomatis setiap status lifecycle aplikasi berubah
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // on pause: aplikasi masuk background (pindah app / layar dimatikan)
      debugPrint('Lifecycle: on pause');
    } else if (state == AppLifecycleState.resumed) {
      // on resume: aplikasi dibuka lagi, muat ulang status cucian terbaru
      debugPrint('Lifecycle: on resume');
      _reloadOnResume();
    }
  }

  // fungsi asinkron muat ulang data saat aplikasi kembali dibuka
  Future<void> _reloadOnResume() async {
    await _handleRefresh();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status cucian diperbarui')),
      );
    }
  }

  // fungsi asinkron memuat data awal cucian pelanggan
  Future<void> _loadInitialOrders() async {
    // simulasi jeda asinkron load data dari server
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // fungsi asinkron untuk refresh data saat ditarik ke bawah
  Future<void> _handleRefresh() async {
    // simulasi pembaruan data terbaru
    await Future.delayed(const Duration(milliseconds: 700));
    if (mounted) {
      setState(() {});
    }
  }

  // dialog konfirmasi keluar akun
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
              // kembali ke login pakai push dan hapus tumpukan halaman
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
              backgroundColor: const Color(0xFF007BFF).withValues(alpha: 0.12),
              child: const Icon(Icons.person, color: Color(0xFF007BFF), size: 20),
            ),
            const SizedBox(width: 12),
            // Expanded agar nama panjang tidak overflow, dipotong dengan ellipsis
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, ${widget.customer.name} 👋',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  Text(
                    widget.customer.phone,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
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

      // tampilkan loading indicator jika proses asinkron awal masih berjalan
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _handleRefresh,
              child: _currentIndex == 0
                  ? _buildHomeTab(activeOrders)
                  : _buildHistoryTab(pastOrders),
            ),

      // bottom navigation bar material 3
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -3),
            ),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.white,
          elevation: 0,
          selectedIndex: _currentIndex,
          indicatorColor: const Color(0xFF007BFF).withValues(alpha: 0.15),
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
      physics: const AlwaysScrollableScrollPhysics(), // agar RefreshIndicator selalu bisa ditarik
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

        const SizedBox(height: 22),

        // SEKSI KATALOG LAYANAN DENGAN GRIDVIEW
        const Text(
          'Paket Layanan Tersedia',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 10),
        _buildServiceGrid(),

        const SizedBox(height: 24),

        // JUDUL SECTION CUCIAN AKTIF
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Cucian Sedang Berlangsung',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF007BFF).withValues(alpha: 0.1),
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

        // daftar kartu pesanan aktif (ListView)
        if (activeOrders.isEmpty)
          _buildEmptyState('Tidak ada cucian aktif saat ini.', Icons.dry_cleaning_outlined)
        else
          ...activeOrders.map((order) => _buildModernOrderCard(order, isActive: true)),
      ],
    );
  }

  // widget gridview untuk daftar paket layanan 2 kolom
  Widget _buildServiceGrid() {
    // hanya tampilkan layanan yang masih aktif
    final services = ServiceModel.dummyServices.where((s) => s.isActive).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(), // menyatu dengan scroll ListView
      itemCount: services.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 kolom sejajar
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 72, // tinggi kartu tetap agar teks tidak terpotong
      ),
      itemBuilder: (context, index) {
        final service = services[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF007BFF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_getServiceIcon(service.name), color: const Color(0xFF007BFF), size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      service.name,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // menggunakan getter formattedPrice dari model
                    Text(
                      service.formattedPrice,
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ikon kartu layanan berdasarkan nama layanan
  IconData _getServiceIcon(String name) {
    switch (name) {
      case 'Cuci Setrika':
        return Icons.iron;
      case 'Setrika Saja':
        return Icons.checkroom;
      case 'Cuci Kilat':
        return Icons.flash_on;
      default:
        return Icons.local_laundry_service;
    }
  }

  // tab riwayat
  Widget _buildHistoryTab(List<OrderModel> pastOrders) {
    if (pastOrders.isEmpty) {
      return _buildEmptyState('Belum ada riwayat pesanan yang selesai.', Icons.history_rounded);
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
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
          onTap: () async {
            // pindah ke detail pakai push, objek order dikirim lewat argumen constructor
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OrderDetailScreen(order: order),
              ),
            );
            // setelah kembali (pop) dari detail, refresh tampilan status
            if (mounted) {
              setState(() {});
            }
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

                // baris layanan dan berat memakai getter model
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
                          order.formattedWeight,
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

                // baris bawah: total biaya memakai getter dan tombol detail
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Tagihan', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            order.formattedTotalPrice,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF007BFF),
                            ),
                          ),
                        ],
                      ),
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
