import 'package:flutter/material.dart';
import '../../models/service_model.dart';
import '../../models/order_model.dart';
import '../../models/customer_model.dart';
import '../../utils/format_rupiah.dart';

class OrderEntryScreen extends StatefulWidget {
  const OrderEntryScreen({super.key});

  @override
  State<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends State<OrderEntryScreen> {
  CustomerModel? _selectedCustomer;
  bool _isSubmitting = false; // status loading saat proses simpan asinkron

  final _newCustomerNameController = TextEditingController();
  final _newCustomerPhoneController = TextEditingController();
  final _weightController = TextEditingController();

  // hanya layanan aktif yang bisa dipilih di dropdown
  final List<ServiceModel> _availableServices =
      ServiceModel.dummyServices.where((s) => s.isActive).toList();

  ServiceModel? _selectedService;
  double _weight = 0.0;
  double _totalPrice = 0.0;

  // POPUP REGISTRASI PELANGGAN BARU
  void _showRegisterCustomerDialog() {
    _newCustomerNameController.clear();
    _newCustomerPhoneController.clear();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registrasi Pelanggan Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _newCustomerNameController,
              decoration: const InputDecoration(
                labelText: 'Nama Lengkap',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newCustomerPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor HP / WhatsApp',
                prefixIcon: Icon(Icons.phone),
                hintText: '08...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final name = _newCustomerNameController.text.trim();
              final phone = _newCustomerPhoneController.text.trim();
              if (name.isNotEmpty && phone.isNotEmpty) {
                // 1. Buat pelanggan baru
                final newCust = CustomerModel(
                  id: 'CUST-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                  name: name,
                  phone: phone,
                  password: 'ayamgoreng', // Password default agar mudah demo
                );
                // 2. Simpan ke daftar pelanggan dan otomatis pilih pelanggan tersebut
                setState(() {
                  CustomerModel.dummyCustomers.add(newCust);
                  _selectedCustomer = newCust;
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(backgroundColor: Colors.green, content: Text('Pelanggan $name berhasil didaftarkan!')),
                );
              }
            },
            child: const Text('Daftarkan'),
          ),
        ],
      ),
    );
  }

  // hitung subtotal otomatis 
  void _calculateTotal() {
    setState(() {
      if (_selectedService != null && _weight > 0) {
        _totalPrice = _selectedService!.pricePerKG * _weight;
      } else {
        _totalPrice = 0.0;
      }
    });
  }

  // fungsi simpan transaksi pesanan secara asinkron
  Future<void> _submitOrder() async {
    // validasi form
    if (_selectedCustomer == null || _selectedService == null || _weight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pelanggan, layanan, dan berat cucian!')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // simulasi request penyimpanan data transaksi ke database
    await Future.delayed(const Duration(milliseconds: 600));

    if (!mounted) return;

    // INSTANSIASI DARI INPUT KE ORDERMODEL
    final newOrder = OrderModel(
      id: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      customerName: _selectedCustomer!.name,
      customerPhone: _selectedCustomer!.phone, // Relasi ke nomor HP pelanggan
      serviceName: _selectedService!.name,
      weight: _weight,
      pricePerKgSnapshot: _selectedService!.pricePerKG,
      totalPrice: _totalPrice,
      status: 'diterima',
      pickupToken: 'QR-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
      createdAt: DateTime.now(),
    );

    // SIMPAN KE LIST DUMMY & REFRESH TAMPILAN
    setState(() {
      OrderModel.dummyOrders.insert(0, newOrder); // pesanan baru muncul paling atas
      _isSubmitting = false;
      // reset form input
      _selectedCustomer = null;
      _selectedService = null;
      _weight = 0.0;
      _totalPrice = 0.0;
    });

    _weightController.clear();

    // feedback sukses ke admin
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text('Pesanan untuk "${newOrder.customerName}" berhasil dibuat!'),
      ),
    );
  }

  @override
  void dispose() {
    _newCustomerNameController.dispose();
    _newCustomerPhoneController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // hitung ukuran responsif lebar layar dengan mediaquery
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entri Pesanan Baru (POS)'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // pilih pelanggan terdaftar atau tambah baru
            const Text('Pilih Pelanggan', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<CustomerModel>(
                    isExpanded: true, // teks panjang dipotong agar tidak overflow
                    initialValue: _selectedCustomer,
                    items: CustomerModel.dummyCustomers
                        .where((c) => c.role == 'Customer')
                        .map((cust) {
                      return DropdownMenuItem(
                        value: cust,
                        child: Text('${cust.name} (${cust.phone})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCustomer = val;
                      });
                    },
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
                  onPressed: _showRegisterCustomerDialog,
                  icon: const Icon(Icons.person_add),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // dropdown pilih layanan
            const Text('Pilih Layanan Laundry', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<ServiceModel>(
              isExpanded: true, // teks panjang dipotong agar tidak overflow
              initialValue: _selectedService,
              items: _availableServices.map((service) {
                return DropdownMenuItem(
                  value: service,
                  child: Text('${service.name} (${service.formattedPrice})', overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: (ServiceModel? newService) {
                _selectedService = newService;
                _calculateTotal(); // hitung ulang saat layanan diganti
              },
              decoration: InputDecoration(
                hintText: 'Pilih Layanan',
                prefixIcon: const Icon(Icons.local_laundry_service),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),

            // input berat (Kg)
            const Text('Berat Cucian (Kg)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Contoh: 3.5',
                prefixIcon: const Icon(Icons.scale),
                suffixText: 'Kg',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (value) {
                _weight = double.tryParse(value) ?? 0.0;
                _calculateTotal(); // hitung berat * harga
              },
            ),
            const SizedBox(height: 28),

            // Total Tagihan
            Container(
              width: screenWidth,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Tagihan:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  // FittedBox mengecilkan angka jika nominal terlalu panjang untuk layar
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatRupiah(_totalPrice),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
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

            const Text(
              'Pesanan Terbaru (Hari Ini)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // loop data dummy pesanan
            ListView.builder(
              shrinkWrap: true, // agar tidak overflow di SingleChildScrollView
              physics: const NeverScrollableScrollPhysics(), // agar ListView tidak scroll terpisah
              itemCount: OrderModel.dummyOrders.length,
              itemBuilder: (context, index) {
                final order = OrderModel.dummyOrders[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.local_laundry_service, color: Colors.blue),
                    ),
                    title: Text(
                      order.customerName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${order.serviceName} • ${order.formattedWeight} (${order.status})'),
                    trailing: Text(
                      order.formattedTotalPrice,
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
