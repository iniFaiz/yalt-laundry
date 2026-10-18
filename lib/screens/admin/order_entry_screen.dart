import 'package:flutter/material.dart';
import '../../models/service_model.dart';
import '../../models/order_model.dart';

class OrderEntryScreen extends StatefulWidget {
  const OrderEntryScreen({super.key});

  @override
  State<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends State<OrderEntryScreen> {
  final _customerController = TextEditingController();
  final _weightController = TextEditingController();

  // data dummy daftar layanan yang tersedia untuk dipilih di dropdown
  final List<ServiceModel> _availableServices = [
    ServiceModel(id: '1', name: 'Cuci Kering', pricePerKG: 6000, isActive: true),
    ServiceModel(id: '2', name: 'Cuci Setrika', pricePerKG: 8000, isActive: true),
    ServiceModel(id: '3', name: 'Setrika Saja', pricePerKG: 5000, isActive: true),
  ];

  ServiceModel? _selectedService;
  double _weight = 0.0;
  double _totalPrice = 0.0;

  @override
  void dispose() {
    _customerController.dispose();
    _weightController.dispose();
    super.dispose();
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

void _submitOrder() {
  final customer = _customerController.text.trim();
  // validasi
  if (customer.isEmpty || _selectedService == null || _weight <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('lengkapi nama, layanan, dan berat cucian.')),
    );
    return;
  }
  // INSTANSIASI DARI INPUT KE ORDERMODEL
  final newOrder = OrderModel(
    id: 'ORD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}', // ID unik singkat
    customerName: customer,
    serviceName: _selectedService!.name,
    weight: _weight,
    pricePerKgSnapshot: _selectedService!.pricePerKG, // Simpan snapshot harga
    totalPrice: _totalPrice,
    status: 'diterima', // Status awal sesuai SOP laundry
    createdAt: DateTime.now(),
  );
  // SIMPAN KE LIST DUMMY & REFRESH TAMPILAN
  setState(() {
    OrderModel.dummyOrders.insert(0, newOrder); // insert(0, ...) agar pesanan baru muncul paling atas
  });
  // reset Form
  _customerController.clear();
  _weightController.clear();
  setState(() {
    _weight = 0.0;
    _totalPrice = 0.0;
    _selectedService = null;
  });
  // feedback sukses ke admin
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.green,
      content: Text('Pesanan untuk "${newOrder.customerName}" berhasil dibuat'),
    ),
  );
}
  @override
  Widget build(BuildContext context) {
    // responsive width
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
            // input Nama Pelanggan
            const Text('Nama Pelanggan', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: _customerController,
              decoration: InputDecoration(
                hintText: 'Masukkan nama pelanggan...',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 20),

            // dropdown Pilih Layanan
            const Text('Pilih Layanan Laundry', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<ServiceModel>(
              initialValue: _selectedService,
              items: _availableServices.map((service) {
                return DropdownMenuItem(
                  value: service,
                  child: Text('${service.name} (Rp ${service.pricePerKG.toStringAsFixed(0)}/kg)'),
                );
              }).toList(),
              onChanged: (ServiceModel? newService) {
                _selectedService = newService;
                _calculateTotal(); // Hitung ulang saat layanan diganti
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
                _calculateTotal(); // calculate berat * harga
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
                  Text(
                    'Rp ${_totalPrice.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
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
                onPressed: _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Buat Pesanan & Cetak Bukti', style: TextStyle(fontSize: 16)),
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
              shrinkWrap: true, //agar tidak overflow di SingleChildScrollView
              physics: const NeverScrollableScrollPhysics(), // agar ListView tidak bisa discroll sendiri
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
                    subtitle: Text('${order.serviceName} • ${order.weight} kg (${order.status})'),
                    trailing: Text(
                      'Rp ${order.totalPrice.toStringAsFixed(0)}',
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