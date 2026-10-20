import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import '../../models/order_model.dart';
import '../../widgets/customer_form_dialog.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  bool _isLoading = false;

  // inisialisasi awal saat halaman pelanggan dibuka (lifecycle on start)
  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  // simulasi memuat data pelanggan secara asinkron
  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // getter daftar akun dengan role pelanggan saja (admin tidak ditampilkan)
  List<CustomerModel> get _customers =>
      CustomerModel.dummyCustomers.where((c) => c.role == 'Customer').toList();

  // hitung jumlah pesanan milik pelanggan berdasarkan nomor hp
  int _countOrders(CustomerModel customer) {
    return OrderModel.dummyOrders.where((o) => o.customerPhone == customer.phone).length;
  }

  // buka dialog form pelanggan bersama (mode tambah jika customer null, selain itu mode ubah)
  Future<void> _openCustomerForm({CustomerModel? customer}) async {
    // tunggu hasil pop dari dialog, berisi pelanggan yang disimpan atau null jika batal
    final saved = await showCustomerFormDialog(context, customer: customer);
    if (saved == null || !mounted) return;

    // panggil setState biar ListView terupdate
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.green,
        content: Text(customer != null
            ? 'Data pelanggan ${saved.name} berhasil diperbarui!'
            : 'Pelanggan ${saved.name} berhasil didaftarkan!'),
      ),
    );
  }

  // dialog konfirmasi hapus pelanggan
  void _confirmDelete(CustomerModel customer) {
    // pelanggan yang sudah punya pesanan tidak boleh dihapus agar riwayat tetap ada
    if (_countOrders(customer) > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${customer.name} tidak bisa dihapus karena sudah memiliki riwayat pesanan.'),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pelanggan'),
        content: Text('Apakah kamu yakin ingin menghapus ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              // hapus data lalu setState biar ListView terupdate
              setState(() {
                CustomerModel.dummyCustomers.remove(customer);
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Pelanggan ${customer.name} dihapus')),
              );
            },
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customers = _customers;

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
          : customers.isEmpty
              ? const Center(child: Text('Belum ada pelanggan terdaftar'))
              // ListView untuk menampilkan kumpulan daftar pelanggan
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88), // ruang bawah untuk tombol mengambang
                  itemCount: customers.length,
                  itemBuilder: (context, index) {
                    final customer = customers[index];
                    final orderCount = _countOrders(customer);
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
                        title: Text(
                          customer.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${customer.phone} • $orderCount pesanan'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          tooltip: 'Hapus Pelanggan',
                          onPressed: () => _confirmDelete(customer),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
