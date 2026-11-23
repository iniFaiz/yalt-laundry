import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/service_model.dart';
import '../../repositories/service_repository.dart';
import '../../widgets/state_views.dart';

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

  // dialog form nama, tarif & estimasi dengan validasi jelas
  Future<(String, double, int)?> _showServiceDialog({
    required String title,
    required String nameLabel,
    ServiceModel? initial,
  }) {
    return showDialog<(String, double, int)>(
      context: context,
      builder: (ctx) => _ServiceFormDialog(
        title: title,
        nameLabel: nameLabel,
        initial: initial,
      ),
    );
  }

  // untuk memunculkan Modal Popup Tambah Layanan, lalu simpan ke Supabase
  Future<void> _showAddServiceDialog() async {
    final input = await _showServiceDialog(
      title: 'Tambah Layanan Baru',
      nameLabel: 'Nama Layanan (misal: Cuci Bedcover)',
    );
    if (input == null || !mounted) return;

    await _save(() async {
      final newService = await _repository.addService(input.$1, input.$2, durationHours: input.$3);
      if (!mounted) return;
      // tambah hasil dari server lalu urutkan abjad sesuai urutan query
      setState(() {
        _services.add(newService);
        _services.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });
    }, 'Layanan "${input.$1}" berhasil ditambahkan');
  }

  // untuk memunculkan Modal Popup Edit Nama & Tarif Layanan, lalu simpan ke Supabase
  Future<void> _showEditServiceDialog(ServiceModel service) async {
    final input = await _showServiceDialog(
      title: 'Ubah Layanan',
      nameLabel: 'Nama Layanan',
      initial: service,
    );
    if (input == null || !mounted) return;

    await _save(() async {
      final updated = await _repository.updateService(
        service.id,
        name: input.$1,
        pricePerKG: input.$2,
        durationHours: input.$3,
      );
      if (!mounted) return;
      _replaceService(updated);
    }, 'Layanan "${input.$1}" berhasil diubah');
  }

  // aktifkan / nonaktifkan layanan tanpa menghapus data
  Future<void> _toggleActive(ServiceModel service, bool isActive) async {
    await _save(() async {
      final updated = await _repository.updateService(service.id, isActive: isActive);
      if (!mounted) return;
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
      if (!mounted) return;
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
    setState(() {
      _services[index] = updated;
      _services.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    });
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
      return RefreshIndicator(
        onRefresh: _loadServices,
        child: ErrorStateView(message: _errorMessage!, onRetry: _retry),
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
                EmptyStateView(message: 'Belum ada layanan.', icon: Icons.local_laundry_service_outlined),
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

/// Dialog form tambah / ubah layanan dengan validasi per kolom.
class _ServiceFormDialog extends StatefulWidget {
  final String title;
  final String nameLabel;
  final ServiceModel? initial;

  const _ServiceFormDialog({
    required this.title,
    required this.nameLabel,
    this.initial,
  });

  @override
  State<_ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends State<_ServiceFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _priceController = TextEditingController(
      text: widget.initial != null ? widget.initial!.pricePerKG.toStringAsFixed(0) : '',
    );
    _durationController = TextEditingController(
      text: (widget.initial?.durationHours ?? 48).toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  double? _parsePrice(String raw) {
    final cleaned = raw.trim().replaceAll('.', '').replaceAll(',', '');
    return double.tryParse(cleaned);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final price = _parsePrice(_priceController.text)!;
    final hours = int.parse(_durationController.text.trim());
    Navigator.pop(context, (name, price, hours));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              maxLength: 100,
              decoration: InputDecoration(labelText: widget.nameLabel, counterText: ''),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Nama layanan tidak boleh kosong';
                if (text.length > 100) return 'Nama layanan maksimal 100 huruf';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'Tarif per Kg (Rp)', prefixText: 'Rp '),
              validator: (value) {
                final price = _parsePrice(value ?? '');
                if (price == null || price <= 0) return 'Tarif per kg harus lebih dari 0';
                if (price > 10000000) return 'Tarif per kg terlalu besar';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _durationController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Estimasi Pengerjaan',
                suffixText: 'jam',
                helperText: 'Dipakai menghitung estimasi selesai (1 - 720 jam)',
              ),
              validator: (value) {
                final hours = int.tryParse((value ?? '').trim());
                if (hours == null || hours < 1 || hours > 720) {
                  return 'Estimasi harus antara 1 sampai 720 jam';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
        ElevatedButton(onPressed: _submit, child: const Text('Simpan')),
      ],
    );
  }
}
