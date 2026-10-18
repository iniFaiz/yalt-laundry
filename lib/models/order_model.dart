class OrderModel {
  final String id;
  final String customerName;
  final String serviceName;
  final double weight;
  final double pricePerKgSnapshot;
  final double totalPrice;
  final String status; // 'diterima', 'dicuci', 'siap_diambil', 'diambil'
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.customerName,
    required this.serviceName,
    required this.weight,
    required this.pricePerKgSnapshot,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
  });

  // DATA DUMMY
  static List<OrderModel> dummyOrders = [
    OrderModel(
      id: 'ORD-001',
      customerName: 'Budi Santoso',
      serviceName: 'Cuci Setrika',
      weight: 3.0,
      pricePerKgSnapshot: 8000,
      totalPrice: 24000,
      status: 'dicuci',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    OrderModel(
      id: 'ORD-002',
      customerName: 'Siti Rahma',
      serviceName: 'Cuci Kering',
      weight: 2.0,
      pricePerKgSnapshot: 6000,
      totalPrice: 12000,
      status: 'diterima',
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
  ];
}