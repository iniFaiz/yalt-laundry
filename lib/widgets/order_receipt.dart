import 'package:flutter/material.dart';

import '../models/order_model.dart';
import '../utils/format_date.dart';
import 'order_status_badge.dart';

/// Ringkasan struk digital pesanan: nomor, pelanggan, rincian item (snapshot tarif), total.
class OrderReceipt extends StatelessWidget {
  final OrderModel order;

  const OrderReceipt({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: Color(0xFF007BFF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(order.code, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              Flexible(child: OrderStatusBadge(status: order.status)),
            ],
          ),
          const SizedBox(height: 4),
          Text(formatDateTime(order.createdAt), style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const Divider(height: 24),
          _row('Pelanggan', order.customerName),
          _row('Nomor HP', order.customerPhone),
          const Divider(height: 24),
          // rincian tiap item: berat x tarif snapshot = subtotal
          for (final item in order.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.serviceName, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '${item.formattedWeight} × ${item.formattedPricePerKg}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(item.formattedSubtotal),
                ],
              ),
            ),
          const Divider(height: 24),
          _row('Total Berat', order.formattedWeight),
          _row('Total Bayar', order.formattedTotalPrice, isBold: true, valueColor: const Color(0xFF007BFF)),
          const SizedBox(height: 8),
          _row(
            order.isCollected ? 'Diambil' : 'Estimasi Selesai',
            formatDayTime(order.pickupTokenUsedAt ?? order.estimatedCompletionAt),
          ),
          if (order.notes != null && order.notes!.isNotEmpty) _row('Catatan', order.notes!),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: TextStyle(color: Colors.grey.shade700))),
          const SizedBox(width: 12),
          // Flexible agar nilai panjang turun ke baris baru, bukan overflow
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
