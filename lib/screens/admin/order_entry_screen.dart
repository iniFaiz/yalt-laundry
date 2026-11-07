import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import '../../models/order_model.dart';
import '../../models/service_model.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/service_repository.dart';
import '../../utils/format_rupiah.dart';
import '../../widgets/customer_form_dialog.dart';
import '../../widgets/order_receipt.dart';
import '../../widgets/order_status_badge.dart';
import '../../widgets/state_views.dart';
import '../customer/order_detail_screen.dart';

// satu baris input item: layanan + berat
class _ItemRow {
  String? serviceId;
  final TextEditingController weightController = TextEditingController();

  double get weight => double.tryParse(weightController.text.trim().replaceAll(',', '.')) ?? 0.0;
}

class OrderEntryScreen extends StatefulWidget {
  const OrderEntryScreen({super.key});

  @override
  State<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends State<OrderEntryScreen> {
  List<CustomerModel> _customers = [];
  List<ServiceModel> _services = []; // hanya layanan aktif
  List<OrderModel> _recentOrders = [];

  bool _isLoading = true;
  String? _loadError;
  bool _isSubmitting = false; // status loading saat proses simpan asinkron

  String? _selectedCustomerId;
  final List<_ItemRow> _items = [_ItemRow()];
  final _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.weightController.dispose();
    }
    _notesController.dispose();
    super.dispose();
  }

  // ambil pelanggan, layanan aktif, dan pesanan terbaru dari Supabase secara paralel
  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        CustomerRepository.instance.fetchCustomers(),
        ServiceRepository.instance.fetchServices(),
        OrderRepository.instance.fetchOrders(limit: 10),
      ]);
      if (!mounted) return;
      setState(() {
        _customers = results[0] as List<CustomerModel>;
        _services = (results[1] as List<ServiceModel>).where((s) => s.isActive).toList();
        _recentOrders = results[2] as List<OrderModel>;
        // layanan yang sudah dinonaktifkan tidak bisa dipilih lagi
        for (final item in _items) {
          if (!_services.any((s) => s.id == item.serviceId)) item.serviceId = null;
        }
        _loadError = null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat data kasir: $e');
      if (!mounted) return;
      setState(() {
        _loadError = OrderRepository.errorMessage(e);
        _isLoading = false;
      });
    }
  }

  ServiceModel? _serviceById(String? id) => _services.where((s) => s.id == id).firstOrNull;

  // perkiraan total di layar; total resmi dihitung ulang oleh database (fn_item_total)
  double get _totalPrice => _items.fold(0.0, (sum, item) {
        final service = _serviceById(item.serviceId);
        if (service == null || item.weight <= 0) return sum;
        return sum + (service.pricePerKG * item.weight).roundToDouble();
      });

  // POPUP REGISTRASI PELANGGAN BARU, memakai dialog form yang sama dengan tab Pelanggan
  Future<void> _showRegisterCustomerDialog() async {
    // tunggu hasil pop dari dialog, berisi pelanggan baru yang sudah tersimpan di server
    final newCust = await showCustomerFormDialog(context);
    if (newCust == null || !mounted) return;

    // otomatis pilih pelanggan yang baru didaftarkan di dropdown
    setState(() {
      _customers = [..._customers, newCust]..sort((a, b) => a.name.compareTo(b.name));
      _selectedCustomerId = newCust.id;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.green, content: Text('Pelanggan ${newCust.name} berhasil didaftarkan!')),
    );
  }

  void _addItemRow() => setState(() => _items.add(_ItemRow()));

  void _removeItemRow(int index) {
    setState(() {
      _items.removeAt(index).weightController.dispose();
    });
  }

  // validasi form di aplikasi, lalu dikirim ke RPC sp_create_order (validasi ulang di database)
  String? _validateForm() {
    if (_selectedCustomerId == null) return 'Pilih pelanggan terlebih dahulu';
    for (var i = 0; i < _items.length; i++) {
      final label = _items.length > 1 ? ' pada item ${i + 1}' : '';
      if (_items[i].serviceId == null) return 'Pilih layanan$label';
      final weight = _items[i].weight;
      if (weight <= 0) return 'Isi berat cucian$label';
      if (weight > 100) return 'Berat cucian maksimal 100 kg$label';
    }
    return null;
  }

  // fungsi simpan transaksi pesanan ke Supabase
  Future<void> _submitOrder() async {
    FocusScope.of(context).unfocus();
    final error = _validateForm();
    if (error != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    setState(() => _isSubmitting = true);

    OrderModel order;
    try {
      order = await OrderRepository.instance.createOrder(
        customerId: _selectedCustomerId!,
        items: _items.map((i) => OrderItemInput(serviceId: i.serviceId!, weightKg: i.weight)).toList(),
        notes: _notesController.text,
      );
    } catch (e) {
      debugPrint('Gagal membuat pesanan: $e');
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(OrderRepository.errorMessage(e))),
      );
      return;
    }
    if (!mounted) return;

    // reset form input, pesanan baru muncul paling atas
    setState(() {
      _isSubmitting = false;
      _selectedCustomerId = null;
      for (final item in _items) {
        item.weightController.dispose();
      }
      _items
        ..clear()
        ..add(_ItemRow());
      _recentOrders = [order, ..._recentOrders.take(9)];
    });
    _notesController.clear();

    // feedback sukses ke admin, snackbar sebelumnya ditutup dulu agar tidak antre
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text('Pesanan untuk "${order.customerName}" berhasil dibuat!'),
      ),
    );
    await _showReceiptDialog(order);
  }

  // struk digital setelah pesanan tersimpan
  Future<void> _showReceiptDialog(OrderModel order) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const Text('Bukti Pesanan'),
        contentPadding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
        content: OrderReceipt(order: order),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entri Pesanan Baru (POS)'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _loadError != null && _services.isEmpty
                  ? ErrorStateView(
                      message: _loadError!,
                      onRetry: () {
                        setState(() => _isLoading = true);
                        _loadData();
                      },
                    )
                  : _buildForm(),
            ),
    );
  }

  Widget _buildForm() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      children: [
        // pilih pelanggan terdaftar atau tambah baru
        const Text('Pilih Pelanggan', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                // key berubah saat pelanggan terpilih berubah, agar dropdown ikut menampilkan
                // pelanggan baru dari registrasi dan kosong lagi setelah pesanan disimpan
                key: ValueKey('customer-$_selectedCustomerId-${_customers.length}'),
                isExpanded: true, // teks panjang dipotong agar tidak overflow
                initialValue: _selectedCustomerId,
                items: _customers.map((cust) {
                  return DropdownMenuItem(
                    value: cust.id,
                    child: Text('${cust.name} (${cust.phone})', overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedCustomerId = val),
                decoration: InputDecoration(
                  hintText: '-- Pilih Pelanggan --',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Registrasi Pelanggan Baru',
              onPressed: _isSubmitting ? null : _showRegisterCustomerDialog,
              icon: const Icon(Icons.person_add),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // daftar item: layanan + berat
        Row(
          children: [
            const Expanded(child: Text('Layanan & Berat Cucian', style: TextStyle(fontWeight: FontWeight.bold))),
            TextButton.icon(
              onPressed: _isSubmitting || _items.length >= 20 ? null : _addItemRow,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Layanan'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        if (_services.isEmpty)
          const Text('Belum ada layanan aktif. Tambahkan di tab Layanan.', style: TextStyle(color: Colors.red)),
        for (var i = 0; i < _items.length; i++) _buildItemRow(i),

        const SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLength: 200,
          decoration: InputDecoration(
            labelText: 'Catatan (opsional)',
            prefixIcon: const Icon(Icons.notes),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),

        // Total Tagihan
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Tagihan:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              // FittedBox mengecilkan angka jika nominal terlalu panjang untuk layar
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    formatRupiah(_totalPrice),
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Tombol Simpan Pesanan
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isSubmitting ? null : _submitOrder,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            icon: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.receipt_long),
            label: Text(
              _isSubmitting ? 'Menyimpan Pesanan...' : 'Buat Pesanan & Cetak Bukti',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),

        const SizedBox(height: 30),
        const Divider(),
        const SizedBox(height: 10),
        const Text('Pesanan Terbaru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (_recentOrders.isEmpty)
          const EmptyStateView(message: 'Belum ada pesanan', icon: Icons.receipt_long_outlined)
        else
          for (final order in _recentOrders)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order, isAdmin: true)),
                ),
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: const Icon(Icons.local_laundry_service, color: Colors.blue),
                ),
                title: Text(
                  '${order.code} • ${order.customerName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OrderStatusBadge(status: order.status),
                      Text('${order.serviceName} • ${order.formattedWeight}'),
                    ],
                  ),
                ),
                trailing: Text(
                  order.formattedTotalPrice,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ),
            ),
      ],
    );
  }

  // satu baris item: dropdown layanan + input berat + tombol hapus
  Widget _buildItemRow(int index) {
    final item = _items[index];
    final service = _serviceById(item.serviceId);
    final subtotal = service != null && item.weight > 0 ? (service.pricePerKG * item.weight).roundToDouble() : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    // key berubah agar dropdown kosong lagi setelah pesanan disimpan
                    key: ValueKey('service-${identityHashCode(item)}-${item.serviceId}'),
                    isExpanded: true, // teks panjang dipotong agar tidak overflow
                    initialValue: item.serviceId,
                    items: _services.map((s) {
                      return DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.name} (${s.formattedPrice})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => item.serviceId = val),
                    decoration: InputDecoration(
                      hintText: 'Pilih Layanan',
                      prefixIcon: const Icon(Icons.local_laundry_service),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                if (_items.length > 1)
                  IconButton(
                    tooltip: 'Hapus item',
                    onPressed: _isSubmitting ? null : () => _removeItemRow(index),
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: item.weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Contoh: 3.5',
                      prefixIcon: const Icon(Icons.scale),
                      suffixText: 'Kg',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    // koma juga diterima karena keyboard indonesia memakai koma desimal (3,5)
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 96,
                  child: Text(
                    formatRupiah(subtotal),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
