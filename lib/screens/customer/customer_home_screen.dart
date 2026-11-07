import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../models/customer_model.dart';
import '../../models/service_model.dart';
import '../../repositories/auth_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/service_repository.dart';
import '../../utils/format_date.dart';
import '../../widgets/order_status_badge.dart';
import '../../widgets/state_views.dart';
import '../login_screen.dart';
import 'order_detail_screen.dart';
import 'profile_screen.dart';

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
  String? _errorMessage;
  List<OrderModel> _orders = [];
  List<ServiceModel> _services = [];
  void Function()? _unsubscribe;

  // inisialisasi awal saat widget pertama kali dimuat (lifecycle on start)
  @override
  void initState() {
    super.initState();
    // daftarkan observer lifecycle aplikasi
    WidgetsBinding.instance.addObserver(this);
    _loadData();
    // status cucian berubah di server (admin update / scan QR) -> muat ulang otomatis
    _unsubscribe = OrderRepository.instance.watchOrders(_loadData, customerId: widget.customer.id);
  }

  // observer & langganan realtime dilepas saat halaman ditutup (lifecycle on destroy)
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unsubscribe?.call();
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
    await _loadData();
    if (mounted && _errorMessage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status cucian diperbarui')),
      );
    }
  }

  // ambil pesanan milik pelanggan (dibatasi RLS) dan katalog layanan dari Supabase
  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        OrderRepository.instance.fetchOrders(customerId: widget.customer.id),
        ServiceRepository.instance.fetchServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _orders = results[0] as List<OrderModel>;
        _services = (results[1] as List<ServiceModel>).where((s) => s.isActive).toList();
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat data pelanggan: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = OrderRepository.errorMessage(e);
        _isLoading = false;
      });
    }
  }

  // fungsi asinkron untuk refresh data saat ditarik ke bawah
  Future<void> _handleRefresh() => _loadData();

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
            onPressed: () async {
              Navigator.pop(ctx);
              // hapus sesi Supabase Auth, lalu kembali ke login
              await AuthRepository.instance.signOut();
              if (!mounted) return;
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
    // pesanan sudah difilter server (RLS hanya mengembalikan milik pelanggan ini)
    final activeOrders = _orders.where((o) => o.isActive).toList();
    final pastOrders = _orders.where((o) => o.isCollected).toList();

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
          // tab profil tidak perlu tarik untuk refresh
          : _currentIndex == 2
              ? ProfileScreen(customer: widget.customer, orderCount: _orders.length)
              : RefreshIndicator(
                  onRefresh: _handleRefresh,
                  child: _errorMessage != null && _orders.isEmpty
                      ? ErrorStateView(
                          message: _errorMessage!,
                          onRetry: () {
                            setState(() => _isLoading = true);
                            _loadData();
                          },
                        )
                      : _currentIndex == 0
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
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: Color(0xFF007BFF)),
              label: 'Profil',
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
          const EmptyStateView(message: 'Tidak ada cucian aktif saat ini.', icon: Icons.dry_cleaning_outlined)
        else
          ...activeOrders.map((order) => _buildModernOrderCard(order, isActive: true)),
      ],
    );
  }

  // widget gridview untuk daftar paket layanan 2 kolom
  Widget _buildServiceGrid() {
    // hanya tampilkan layanan yang masih aktif
    final services = _services;
    if (services.isEmpty) {
      return const EmptyStateView(message: 'Belum ada layanan tersedia', icon: Icons.local_laundry_service_outlined);
    }

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
      // dibungkus ListView agar tetap bisa ditarik untuk refresh
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const EmptyStateView(message: 'Belum ada riwayat pesanan yang selesai.', icon: Icons.history_rounded),
        ],
      );
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
            // setelah kembali (pop) dari detail, muat ulang status terbaru
            if (mounted) {
              _loadData();
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
                    Flexible(
                      child: Text(
                        order.code,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // status ditampilkan dengan teks + ikon + warna
                    Flexible(child: OrderStatusBadge(status: order.status)),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.serviceName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            isActive
                                ? '${order.formattedWeight} • Estimasi ${formatDayTime(order.estimatedCompletionAt)}'
                                : '${order.formattedWeight} • Diambil ${formatDayTime(order.pickupTokenUsedAt!)}',
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
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
}
