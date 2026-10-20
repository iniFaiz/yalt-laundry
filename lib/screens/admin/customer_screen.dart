import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import '../../models/order_model.dart';

class CustomerScreen extends StatefulWidget {
  const CustomerScreen({super.key});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  bool _isLoading = false;

  // controller untuk form tambah / ubah pelanggan
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  // key form untuk menjalankan validasi input
  final _formKey = GlobalKey<FormState>();

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

  @override
  void dispose() {
    // controller dibersihkan agar tidak memory leak
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // getter daftar akun dengan role pelanggan saja (admin tidak ditampilkan)
  List<CustomerModel> get _customers =>
      CustomerModel.dummyCustomers.where((c) => c.role == 'Customer').toList();

  // hitung jumlah pesanan milik pelanggan berdasarkan nomor hp
  int _countOrders(CustomerModel customer) {
    return OrderModel.dummyOrders.where((o) => o.customerPhone == customer.phone).length;
  }

  // untuk memunculkan Modal Popup Tambah / Ubah Pelanggan
  // customer bernilai null berarti mode tambah, selain itu mode ubah
  void _showCustomerDialog({CustomerModel? customer}) {
    final isEdit = customer != null;
    // nomor hp dikunci jika pelanggan sudah punya pesanan agar riwayat tetap terhubung
    final isPhoneLocked = isEdit && _countOrders(customer) > 0;

    // isi form dengan data lama memakai getter, atau kosongkan untuk data baru
    _nameController.text = customer?.name ?? '';
    _phoneController.text = customer?.phone ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Ubah Data Pelanggan' : 'Tambah Pelanggan Baru'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min, // agar tinggi modal pas dengan isi
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person),
                ),
                // validasi nama memakai fungsi dari model
                validator: (value) => CustomerModel.validateName(value ?? ''),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                enabled: !isPhoneLocked,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Nomor HP / WhatsApp',
                  prefixIcon: const Icon(Icons.phone),
                  hintText: '08...',
                  helperText: isPhoneLocked
                      ? 'Nomor HP terkunci karena sudah ada pesanan'
                      : (isEdit ? null : 'Password default: ayamgoreng'),
                ),
                validator: (value) {
                  final phone = value ?? '';
                  final error = CustomerModel.validatePhone(phone);
                  if (error != null) return error;
                  // cek nomor hp tidak boleh sama dengan akun lain
                  if (CustomerModel.isPhoneRegistered(phone, except: customer)) {
                    return 'Nomor HP sudah terdaftar';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              // hentikan proses jika ada input yang tidak valid
              if (!_formKey.currentState!.validate()) return;

              final name = _nameController.text.trim();
              final phone = _phoneController.text.trim();

              setState(() {
                if (isEdit) {
                  // ubah data lewat setter model
                  customer.name = name;
                  customer.phone = phone;
                } else {
                  // nambah pelanggan baru ke daftar
                  CustomerModel.dummyCustomers.add(
                    CustomerModel(
                      id: 'CUST-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                      name: name,
                      phone: phone,
                    ),
                  );
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: Colors.green,
                  content: Text(isEdit
                      ? 'Data pelanggan $name berhasil diperbarui!'
                      : 'Pelanggan $name berhasil didaftarkan!'),
                ),
              );
            },
            child: const Text('Simpan'),
          ),
        ],
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
        onPressed: () => _showCustomerDialog(),
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
                        onTap: () => _showCustomerDialog(customer: customer),
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
