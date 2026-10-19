class OrderModel {
  final String id;
  final String customerName;
  final String customerPhone;
  final String serviceName;
  final double weight;
  final double pricePerKgSnapshot;
  final double totalPrice;
  String status; // 'diterima', 'dicuci', 'siap_diambil', 'diambil'
  final String pickupToken; // unique token qr
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.serviceName,
    required this.weight,
    required this.pricePerKgSnapshot,
    required this.totalPrice,
    required this.status,
    required this.pickupToken,
    required this.createdAt,
  });

  // getter format rupiah total harga
  String get formattedTotalPrice => 'Rp ${totalPrice.toStringAsFixed(0)}';

  // getter format berat cucian
  String get formattedWeight => '${weight.toStringAsFixed(1)} kg';

  // getter format tarif snapshot per kg
  String get formattedPricePerKg => 'Rp ${pricePerKgSnapshot.toStringAsFixed(0)} / kg';

  // getter cek apakah cucian siap diambil
  bool get isReadyForPickup => status == 'siap_diambil';

  // getter cek apakah cucian sudah selesai diambil
  bool get isCollected => status == 'diambil';

  // konversi dari map json ke object model
  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      customerName: json['customerName'] as String,
      customerPhone: json['customerPhone'] as String,
      serviceName: json['serviceName'] as String,
      weight: (json['weight'] as num).toDouble(),
      pricePerKgSnapshot: (json['pricePerKgSnapshot'] as num).toDouble(),
      totalPrice: (json['totalPrice'] as num).toDouble(),
      status: json['status'] as String,
      pickupToken: json['pickupToken'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  // konversi dari object model ke map json
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'serviceName': serviceName,
      'weight': weight,
      'pricePerKgSnapshot': pricePerKgSnapshot,
      'totalPrice': totalPrice,
      'status': status,
      'pickupToken': pickupToken,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // data dummy
  static List<OrderModel> dummyOrders = [
    OrderModel(
      id: 'ORD-001',
      customerName: 'Prabowo',
      customerPhone: '081234567890',
      serviceName: 'Cuci Setrika',
      weight: 3.0,
      pricePerKgSnapshot: 8000,
      totalPrice: 24000,
      status: 'dicuci',
      pickupToken: '000324',
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    OrderModel(
      id: 'ORD-002',
      customerName: 'Jokowi',
      customerPhone: '089876543210',
      serviceName: 'Cuci Kering',
      weight: 2.0,
      pricePerKgSnapshot: 6000,
      totalPrice: 12000,
      status: 'siap_diambil',
      pickupToken: '000234',
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
  ];
}
