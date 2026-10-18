import 'package:flutter/material.dart';
import '../../models/service_model.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  // data dummy awal
  final List<ServiceModel> _services = [
    ServiceModel(id: '1', name: 'Cuci Kering', pricePerKG: 6000, isActive: true),
    ServiceModel(id: '2', name: 'Cuci Setrika', pricePerKG: 8000, isActive: true),
    ServiceModel(id: '3', name: 'Setrika Saja', pricePerKG: 5000, isActive: true),
  ];

  // controller untuk dialog tambah layanan
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();

  @override
  void dispose() {
    // controller dibersihkan agar tidak memory leak
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // untuk memunculkan Modal Popup Tambah Layanan
  void _showAddServiceDialog() {
    _nameController.clear();
    _priceController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tambah Layanan Baru'),
        content: Column(
          mainAxisSize: MainAxisSize.min, // agar tinggi modal pas dengan isi
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nama Layanan (misal: Cuci Bedcover)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Tarif per Kg (Rp)',
                prefixText: 'Rp ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              final price = double.tryParse(_priceController.text) ?? 0.0;

              if (name.isNotEmpty && price > 0) {
                // nambah data baru lalu panggil setState biar ListView terupdate
                setState(() {
                  _services.add(
                    ServiceModel(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: name,
                      pricePerKG: price,
                      isActive: true,
                    ),
                  );
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Master Layanan & Tarif'),
        centerTitle: true,
      ),
      // tombol mengambang untuk tambah data
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddServiceDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Layanan'),
      ),
      // ListView untuk menampilkan kumpulan daftar layanan
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _services.length,
        itemBuilder: (context, index) {
          final service = _services[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                child: Text('${index + 1}'),
              ),
              title: Text(
                service.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  decoration: service.isActive ? null : TextDecoration.lineThrough,
                ),
              ),
              subtitle: Text('Rp ${service.pricePerKG.toStringAsFixed(0)} / kg'),
              trailing: Switch(
                value: service.isActive,
                onChanged: (bool val) {
                  // ubah status aktif/nonaktif layanan tanpa menghapus data
                  setState(() {
                    service.isActive = val;
                  });
                },
              ),
            ),
          );
        },
      ),
    );
  }
}