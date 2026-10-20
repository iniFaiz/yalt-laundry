import 'package:flutter/material.dart';
import '../../models/service_model.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  // ambil data dummy layanan yang dipakai bersama
  final List<ServiceModel> _services = ServiceModel.dummyServices;

  bool _isLoading = false;

  // inisialisasi awal saat halaman layanan dibuka (lifecycle on start)
  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  // simulasi memuat data master layanan secara asinkron
  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

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
  Future<void> _showAddServiceDialog() async {
    _nameController.clear();
    _priceController.clear();

    // tunggu hasil pop dari dialog, berisi layanan baru atau null jika batal
    final newService = await showDialog<ServiceModel>(
      context: context,
      builder: (ctx) => AlertDialog(
        // isi dialog bisa di-scroll agar form tetap terlihat saat keyboard muncul (terutama landscape)
        scrollable: true,
        title: const Text('Tambah Layanan Baru'),
        content: _buildServiceForm('Nama Layanan (misal: Cuci Bedcover)'),
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
                // kirim data layanan baru ke halaman pemanggil lewat hasil pop
                Navigator.pop(
                  ctx,
                  ServiceModel(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: name,
                    pricePerKG: price,
                    isActive: true,
                  ),
                );
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    // nambah data baru lalu panggil setState biar ListView terupdate
    if (newService != null && mounted) {
      setState(() {
        _services.add(newService);
      });
    }
  }

  // untuk memunculkan Modal Popup Edit Nama & Tarif Layanan
  void _showEditServiceDialog(ServiceModel service) {
    // isi form dengan data lama memakai getter
    _nameController.text = service.name;
    _priceController.text = service.pricePerKG.toStringAsFixed(0);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        // isi dialog bisa di-scroll agar form tetap terlihat saat keyboard muncul (terutama landscape)
        scrollable: true,
        title: const Text('Ubah Layanan'),
        content: _buildServiceForm('Nama Layanan'),
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
                // ubah data lewat setter model, lalu setState biar ListView terupdate
                setState(() {
                  service.name = name;
                  service.pricePerKG = price;
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

  // form isian nama & tarif yang dipakai dialog tambah dan edit
  Widget _buildServiceForm(String nameLabel) {
    return Column(
      mainAxisSize: MainAxisSize.min, // agar tinggi modal pas dengan isi
      children: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: nameLabel),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final service = _services[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    // ketuk kartu untuk ubah nama & tarif layanan
                    onTap: () => _showEditServiceDialog(service),
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
                    // menggunakan getter formattedPrice dari model
                    subtitle: Text(service.formattedPrice),
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
