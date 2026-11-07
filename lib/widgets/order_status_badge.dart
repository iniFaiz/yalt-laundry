import 'package:flutter/material.dart';

import '../models/order_model.dart';

/// Warna & ikon tiap status. Status selalu ditampilkan dengan teks + ikon,
/// tidak hanya warna, agar tetap jelas bagi pengguna buta warna.
class OrderStatusStyle {
  final Color background;
  final Color foreground;
  final IconData icon;

  const OrderStatusStyle(this.background, this.foreground, this.icon);

  static OrderStatusStyle of(String status) {
    switch (status) {
      case 'diterima':
        return const OrderStatusStyle(Color(0xFFE3F2FD), Color(0xFF1565C0), Icons.inventory_2_outlined);
      case 'dicuci':
        return const OrderStatusStyle(Color(0xFFFFF3E0), Color(0xFFE65100), Icons.local_laundry_service_outlined);
      case 'siap_diambil':
        return const OrderStatusStyle(Color(0xFFE0F2F1), Color(0xFF00796B), Icons.shopping_bag_outlined);
      case 'diambil':
        return const OrderStatusStyle(Color(0xFFF1F5F9), Color(0xFF475569), Icons.task_alt);
      default:
        return const OrderStatusStyle(Color(0xFFF5F5F5), Colors.black54, Icons.help_outline);
    }
  }
}

class OrderStatusBadge extends StatelessWidget {
  final String status;

  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final style = OrderStatusStyle.of(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: style.foreground.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 14, color: style.foreground),
          const SizedBox(width: 4),
          // Flexible agar label tidak overflow di layar sempit / ukuran font besar
          Flexible(
            child: Text(
              OrderModel.labelOf(status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: style.foreground),
            ),
          ),
        ],
      ),
    );
  }
}
