import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../repositories/order_repository.dart';

/// Halaman scan QR pengambilan untuk admin.
/// Hasil pop berisi token QR (string) atau null jika dibatalkan.
/// Tersedia input manual sebagai cadangan (misalnya emulator tanpa kamera).
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final TextEditingController _manualController = TextEditingController();
  bool _handled = false; // cegah pop dua kali saat kamera membaca QR beruntun

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null) continue;
      if (!raw.toLowerCase().startsWith(OrderRepository.qrPrefix)) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ini bukan QR pengambilan YALT')),
        );
        return;
      }
      _handled = true;
      Navigator.pop(context, OrderRepository.parseQrToken(raw));
      return;
    }
  }

  void _submitManual() {
    final token = OrderRepository.parseQrToken(_manualController.text);
    if (token.isEmpty) return;
    _handled = true;
    Navigator.pop(context, token);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Pengambilan'),
        actions: [
          IconButton(
            tooltip: 'Lampu kilat',
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: _onDetect,
                    errorBuilder: (context, error) => Container(
                      color: Colors.black87,
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Text(
                        'Kamera tidak dapat dibuka (${error.errorCode.name}).\n'
                        'Izinkan akses kamera, atau masukkan token secara manual di bawah.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  // bingkai bidik
                  IgnorePointer(
                    child: Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.7,
                        heightFactor: 0.7,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 3),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Arahkan kamera ke QR Code pengambilan yang ditunjukkan pelanggan di aplikasinya.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const Divider(height: 32),
          const Text('Input manual', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _manualController,
            decoration: InputDecoration(
              hintText: 'Tempel token QR pelanggan',
              prefixIcon: const Icon(Icons.qr_code),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onSubmitted: (_) => _submitManual(),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _submitManual,
            child: const Text('Verifikasi Pengambilan'),
          ),
        ],
      ),
    );
  }
}
