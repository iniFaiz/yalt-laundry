import 'package:flutter/material.dart';
import '../../models/order_model.dart';

class OrderMonitoringScreen extends StatefulWidget {
  const OrderMonitoringScreen({super.key});

  @override
  State<OrderMonitoringScreen> createState() => _OrderMonitoringScreenState();
}

class _OrderMonitoringScreenState extends State<OrderMonitoringScreen> {
  // simulasi Scanner input token QR
  final TextEditingController _qrInputController = TextEditingController();

  // Helper warna badge status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'diterima':
        return Colors.blue;
      case 'dicuci':
        return Colors.orange;
      case 'siap_diambil':
        return Colors.green;
      case 'diambil':
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  // PEMBARUAN STATUS
  void _advanceOrderStatus(OrderModel order) {
    setState(() {
      if (order.status == 'diterima') {
        order.status = 'dicuci';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pesanan ${order.id} status diubah ke: DICUCI')),
        );
      } else if (order.status == 'dicuci') {
        order.status = 'siap_diambil';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pesanan ${order.id} siap diambil pelanggan!')),
        );
      }
    });
  }

  // 2. LOGIKA VERIFIKASI SCANNER QR PENGAMBILAN
  void _verifyQRPickup(String token) {
    token = token.trim();
    if (token.isEmpty) return;

    // Cari pesanan berdasarkan token QR
    final orderIndex = OrderModel.dummyOrders.indexWhere((o) => o.pickupToken == token);

    if (orderIndex == -1) {
      _showScanResultDialog(
        success: false,
        title: 'QR Tidak Valid!',
        message: 'Token QR tidak ditemukan dalam sistem.',
      );
      return;
    }

    final order = OrderModel.dummyOrders[orderIndex];

    // Cek kondisi status
    if (order.status == 'diambil') {
      _showScanResultDialog(
        success: false,
        title: 'QR Sudah Hangus!',
        message: 'Cucian atas nama ${order.customerName} sudah pernah diambil sebelumnya.',
      );
    } else if (order.status != 'siap_diambil') {
      _showScanResultDialog(
        success: false,
        title: 'Cucian Belum Siap!',
        message: 'Pesanan masih berstatus "${order.status.toUpperCase()}". Belum siap diambil.',
      );
    } else {
      // berhasil diverifikasi, ubah status menjadi diambil
      setState(() {
        order.status = 'diambil';
      });
      _showScanResultDialog(
        success: true,
        title: 'Pengambilan Berhasil!',
        message: 'Cucian untuk ${order.customerName} (${order.serviceName} - ${order.weight} kg) berhasil diserahkan!',
      );
    }
  }

  void _showScanResultDialog({required bool success, required String title, required String message}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        icon: Icon(
          success ? Icons.check_circle : Icons.error,
          color: success ? Colors.green : Colors.red,
          size: 48,
        ),
        title: Text(title),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // dialog simulator scanner kamera
  void _openScannerDialog() {
    _qrInputController.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.qr_code_scanner, color: Color(0xFF007BFF)),
                SizedBox(width: 8),
                Text('Scanner QR Pengambilan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Masukkan atau tempel Token QR pengambilan pelanggan:',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _qrInputController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Contoh: 000324',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                prefixIcon: const Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () {
                final token = _qrInputController.text;
                Navigator.pop(ctx);
                _verifyQRPickup(token);
              },
              child: const Text('Verifikasi Pengambilan'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // PERHITUNGAN LAPORAN
    final activeOrders = OrderModel.dummyOrders.where((o) => o.status != 'diambil').length;
    final completedOrders = OrderModel.dummyOrders.where((o) => o.status == 'diambil').length;
    final totalRevenue = OrderModel.dummyOrders
        .where((o) => o.status == 'diambil')
        .fold(0.0, (sum, o) => sum + o.totalPrice);

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
          onPressed: _openScannerDialog,
          backgroundColor: const Color(0xFF007BFF),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.qr_code_scanner),
          label: const Text('Scan QR Pickup'),
        ),
        body: Column(
          children: [
            // KARTU LAPORAN
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Card(
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
                      _buildReportStat('Omzet Selesai', 'Rp ${totalRevenue.toStringAsFixed(0)}', Colors.blue.shade900),
                    ],
                  ),
                ),
              ),
            ),

            // ISI TAB VIEW: PESANAN AKTIF VS RIWAYAT SELESAI dummy only
            Expanded(
              child: TabBarView(
                children: [
                  // cucian Aktif
                  _buildOrderList(
                    OrderModel.dummyOrders.where((o) => o.status != 'diambil').toList(),
                    isActiveList: true,
                  ),
                  // riwayat Selesai
                  _buildOrderList(
                    OrderModel.dummyOrders.where((o) => o.status == 'diambil').toList(),
                    isActiveList: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildOrderList(List<OrderModel> orders, {required bool isActiveList}) {
    if (orders.isEmpty) {
      return const Center(child: Text('Tidak ada pesanan'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final statusColor = _getStatusColor(order.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // baris Atas: Nama & Badge Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.customerName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusColor),
                      ),
                      child: Text(
                        order.status.toUpperCase(),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('${order.serviceName} • ${order.weight} kg • Total: Rp ${order.totalPrice.toStringAsFixed(0)}'),
                Text('Token QR: ${order.pickupToken}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                
                // tombol Update Status
                if (isActiveList) ...[
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (order.status == 'diterima')
                        ElevatedButton.icon(
                          onPressed: () => _advanceOrderStatus(order),
                          icon: const Icon(Icons.waves, size: 16),
                          label: const Text('Mulai Cuci'),
                        ),
                      if (order.status == 'dicuci')
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                          onPressed: () => _advanceOrderStatus(order),
                          icon: const Icon(Icons.check_circle_outline, size: 16),
                          label: const Text('Tandai Siap Diambil'),
                        ),
                      if (order.status == 'siap_diambil')
                        const Text(
                          'Menunggu Scan QR Pelanggan',
                          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.green),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}