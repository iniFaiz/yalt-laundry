import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/order_model.dart';
import '../../repositories/order_repository.dart';
import '../../utils/format_date.dart';
import '../../widgets/order_receipt.dart';
import '../../widgets/order_status_badge.dart';

/// Detail pesanan: timeline status beranimasi, QR pengambilan (pelanggan), dan struk digital.
/// Data dimuat ulang dari server saat halaman dibuka, saat ditarik, dan saat pesanan berubah (Realtime).
class OrderDetailScreen extends StatefulWidget {
  final OrderModel order; // data awal dari daftar, langsung diperbarui dari server
  final bool isAdmin; // admin tidak melihat QR (token hanya untuk pelanggan)

  const OrderDetailScreen({super.key, required this.order, this.isAdmin = false});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> with SingleTickerProviderStateMixin {
  final OrderRepository _repository = OrderRepository.instance;

  late OrderModel _order = widget.order;
  String? _pickupToken;
  String? _errorMessage;
  bool _isRefreshing = false;
  void Function()? _unsubscribe;

  // animasi timeline: tiap langkah muncul bergantian
  late final AnimationController _timelineController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    _timelineController.forward();
    _refresh();
    if (!widget.isAdmin) {
      // status berubah di server (admin update / scan QR) -> muat ulang otomatis
      _unsubscribe = _repository.watchOrders(_refresh, customerId: _order.customerId);
    }
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    _timelineController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final order = await _repository.fetchOrder(_order.id);
      String? token;
      // token QR hanya diminta pelanggan pemilik pesanan saat cucian siap diambil
      if (!widget.isAdmin && order.isReadyForPickup) {
        token = await _repository.fetchPickupToken(order.id);
      }
      if (!mounted) return;
      final statusChanged = order.status != _order.status;
      setState(() {
        _order = order;
        _pickupToken = token;
        _errorMessage = null;
      });
      // ulangi animasi timeline jika status berubah
      if (statusChanged) _timelineController.forward(from: 0);
    } catch (e) {
      debugPrint('Gagal memuat detail pesanan: $e');
      if (mounted) setState(() => _errorMessage = OrderRepository.errorMessage(e));
    } finally {
      _isRefreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        // tombol kembali ke halaman sebelumnya pakai pop
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Kembali',
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Detail ${_order.code}'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_off, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(child: Text('$_errorMessage Tarik layar untuk mencoba lagi.')),
                  ],
                ),
              ),

            // TIMELINE STATUS TRACKER
            Row(
              children: [
                const Expanded(
                  child: Text('Status Cucian', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                OrderStatusBadge(status: _order.status),
              ],
            ),
            const SizedBox(height: 12),
            _buildTimeline(),
            const SizedBox(height: 20),

            // KARTU QR CODE PENGAMBILAN (khusus pelanggan)
            if (!widget.isAdmin) ...[
              _buildQrCard(),
              const SizedBox(height: 20),
            ],

            // RINGKASAN STRUK DIGITAL
            const Text('Rincian Biaya & Layanan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            OrderReceipt(order: _order),
          ],
        ),
      ),
    );
  }

  // WIDGET TIMELINE STATUS VERTIKAL BERANIMASI
  Widget _buildTimeline() {
    final steps = OrderModel.statusFlow;
    final currentStep = steps.indexOf(_order.status);
    const descriptions = {
      'diterima': 'Cucian diterima kasir dan ditimbang',
      'dicuci': 'Cucian sedang dicuci dan dikeringkan',
      'siap_diambil': 'Cucian siap, tunjukkan QR di outlet',
      'diambil': 'Cucian sudah diambil. Terima kasih!',
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: List.generate(steps.length, (i) {
          final status = steps[i];
          final isDone = i <= currentStep;
          final isCurrent = i == currentStep;
          final style = OrderStatusStyle.of(status);
          final reachedAt = _order.reachedAt(status);
          final timeText = reachedAt != null
              ? formatDayTime(reachedAt)
              : status == 'siap_diambil'
                  ? 'Estimasi: ${formatDayTime(_order.estimatedCompletionAt)}'
                  : 'Belum';

          // tiap langkah punya jendela animasi sendiri (berurutan)
          final animation = CurvedAnimation(
            parent: _timelineController,
            curve: Interval(i / steps.length, (i + 1) / steps.length, curve: Curves.easeOutBack),
          );
          final lineAnimation = CurvedAnimation(
            parent: _timelineController,
            curve: Interval((i + 0.5) / steps.length, (i + 1) / steps.length, curve: Curves.easeOut),
          );

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 40,
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: animation,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDone ? style.foreground : Colors.grey.shade200,
                            border: isCurrent
                                ? Border.all(color: style.foreground.withValues(alpha: 0.3), width: 4)
                                : null,
                          ),
                          child: Icon(
                            isDone ? style.icon : Icons.circle_outlined,
                            size: 18,
                            color: isDone ? Colors.white : Colors.grey,
                          ),
                        ),
                      ),
                      if (i < steps.length - 1)
                        Expanded(
                          child: Container(
                            width: 3,
                            margin: const EdgeInsets.symmetric(vertical: 2),
                            color: Colors.grey.shade200,
                            // garis terisi warna (beranimasi dari atas) jika langkah berikutnya sudah tercapai.
                            // CustomPaint dipakai karena tidak menambah tinggi intrinsik baris timeline.
                            child: i < currentStep ? CustomPaint(painter: _TimelineLinePainter(lineAnimation)) : null,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FadeTransition(
                    opacity: animation.drive(Tween(begin: 0.0, end: 1.0)),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 18, top: 2),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            OrderModel.labelOf(status),
                            style: TextStyle(
                              fontWeight: isDone ? FontWeight.bold : FontWeight.normal,
                              color: isDone ? Colors.black87 : Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            descriptions[status]!,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                          Text(
                            timeText,
                            style: TextStyle(
                              fontSize: 12,
                              color: reachedAt != null ? const Color(0xFF007BFF) : Colors.grey,
                              fontWeight: reachedAt != null ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  // QR pengambilan: aktif hanya saat siap diambil, hangus setelah dipakai
  Widget _buildQrCard() {
    final screenWidth = MediaQuery.of(context).size.width;
    final qrBoxSize = (screenWidth * 0.55).clamp(160.0, 240.0);
    final token = _pickupToken;
    final isActive = _order.isReadyForPickup && token != null;

    final String message;
    if (_order.isCollected) {
      message = 'QR sudah digunakan pada ${formatDayTime(_order.pickupTokenUsedAt!)}';
    } else if (_order.isReadyForPickup) {
      message = token == null ? 'Memuat QR...' : 'Tunjukkan QR ini ke kasir saat mengambil pakaian';
    } else {
      message = 'QR akan aktif saat cucian siap diambil';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isActive ? const Color(0xFF00796B) : Colors.grey.shade200, width: isActive ? 2 : 1),
      ),
      child: Column(
        children: [
          const Text('QR Code Pengambilan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: isActive ? const Color(0xFF00796B) : Colors.grey,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: isActive
                ? QrImageView(
                    key: const ValueKey('qr-active'),
                    data: OrderRepository.qrPayload(token),
                    size: qrBoxSize,
                    backgroundColor: Colors.white,
                    semanticsLabel: 'QR pengambilan ${_order.code}',
                  )
                : Container(
                    key: const ValueKey('qr-locked'),
                    width: qrBoxSize,
                    height: qrBoxSize,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _order.isCollected ? Icons.task_alt : Icons.lock_clock_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                  ),
          ),
          if (isActive) ...[
            const SizedBox(height: 8),
            // token lengkap bisa disalin, untuk input manual jika kamera kasir bermasalah
            SelectableText(
              token,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.grey, fontFamily: 'monospace'),
            ),
          ],
        ],
      ),
    );
  }
}

// menggambar garis penghubung timeline yang terisi dari atas sesuai progres animasi
class _TimelineLinePainter extends CustomPainter {
  final Animation<double> progress;

  _TimelineLinePainter(this.progress) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final height = size.height * progress.value.clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, height), Paint()..color = Colors.blue);
  }

  @override
  bool shouldRepaint(_TimelineLinePainter oldDelegate) => oldDelegate.progress != progress;
}
