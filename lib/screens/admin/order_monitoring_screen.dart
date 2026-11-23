import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../repositories/api_error.dart';
import '../../repositories/order_repository.dart';
import '../../utils/format_date.dart';
import '../../utils/format_rupiah.dart';
import '../../widgets/order_status_badge.dart';
import '../../widgets/state_views.dart';
import '../customer/order_detail_screen.dart';
import 'qr_scan_screen.dart';

class OrderMonitoringScreen extends StatefulWidget {
  const OrderMonitoringScreen({super.key});

  @override
  State<OrderMonitoringScreen> createState() => OrderMonitoringScreenState();
}

class OrderMonitoringScreenState extends State<OrderMonitoringScreen> {
  final OrderRepository _repository = OrderRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  List<OrderModel> _orders = [];
  OrderSummary? _summary; // agregat akurat dari daily_order_report_view (tidak terpotong limit 200)
  String _searchQuery = '';
  bool _isLoading = true; // status loading data awal
  String? _errorMessage;
  final Set<String> _updatingIds = {}; // pesanan yang sedang diubah statusnya
  void Function()? _unsubscribe;

  // inisialisasi awal saat halaman dibuka (lifecycle on start)
  @override
  void initState() {
    super.initState();
    _loadOrders();
    // muat ulang otomatis jika ada pesanan yang berubah (Supabase Realtime)
    _unsubscribe = _repository.watchOrders(_loadOrders);
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _searchController.dispose();
    super.dispose();
  }

  // dipanggil saat admin berpindah kembali ke tab Monitoring
  Future<void> refresh() => _loadOrders();

  // ambil daftar pesanan dan ringkasan agregat dari daily_order_report_view secara paralel
  Future<void> _loadOrders() async {
    try {
      final results = await Future.wait<Object?>([
        _repository.fetchOrders(),
        _repository.fetchOrderSummary().then<OrderSummary?>((s) => s).catchError((_) => null),
      ]);
      if (!mounted) return;
      setState(() {
        _orders = results[0] as List<OrderModel>;
        _summary = results[1] as OrderSummary? ?? _summary;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat pesanan: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = OrderRepository.errorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshSummaryOnly() async {
    try {
      final summary = await _repository.fetchOrderSummary();
      if (mounted) setState(() => _summary = summary);
    } catch (_) {
      // biarkan angka sebelumnya jika view gagal dimuat sementara
    }
  }

  void _replaceOrder(OrderModel updated) {
    final index = _orders.indexWhere((o) => o.id == updated.id);
    if (index != -1) {
      _orders[index] = updated;
    } else {
      _orders.insert(0, updated);
    }
  }

  // PEMBARUAN STATUS lewat RPC sp_update_order_status (transisi divalidasi database)
  Future<void> _advanceOrderStatus(OrderModel order) async {
    final next = order.nextAdminStatus;
    if (next == null) return;
    setState(() => _updatingIds.add(order.id));
    try {
      final updated = await _repository.updateStatus(order.id, next);
      if (!mounted) return;
      setState(() {
        _replaceOrder(updated);
        _updatingIds.remove(order.id);
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pesanan ${order.code} sekarang berstatus: ${updated.statusLabel}')),
      );
    } catch (e) {
      debugPrint('Gagal mengubah status: $e');
      if (!mounted) return;
      setState(() => _updatingIds.remove(order.id));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(OrderRepository.errorMessage(e))),
      );
      // status di layar mungkin sudah usang, muat ulang dari server
      _loadOrders();
    }
  }

  // buka scanner, lalu verifikasi token ke server (sp_pickup_order)
  Future<void> _openScanner() async {
    final token = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (token == null || token.isEmpty || !mounted) return;
    await _verifyQRPickup(token);
  }

  // LOGIKA VERIFIKASI QR PENGAMBILAN: validasi & tandai token terpakai secara atomik di database
  Future<void> _verifyQRPickup(String token) async {
    // tampilkan dialog loading proses verifikasi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Memverifikasi QR...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final order = await _repository.pickupByToken(token);
      if (!mounted) return;
      Navigator.pop(context); // tutup loading dialog
      setState(() => _replaceOrder(order));
      _refreshSummaryOnly();
      _showScanResultDialog(
        success: true,
        title: 'Pengambilan Berhasil!',
        message: 'Cucian ${order.code} untuk ${order.customerName} '
            '(${order.serviceName} - ${order.formattedWeight}) berhasil diserahkan.',
      );
    } catch (e) {
      debugPrint('Verifikasi QR gagal: $e');
      if (!mounted) return;
      Navigator.pop(context); // tutup loading dialog
      // hint dikirim fungsi database untuk membedakan jenis penolakan
      final title = switch (apiErrorHint(e)) {
        'token_used' => 'QR Sudah Dipakai!',
        'not_ready' => 'Cucian Belum Siap!',
        'token_not_found' => 'QR Tidak Valid!',
        _ => 'Verifikasi Gagal',
      };
      _showScanResultDialog(success: false, title: title, message: OrderRepository.errorMessage(e));
      _loadOrders();
    }
  }

  void _showScanResultDialog({required bool success, required String title, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(
          success ? Icons.check_circle : Icons.error,
          color: success ? Colors.green : Colors.red,
          size: 48,
        ),
        title: Text(title),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  List<OrderModel> _applySearch(List<OrderModel> source) {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return source;
    return source
        .where((o) =>
            o.code.toLowerCase().contains(q) ||
            o.customerName.toLowerCase().contains(q) ||
            o.customerPhone.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final allActive = _orders.where((o) => o.isActive).toList();
    final allCompleted = _orders.where((o) => o.isCollected).toList();
    final active = _applySearch(allActive);
    final completed = _applySearch(allCompleted);

    // gunakan agregat akurat dari daily_order_report_view bila tersedia
    final activeCount = _summary?.activeCount ?? allActive.length;
    final completedCount = _summary?.completedCount ?? allCompleted.length;
    final totalRevenue =
        _summary?.collectedRevenue ?? allCompleted.fold<double>(0.0, (sum, o) => sum + o.totalPrice);
    final header = Column(
      children: [
        _buildReportCard(activeCount, completedCount, totalRevenue),
        _buildSearchField(),
      ],
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Monitoring & Laporan'),
          centerTitle: true,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Cucian Aktif', icon: Icon(Icons.local_laundry_service)),
              Tab(text: 'Riwayat Selesai', icon: Icon(Icons.history)),
            ],
          ),
        ),
        // tombol Scanner QR terbang
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openScanner,
          backgroundColor: const Color(0xFF007BFF),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan QR Pickup'),
        ),
        // kartu laporan & pencarian ditaruh di dalam list tiap tab agar ikut ter-scroll
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  RefreshIndicator(
                    onRefresh: _loadOrders,
                    child: _buildOrderList(active, isActiveList: true, header: header),
                  ),
                  RefreshIndicator(
                    onRefresh: _loadOrders,
                    child: _buildOrderList(completed, isActiveList: false, header: header),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Cari kode ORD, nama, atau nomor HP...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Hapus pencarian',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  // KARTU LAPORAN
  Widget _buildReportCard(int activeOrders, int completedOrders, double totalRevenue) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.blue.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.blue.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildReportStat('Aktif', '$activeOrders', Colors.orange.shade800),
            _buildReportStat('Selesai', '$completedOrders', Colors.green.shade800),
            _buildReportStat('Omzet Selesai', formatRupiah(totalRevenue), Colors.blue.shade900),
          ],
        ),
      ),
    );
  }

  Widget _buildReportStat(String label, String value, Color color) {
    // Expanded membagi lebar sama rata, FittedBox mengecilkan teks jika tidak muat
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<OrderModel> orders, {required bool isActiveList, required Widget header}) {
    if (_errorMessage != null && _orders.isEmpty) {
      return ErrorStateView(
        message: _errorMessage!,
        onRetry: () {
          setState(() => _isLoading = true);
          _loadOrders();
        },
      );
    }

    if (orders.isEmpty) {
      // dibungkus ListView agar tetap bisa ditarik untuk refresh
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          header,
          EmptyStateView(
            message: _searchQuery.trim().isNotEmpty
                ? 'Pesanan tidak ditemukan untuk "${_searchQuery.trim()}"'
                : (isActiveList ? 'Tidak ada cucian aktif' : 'Belum ada pesanan yang selesai'),
            icon: _searchQuery.trim().isNotEmpty
                ? Icons.search_off
                : (isActiveList ? Icons.local_laundry_service_outlined : Icons.history),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88), // ruang bawah untuk tombol mengambang
      // item pertama adalah kartu laporan + pencarian, sisanya kartu pesanan
      itemCount: orders.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return header;
        return _buildOrderCard(orders[index - 1], isActiveList);
      },
    );
  }

  Widget _buildOrderCard(OrderModel order, bool isActiveList) {
    final isUpdating = _updatingIds.contains(order.id);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order, isAdmin: true)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // baris atas: nama & badge status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      order.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  OrderStatusBadge(status: order.status),
                ],
              ),
              const SizedBox(height: 6),
              Text('${order.code} • ${order.serviceName}'),
              Text('${order.formattedWeight} • Total: ${order.formattedTotalPrice}'),
              Text(
                order.isCollected
                    ? (order.pickupTokenUsedAt != null
                        ? 'Diambil: ${formatDayTime(order.pickupTokenUsedAt!)}'
                        : 'Sudah diambil')
                    : 'Estimasi selesai: ${formatDayTime(order.estimatedCompletionAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),

              // tombol Update Status
              if (isActiveList) ...[
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isUpdating)
                      const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                    else if (order.status == 'diterima')
                      ElevatedButton.icon(
                        onPressed: () => _advanceOrderStatus(order),
                        icon: const Icon(Icons.waves, size: 16),
                        label: const Text('Mulai Cuci'),
                      )
                    else if (order.status == 'dicuci')
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () => _advanceOrderStatus(order),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Siap Diambil'),
                      )
                    else if (order.isReadyForPickup)
                      // Flexible agar teks turun ke baris baru di layar sempit
                      const Flexible(
                        child: Text(
                          'Menunggu Scan QR Pelanggan',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.green),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
