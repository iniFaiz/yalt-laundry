import 'package:my_app/models/customer_model.dart';
import 'package:my_app/models/order_model.dart';
import 'package:my_app/models/service_model.dart';
import 'package:my_app/repositories/auth_repository.dart';
import 'package:my_app/repositories/customer_repository.dart';
import 'package:my_app/repositories/order_repository.dart';
import 'package:my_app/repositories/service_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Backend palsu di memori untuk widget test (tanpa internet).
/// Aturan penting meniru fungsi database: role admin, alur status, dan QR sekali pakai.
class FakeBackend {
  final Map<String, String> passwords = {
    '081111111111': 'ayamgoreng',
    '081234567890': 'ayamgoreng',
    '089876543210': 'ayamgoreng',
  };

  final List<CustomerModel> users = [
    CustomerModel(id: 'ADM-01', name: 'Admin YALT', phone: '081111111111', role: 'Admin'),
    CustomerModel(id: 'CUST-01', name: 'Prabowo', phone: '081234567890'),
    CustomerModel(id: 'CUST-02', name: 'Jokowi', phone: '089876543210'),
  ];

  final List<ServiceModel> services = [
    ServiceModel(id: 'S1', name: 'Cuci Kering', pricePerKG: 6000, isActive: true),
    ServiceModel(id: 'S2', name: 'Cuci Setrika', pricePerKG: 8000, isActive: true),
    ServiceModel(id: 'S3', name: 'Setrika Saja', pricePerKG: 5000, isActive: true, durationHours: 24),
    ServiceModel(id: 'S4', name: 'Cuci Kilat', pricePerKG: 12000, isActive: true, durationHours: 6),
  ];

  late final List<OrderModel> orders = [
    _order('O1', 'ORD-00001', users[1], 'siap_diambil', 'Cuci Setrika', 3, 8000),
    _order('O2', 'ORD-00002', users[2], 'diterima', 'Cuci Kering', 2, 6000),
  ];

  final Map<String, String> tokens = {'O1': 'token-o1', 'O2': 'token-o2'};
  int _seq = 2;

  OrderModel _order(String id, String code, CustomerModel c, String status, String service, double kg, double price,
      {DateTime? usedAt}) {
    final now = DateTime(2026, 11, 7, 9);
    final flow = OrderModel.statusFlow;
    return OrderModel(
      id: id,
      code: code,
      customerId: c.id,
      customerName: c.name,
      customerPhone: c.phone,
      status: status,
      totalPrice: kg * price,
      estimatedCompletionAt: now.add(const Duration(hours: 48)),
      pickupTokenUsedAt: usedAt,
      createdAt: now,
      items: [
        OrderItemModel(id: '$id-1', serviceName: service, weightKg: kg, pricePerKgSnapshot: price, subtotal: kg * price),
      ],
      histories: [
        for (var i = 0; i <= flow.indexOf(status); i++)
          StatusHistoryModel(
            fromStatus: i == 0 ? null : flow[i - 1],
            toStatus: flow[i],
            changedAt: now.add(Duration(hours: i)),
          ),
      ],
    );
  }

  OrderModel copyWithStatus(OrderModel o, String status, {DateTime? usedAt}) {
    return OrderModel(
      id: o.id,
      code: o.code,
      customerId: o.customerId,
      customerName: o.customerName,
      customerPhone: o.customerPhone,
      status: status,
      totalPrice: o.totalPrice,
      estimatedCompletionAt: o.estimatedCompletionAt,
      pickupTokenUsedAt: usedAt ?? o.pickupTokenUsedAt,
      createdAt: o.createdAt,
      items: o.items,
      histories: [...o.histories, StatusHistoryModel(fromStatus: o.status, toStatus: status, changedAt: DateTime.now())],
    );
  }

  String nextCode() => 'ORD-${(++_seq).toString().padLeft(5, '0')}';

  void install() {
    AuthRepository.instance = FakeAuthRepository(this);
    ServiceRepository.instance = FakeServiceRepository(this);
    CustomerRepository.instance = FakeCustomerRepository(this);
    OrderRepository.instance = FakeOrderRepository(this);
  }
}

PostgrestException _error(String code, String message, [String? hint]) =>
    PostgrestException(message: message, code: code, hint: hint);

class FakeAuthRepository extends AuthRepository {
  final FakeBackend db;
  FakeAuthRepository(this.db);

  @override
  Future<CustomerModel> signIn(String phone, String password) async {
    final user = db.users.where((u) => u.phone == phone.trim()).firstOrNull;
    if (user == null || db.passwords[user.phone] != password) {
      throw const AuthFailure('Nomor HP atau password salah');
    }
    return user;
  }

  @override
  Future<void> signOut() async {}

  @override
  Future<void> changePassword(String phone, String oldPassword, String newPassword) async {
    if (db.passwords[phone] != oldPassword) {
      throw const AuthFailure('Password lama salah');
    }
    db.passwords[phone] = newPassword;
  }
}

class FakeServiceRepository extends ServiceRepository {
  final FakeBackend db;
  FakeServiceRepository(this.db);

  @override
  Future<List<ServiceModel>> fetchServices() async => [...db.services];

  @override
  Future<ServiceModel> addService(String name, double pricePerKG, {int durationHours = 48}) async {
    final s = ServiceModel(
      id: 'S${db.services.length + 1}',
      name: name,
      pricePerKG: pricePerKG,
      isActive: true,
      durationHours: durationHours,
    );
    db.services.add(s);
    return s;
  }
}

class FakeCustomerRepository extends CustomerRepository {
  final FakeBackend db;
  FakeCustomerRepository(this.db);

  int _orderCount(String id) => db.orders.where((o) => o.customerId == id).length;

  @override
  Future<List<CustomerModel>> fetchCustomers() async => [
        for (final u in db.users.where((u) => !u.isAdmin))
          CustomerModel(id: u.id, name: u.name, phone: u.phone, orderCount: _orderCount(u.id)),
      ];

  @override
  Future<CustomerModel> createCustomer(String name, String phone, String password) async {
    if (db.users.any((u) => u.phone == phone)) {
      throw _error('23505', 'Nomor HP sudah terdaftar', 'phone_taken');
    }
    final c = CustomerModel(id: 'CUST-${db.users.length}', name: name, phone: phone);
    db.users.add(c);
    db.passwords[phone] = password;
    return c;
  }

  @override
  Future<void> deleteCustomer(String id) async {
    if (_orderCount(id) > 0) {
      throw _error('PT409', 'Pelanggan tidak bisa dihapus karena sudah memiliki riwayat pesanan', 'customer_has_orders');
    }
    db.users.removeWhere((u) => u.id == id);
  }
}

class FakeOrderRepository extends OrderRepository {
  final FakeBackend db;
  FakeOrderRepository(this.db);

  OrderModel _find(String id) => db.orders.firstWhere((o) => o.id == id);

  void _replace(OrderModel o) => db.orders[db.orders.indexWhere((x) => x.id == o.id)] = o;

  @override
  Future<List<OrderModel>> fetchOrders({String? customerId, int limit = 200}) async =>
      db.orders.where((o) => customerId == null || o.customerId == customerId).take(limit).toList();

  @override
  Future<OrderModel> fetchOrder(String id) async => _find(id);

  @override
  Future<OrderModel> createOrder({
    required String customerId,
    required List<OrderItemInput> items,
    String? notes,
  }) async {
    final customer = db.users.firstWhere((u) => u.id == customerId);
    final id = 'O${db.orders.length + 1}';
    final now = DateTime.now();
    final orderItems = [
      for (final (i, input) in items.indexed)
        () {
          final s = db.services.firstWhere((s) => s.id == input.serviceId);
          return OrderItemModel(
            id: '$id-$i',
            serviceName: s.name,
            weightKg: input.weightKg,
            pricePerKgSnapshot: s.pricePerKG,
            subtotal: (input.weightKg * s.pricePerKG).roundToDouble(),
          );
        }(),
    ];
    final order = OrderModel(
      id: id,
      code: db.nextCode(),
      customerId: customer.id,
      customerName: customer.name,
      customerPhone: customer.phone,
      status: 'diterima',
      totalPrice: orderItems.fold(0.0, (sum, i) => sum + i.subtotal),
      estimatedCompletionAt: now.add(const Duration(hours: 48)),
      createdAt: now,
      items: orderItems,
      histories: [StatusHistoryModel(toStatus: 'diterima', changedAt: now)],
    );
    db.orders.insert(0, order);
    db.tokens[id] = 'token-$id';
    return order;
  }

  @override
  Future<OrderModel> updateStatus(String orderId, String newStatus) async {
    final order = _find(orderId);
    if (newStatus == 'diambil' || !OrderModel.isValidTransition(order.status, newStatus)) {
      throw _error('PT409', 'Transisi status ${order.status} -> $newStatus tidak valid', 'invalid_transition');
    }
    final updated = db.copyWithStatus(order, newStatus);
    _replace(updated);
    return updated;
  }

  @override
  Future<String?> fetchPickupToken(String orderId) async =>
      _find(orderId).isCollected ? null : db.tokens[orderId];

  @override
  Future<OrderModel> pickupByToken(String rawToken) async {
    final token = OrderRepository.parseQrToken(rawToken);
    final entry = db.tokens.entries.where((e) => e.value == token).firstOrNull;
    if (entry == null) throw _error('PT404', 'QR tidak dikenali', 'token_not_found');
    final order = _find(entry.key);
    if (order.isCollected) throw _error('PT409', 'QR sudah pernah dipakai', 'token_used');
    if (!order.isReadyForPickup) throw _error('PT409', 'Cucian belum siap diambil', 'not_ready');
    final updated = db.copyWithStatus(order, 'diambil', usedAt: DateTime.now());
    _replace(updated);
    return updated;
  }

  @override
  void Function() watchOrders(void Function() onChange, {String? customerId}) => () {};
}
