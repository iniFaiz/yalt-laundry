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