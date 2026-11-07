import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order_model.dart';
import 'api_error.dart';

// akses data pesanan ke Supabase, terpisah dari UI.
// Baca data lewat PostgREST (dibatasi RLS), ubah data lewat RPC (fungsi database atomik).
class OrderRepository {
  // instance yang dipakai aplikasi, bisa diganti versi palsu saat tes
  static OrderRepository instance = OrderRepository();

  final SupabaseClient? _injectedClient;

  OrderRepository([this._injectedClient]);

  SupabaseClient get _client => _injectedClient ?? Supabase.instance.client;

  // isi QR pengambilan: awalan agar QR lain tidak dianggap token
  static const String qrPrefix = 'yalt:pickup:';

  static String qrPayload(String token) => '$qrPrefix$token';

  // terima isi QR (dengan awalan) atau token yang diketik manual
  static String parseQrToken(String raw) {
    final text = raw.trim();
    if (text.toLowerCase().startsWith(qrPrefix)) {
      return text.substring(qrPrefix.length).trim();
    }
    return text;
  }

  // kolom pickup_token sengaja tidak diambil (tidak bisa dibaca langsung, lihat migration)
  static const _select = 'id, order_code, customer_id, status, total_amount, notes, '
      'estimated_completion_at, pickup_token_used_at, created_at, '
      'customer:profiles!orders_customer_id_fkey(id, full_name, phone), '
      'order_items(id, service_name_snapshot, weight_kg, price_per_kg_snapshot, subtotal, created_at), '
      'order_status_histories(from_status, to_status, changed_at)';

  // GET /rest/v1/orders?select=...&order=created_at.desc
  // pelanggan otomatis hanya menerima pesanannya sendiri (RLS)
  Future<List<OrderModel>> fetchOrders({String? customerId, int limit = 200}) async {
    var query = _client.from('orders').select(_select);
    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.map(OrderModel.fromJson).toList();
  }

  // GET /rest/v1/orders?id=eq.<id>&select=...
  Future<OrderModel> fetchOrder(String id) async {
    final row = await _client.from('orders').select(_select).eq('id', id).single();
    return OrderModel.fromJson(row);
  }

  // POST /rest/v1/rpc/sp_create_order — pesanan + semua item disimpan dalam satu transaksi
  Future<OrderModel> createOrder({
    required String customerId,
    required List<OrderItemInput> items,
    String? notes,
  }) async {
    final result = await _client.rpc('sp_create_order', params: {
      'p_customer_id': customerId,
      'p_items': items.map((i) => i.toJson()).toList(),
      'p_notes': notes,
    }) as Map<String, dynamic>;
    return fetchOrder(result['id'] as String);
  }

  // POST /rest/v1/rpc/sp_update_order_status — transisi divalidasi di database
  Future<OrderModel> updateStatus(String orderId, String newStatus) async {
    await _client.rpc('sp_update_order_status', params: {'p_order_id': orderId, 'p_new_status': newStatus});
    return fetchOrder(orderId);
  }

  // POST /rest/v1/rpc/sp_get_pickup_token — hanya pemilik pesanan, null jika sudah dipakai
  Future<String?> fetchPickupToken(String orderId) async {
    final result = await _client.rpc('sp_get_pickup_token', params: {'p_order_id': orderId}) as Map<String, dynamic>;
    return result['pickup_token'] as String?;
  }

  // POST /rest/v1/rpc/sp_pickup_order — validasi & pakai token QR secara atomik (row lock)
  Future<OrderModel> pickupByToken(String rawToken) async {
    final result = await _client.rpc('sp_pickup_order', params: {'p_token': parseQrToken(rawToken)})
        as Map<String, dynamic>;
    return fetchOrder(result['id'] as String);
  }

  // Supabase Realtime: panggil onChange setiap ada pesanan yang berubah.
  // Mengembalikan fungsi untuk berhenti berlangganan (dipanggil di dispose).
  void Function() watchOrders(void Function() onChange, {String? customerId}) {
    final channel = _client
        .channel('orders-${customerId ?? 'all'}-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: customerId == null
              ? null
              : PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'customer_id', value: customerId),
          callback: (_) => onChange(),
        )
        .subscribe();
    return () => _client.removeChannel(channel);
  }

  static String errorMessage(Object error) =>
      apiErrorMessage(error, fallback: 'Gagal memproses pesanan. Periksa koneksi internet lalu coba lagi.');
}
