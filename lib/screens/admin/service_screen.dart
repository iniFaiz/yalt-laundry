import 'package:flutter/material.dart';

import '../../models/service_model.dart';
import '../../repositories/service_repository.dart';

class ServiceScreen extends StatefulWidget {
  const ServiceScreen({super.key});

  @override
  State<ServiceScreen> createState() => _ServiceScreenState();
}

class _ServiceScreenState extends State<ServiceScreen> {
  final ServiceRepository _repository = ServiceRepository.instance;

  // list layanan, isinya diambil dari API
  final List<ServiceModel> _services = [];

  bool _isLoading = true;
  bool _isSaving = false; // true saat menunggu respon simpan dari API
  String? _errorMessage;

  // inisialisasi awal saat halaman layanan dibuka (lifecycle on start)
  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  // ambil data master layanan dari Supabase (GET /rest/v1/services)
  Future<void> _loadServices() async {
    try {
      final services = await _repository.fetchServices();
      if (!mounted) return;
      setState(() {
        _services
          ..clear()
          ..addAll(services);
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat layanan: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Gagal memuat layanan. Periksa koneksi internet lalu coba lagi.';
        _isLoading = false;
      });
    }
  }

  // tombol "Coba Lagi" pada tampilan error
  void _retry() {
    setState(() => _isLoading = true);
    _loadServices();
  }

  // controller untuk dialog tambah layanan
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _durationController = TextEditingController();

  @override
  void dispose() {
    // controller dibersihkan agar tidak memory leak
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  // jalankan request simpan ke API, tampilkan pesan sukses / gagal
  Future<void> _save(
    Future<void> Function() request,
    String successMessage, {
    String Function()? successMessageBuilder,
  }) async {
    setState(() => _isSaving = true);
    String message = successMessage;
    bool success = true;
    try {
      await request();
      if (successMessageBuilder != null) message = successMessageBuilder();
    } catch (e) {
      debugPrint('Gagal menyimpan layanan: $e');
      message = ServiceRepository.errorMessage(e);
      success = false;
    }
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(backgroundColor: success ? Colors.green : Colors.red, content: Text(message)));
  }

  // dialog form nama, tarif & estimasi, hasil pop berisi (nama, tarif, jam) atau null jika batal
  Future<(String, double, int)?> _showServiceDialog({required String title, required String nameLabel}) {
    return showDialog<(String, double, int)>(
      context: context,
      builder: (ctx) => AlertDialog(
        // isi dialog bisa di-scroll agar form tetap terlihat saat keyboard muncul (terutama landscape)
        scrollable: true,
        title: Text(title),
        content: _buildServiceForm(nameLabel),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () {
              final name = _nameController.text.trim();
              final price = double.tryParse(_priceController.text) ?? 0.0;
              final hours = int.tryParse(_durationController.text) ?? 0;

              if (name.isNotEmpty && price > 0 && hours >= 1 && hours <= 720) {
                // kirim isian form ke halaman pemanggil lewat hasil pop
                Navigator.pop(ctx, (name, price, hours));
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  // untuk memunculkan Modal Popup Tambah Layanan, lalu simpan ke Supabase
  Future<void> _showAddServiceDialog() async {
    _nameController.clear();
    _priceController.clear();
    _durationController.text = '48';

    final input = await _showServiceDialog(
      title: 'Tambah Layanan Baru',
      nameLabel: 'Nama Layanan (misal: Cuci Bedcover)',
    );
    if (input == null || !mounted) return;

    await _save(() async {
      final newService = await _repository.addService(input.$1, input.$2, durationHours: input.$3);
      // tambah hasil dari server lalu setState biar ListView terupdate
      setState(() => _services.add(newService));
    }, 'Layanan "${input.$1}" berhasil ditambahkan');
  }

  // untuk memunculkan Modal Popup Edit Nama & Tarif Layanan, lalu simpan ke Supabase
  Future<void> _showEditServiceDialog(ServiceModel service) async {
    // isi form dengan data lama memakai getter
    _nameController.text = service.name;
    _priceController.text = service.pricePerKG.toStringAsFixed(0);
    _durationController.text = service.durationHours.toString();

    final input = await _showServiceDialog(title: 'Ubah Layanan', nameLabel: 'Nama Layanan');
    if (input == null || !mounted) return;

    await _save(() async {
      final updated = await _repository.updateService(
        service.id,
        name: input.$1,
        pricePerKG: input.$2,
        durationHours: input.$3,
      );
      _replaceService(updated);
    }, 'Layanan "${input.$1}" berhasil diubah');
  }

  // aktifkan / nonaktifkan layanan tanpa menghapus data
  Future<void> _toggleActive(ServiceModel service, bool isActive) async {
    await _save(() async {
      final updated = await _repository.updateService(service.id, isActive: isActive);
      _replaceService(updated);
    }, isActive ? 'Layanan "${service.name}" diaktifkan' : 'Layanan "${service.name}" dinonaktifkan');
  }

  // hapus layanan: server menghapus permanen jika belum dipakai, atau menonaktifkan jika sudah dipakai
  Future<void> _confirmDelete(ServiceModel service) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Layanan'),
        content: Text(
          'Hapus "${service.name}"? Jika layanan ini sudah pernah dipakai pesanan, '
          'layanan hanya dinonaktifkan agar riwayat pesanan tetap utuh.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    var message = '';
    await _save(() async {
      final action = await _repository.deleteService(service.id);
      if (action == ServiceDeleteAction.deleted) {
        setState(() => _services.removeWhere((s) => s.id == service.id));
        message = 'Layanan "${service.name}" dihapus';
      } else {
        _replaceService(ServiceModel(
          id: service.id,
          name: service.name,
          pricePerKG: service.pricePerKG,
          durationHours: service.durationHours,
          isActive: false,
        ));
        message = 'Layanan "${service.name}" sudah dipakai pesanan, jadi dinonaktifkan';
      }
    }, '', successMessageBuilder: () => message);
  }

  // ganti data layanan di list dengan hasil terbaru dari server
  void _replaceService(ServiceModel updated) {
    final index = _services.indexWhere((s) => s.id == updated.id);
    if (index == -1) return;
    setState(() => _services[index] = updated);
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
          decoration: const InputDecoration(labelText: 'Tarif per Kg (Rp)', prefixText: 'Rp '),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _durationController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Estimasi Pengerjaan',
            suffixText: 'jam',
            helperText: 'Dipakai menghitung estimasi selesai (1 - 720 jam)',
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
        // garis progres saat data sedang disimpan ke server
        bottom: _isSaving
            ? const PreferredSize(preferredSize: Size.fromHeight(4), child: LinearProgressIndicator())
            : null,
      ),
      // tombol mengambang untuk tambah data
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _showAddServiceDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Layanan'),
      ),
      body: _buildBody(),
    );
  }

  // pilih tampilan sesuai state: loading, error, kosong, atau daftar layanan
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _services.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(onPressed: _retry, icon: const Icon(Icons.refresh), label: const Text('Coba Lagi')),
            ],
          ),
        ),
      );
    }

    // tarik layar ke bawah untuk memuat ulang data dari API
    return RefreshIndicator(
      onRefresh: _loadServices,
      child: _services.isEmpty
          ? ListView(
              // tetap bisa ditarik walau kosong
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 160),
                Icon(Icons.local_laundry_service_outlined, size: 56, color: Colors.grey),
                SizedBox(height: 12),
                Text('Belum ada layanan.', textAlign: TextAlign.center),
              ],
            )
          // ListView untuk menampilkan kumpulan daftar layanan
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              // ruang bawah agar kartu terakhir tidak tertutup tombol tambah
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final service = _services[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    // ketuk kartu untuk ubah nama & tarif layanan
                    onTap: _isSaving ? null : () => _showEditServiceDialog(service),
                    leading: CircleAvatar(child: Text('${index + 1}')),
                    title: Text(
                      service.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        decoration: service.isActive ? null : TextDecoration.lineThrough,
                      ),
                    ),
                    // menggunakan getter formattedPrice dari model
                    subtitle: Text(
                      '${service.formattedPrice} • ±${service.formattedDuration}'
                      '${service.isActive ? '' : ' • Nonaktif'}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: service.isActive,
                          // ubah status aktif/nonaktif layanan tanpa menghapus data
                          onChanged: _isSaving ? null : (bool val) => _toggleActive(service, val),
                        ),
                        IconButton(
                          tooltip: 'Hapus Layanan',
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: _isSaving ? null : () => _confirmDelete(service),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
