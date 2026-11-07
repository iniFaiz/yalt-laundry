import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import '../../repositories/customer_repository.dart';
import '../../widgets/customer_form_dialog.dart';
import '../../widgets/state_views.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final CustomerRepository _repository = CustomerRepository.instance;

  List<CustomerModel> _customers = [];
  bool _isLoading = true;
  String? _errorMessage;

  // inisialisasi awal saat halaman pelanggan dibuka (lifecycle on start)
  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  // ambil daftar pelanggan + jumlah pesanan (GET /rest/v1/customer_summary_view)
  Future<void> _loadCustomers() async {
    try {
      final customers = await _repository.fetchCustomers();
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat pelanggan: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = CustomerRepository.errorMessage(e);
        _isLoading = false;
      });
    }
  }

  void _retry() {
    setState(() => _isLoading = true);
    _loadCustomers();
  }

  // buka dialog form pelanggan bersama (mode tambah jika customer null, selain itu mode ubah)
  Future<void> _openCustomerForm({CustomerModel? customer}) async {
    // tunggu hasil pop dari dialog, berisi pelanggan yang sudah tersimpan di server
    final saved = await showCustomerFormDialog(context, customer: customer);
    if (saved == null || !mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(customer != null
            ? 'Data pelanggan ${saved.name} berhasil diperbarui!'
            : 'Pelanggan ${saved.name} berhasil didaftarkan!'),
      ),
    );
    await _loadCustomers();
  }

  // dialog konfirmasi hapus pelanggan, aturan riwayat pesanan dicek di server
  Future<void> _confirmDelete(CustomerModel customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pelanggan'),
        content: Text(
          'Apakah kamu yakin ingin menghapus ${customer.name}? Akun login pelanggan ini juga akan dihapus.',
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

    try {
      await _repository.deleteCustomer(customer.id);
      if (!mounted) return;
      setState(() => _customers.removeWhere((c) => c.id == customer.id));
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pelanggan ${customer.name} dihapus')));
    } catch (e) {
      debugPrint('Gagal menghapus pelanggan: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.red, content: Text(CustomerRepository.errorMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Pelanggan'),
        centerTitle: true,
      ),
      // tombol mengambang untuk tambah data
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCustomerForm(),
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Pelanggan'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _loadCustomers, child: _buildList()),
    );
  }

  Widget _buildList() {
    if (_errorMessage != null && _customers.isEmpty) {
      return ErrorStateView(message: _errorMessage!, onRetry: _retry);
    }
    if (_customers.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          EmptyStateView(message: 'Belum ada pelanggan terdaftar', icon: Icons.people_outline),
        ],
      );
    }

    // ListView untuk menampilkan kumpulan daftar pelanggan
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88), // ruang bawah untuk tombol mengambang
      itemCount: _customers.length,
      itemBuilder: (context, index) {
        final customer = _customers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            // ketuk kartu untuk ubah data pelanggan
            onTap: () => _openCustomerForm(customer: customer),
            leading: CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                customer.name[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
              ),
            ),
            title: Text(customer.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${customer.phone} • ${customer.orderCount} pesanan'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Hapus Pelanggan',
              onPressed: () => _confirmDelete(customer),
            ),
          ),
        );
      },
    );
  }
}
