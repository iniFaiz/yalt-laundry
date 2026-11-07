import '../utils/format_rupiah.dart';
import '../utils/format_date.dart';

// angka dari PostgREST bisa berupa num atau String (kolom numeric)
double _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

DateTime? _toDate(dynamic value) => value == null ? null : DateTime.parse(value as String).toLocal();

/// Satu baris layanan di dalam pesanan (tabel order_items).
/// Nama & tarif disimpan sebagai snapshot saat pesanan dibuat.
class OrderItemModel {
  final String id;
  final String serviceName;
  final double weightKg;
  final double pricePerKgSnapshot;
  final double subtotal;

  const OrderItemModel({
    required this.id,
    required this.serviceName,
    required this.weightKg,
    required this.pricePerKgSnapshot,
    required this.subtotal,
  });

  String get formattedWeight => formatKg(weightKg);
  String get formattedPricePerKg => '${formatRupiah(pricePerKgSnapshot)} / kg';
  String get formattedSubtotal => formatRupiah(subtotal);

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      serviceName: json['service_name_snapshot'] as String,
      weightKg: _toDouble(json['weight_kg']),
      pricePerKgSnapshot: _toDouble(json['price_per_kg_snapshot']),
      subtotal: _toDouble(json['subtotal']),
    );
  }
}

/// Satu perubahan status (tabel order_status_histories, diisi trigger database).
class StatusHistoryModel {
  final String? fromStatus;
  final String toStatus;
  final DateTime changedAt;

  const StatusHistoryModel({this.fromStatus, required this.toStatus, required this.changedAt});

  factory StatusHistoryModel.fromJson(Map<String, dynamic> json) {
    return StatusHistoryModel(
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String,
      changedAt: _toDate(json['changed_at'])!,
    );
  }
}

/// Input item saat admin membuat pesanan baru.
class OrderItemInput {
  final String serviceId;
  final double weightKg;

  const OrderItemInput({required this.serviceId, required this.weightKg});

  Map<String, dynamic> toJson() => {'service_id': serviceId, 'weight_kg': weightKg};
}

class OrderModel {
  // urutan alur status cucian yang sah (divalidasi juga di database)
  static const List<String> statusFlow = ['diterima', 'dicuci', 'siap_diambil', 'diambil'];

  final String id;
  final String code; // nomor pesanan yang mudah dibaca, contoh ORD-00001
  final String customerId;
  final String customerName;
  final String customerPhone;
  final String status;
  final double totalPrice;
  final String? notes;
  final DateTime estimatedCompletionAt;
  final DateTime? pickupTokenUsedAt;
  final DateTime createdAt;
  final List<OrderItemModel> items;
  final List<StatusHistoryModel> histories;

  const OrderModel({
    required this.id,
    required this.code,
    required this.customerId,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.totalPrice,
    this.notes,
    required this.estimatedCompletionAt,
    this.pickupTokenUsedAt,
    required this.createdAt,
    this.items = const [],
    this.histories = const [],
  });

  // cek apakah perpindahan status from -> to sah (maju tepat satu langkah)
  static bool isValidTransition(String from, String to) {
    final fromIndex = statusFlow.indexOf(from);
    final toIndex = statusFlow.indexOf(to);
    return fromIndex != -1 && toIndex == fromIndex + 1;
  }

  // label status yang mudah dibaca untuk ditampilkan di layar
  static String labelOf(String status) {
    switch (status) {
      case 'diterima':
        return 'Diterima';
      case 'dicuci':
        return 'Sedang Dicuci';
      case 'siap_diambil':
        return 'Siap Diambil';
      case 'diambil':
        return 'Selesai';
      default:
        return status;
    }
  }

  String get statusLabel => labelOf(status);

  // status berikutnya yang boleh diubah admin lewat tombol (diambil hanya lewat scan QR)
  String? get nextAdminStatus {
    switch (status) {
      case 'diterima':
        return 'dicuci';
      case 'dicuci':
        return 'siap_diambil';
      default:
        return null;
    }
  }

  bool get isReadyForPickup => status == 'siap_diambil';
  bool get isCollected => status == 'diambil';
  bool get isActive => !isCollected;

  // ringkasan nama layanan, contoh "Cuci Kering, Cuci Kilat"
  String get serviceName => items.isEmpty ? '-' : items.map((i) => i.serviceName).join(', ');

  // total berat semua item
  double get weight => items.fold(0.0, (sum, i) => sum + i.weightKg);

  String get formattedTotalPrice => formatRupiah(totalPrice);
  String get formattedWeight => formatKg(weight);

  // waktu saat pesanan mencapai status tertentu (dari riwayat), null jika belum
  DateTime? reachedAt(String targetStatus) {
    for (final h in histories) {
      if (h.toStatus == targetStatus) return h.changedAt;
    }
    return null;
  }

  // konversi dari JSON PostgREST (select dengan embed customer, order_items, order_status_histories)
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final items = (json['order_items'] as List<dynamic>? ?? const [])
        .map((e) => OrderItemModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final histories = (json['order_status_histories'] as List<dynamic>? ?? const [])
        .map((e) => StatusHistoryModel.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.changedAt.compareTo(b.changedAt));

    return OrderModel(
      id: json['id'] as String,
      code: json['order_code'] as String,
      customerId: json['customer_id'] as String,
      customerName: customer?['full_name'] as String? ?? '-',
      customerPhone: customer?['phone'] as String? ?? '-',
      status: json['status'] as String,
      totalPrice: _toDouble(json['total_amount']),
      notes: json['notes'] as String?,
      estimatedCompletionAt: _toDate(json['estimated_completion_at'])!,
      pickupTokenUsedAt: _toDate(json['pickup_token_used_at']),
      createdAt: _toDate(json['created_at'])!,
      items: items,
      histories: histories,
    );
  }
}
