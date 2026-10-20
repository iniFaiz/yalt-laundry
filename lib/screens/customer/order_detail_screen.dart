import 'package:flutter/material.dart';
import '../../models/order_model.dart';

class OrderDetailScreen extends StatelessWidget {
  final OrderModel order;

  const OrderDetailScreen({super.key, required this.order});

  // menentukan langkah timeline aktif berdasarkan status order
  int _getCurrentStep(String status) {
    switch (status) {
      case 'diterima':
        return 0;
      case 'dicuci':
        return 1;
      case 'siap_diambil':
        return 2;
      case 'diambil':
        return 3;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _getCurrentStep(order.status);

    // menghitung ukuran responsif elemen layar dengan mediaquery
    final screenWidth = MediaQuery.of(context).size.width;
    final qrBoxSize = (screenWidth * 0.48).clamp(160.0, 220.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('Detail ${order.id}'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TIMELINE STATUS TRACKER
            const Text(
              'Status Cucian',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTimeline(currentStep),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // KARTU QR CODE PENGAMBILAN
            Center(
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      const Text(
                        'QR Code Pengambilan',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        // memanfaatkan getter isReadyForPickup dari order model
                        order.isReadyForPickup
                            ? 'Tunjukkan QR ini ke kasir saat mengambil pakaian'
                            : 'QR akan aktif diverifikasi saat cucian siap diambil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: order.isReadyForPickup ? Colors.green : Colors.grey,
                          fontWeight: order.isReadyForPickup ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // QR Image via Image.asset sebagai placeholder offline (tidak butuh internet)
                      Container(
                        width: qrBoxSize,
                        height: qrBoxSize,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Image.asset(
                          'assets/images/qr_placeholder.png',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.qr_code_2, size: 70, color: Colors.blue),
                                const SizedBox(height: 4),
                                Text(
                                  order.pickupToken,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Token: ${order.pickupToken}',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // 3. RINGKASAN STRUK DIGITAL
            const Text(
              'Rincian Biaya & Layanan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildReceiptRow('Nama Pelanggan', order.customerName),
            _buildReceiptRow('Layanan', order.serviceName),
            // menggunakan getter formattedPricePerKg dan formattedWeight
            _buildReceiptRow('Tarif per Kg', order.formattedPricePerKg),
            _buildReceiptRow('Berat Cucian', order.formattedWeight),
            const Divider(height: 24),
            // menggunakan getter formattedTotalPrice
            _buildReceiptRow(
              'Total Bayar',
              order.formattedTotalPrice,
              isBold: true,
              valueColor: const Color(0xFF007BFF),
            ),
          ],
        ),
      ),
    );
  }

  // WIDGET TIMELINE STATUS STEPPER
  Widget _buildTimeline(int currentStep) {
    final steps = ['Diterima', 'Dicuci', 'Siap Diambil', 'Selesai'];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isEven) {
          final stepIndex = index ~/ 2;
          final isCompleted = stepIndex <= currentStep;
          return Column(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: isCompleted ? Colors.blue : Colors.grey.shade300,
                child: Icon(
                  isCompleted ? Icons.check : Icons.circle,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                steps[stepIndex],
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                  color: isCompleted ? Colors.black : Colors.grey,
                ),
              ),
            ],
          );
        } else {
          final stepIndex = index ~/ 2;
          final isLineActive = stepIndex < currentStep;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.only(bottom: 22),
              color: isLineActive ? Colors.blue : Colors.grey.shade300,
            ),
          );
        }
      }),
    );
  }

  Widget _buildReceiptRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: valueColor ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}
