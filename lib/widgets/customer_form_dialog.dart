import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../models/order_model.dart';

/// Membuka dialog form pelanggan yang dipakai bersama oleh tab Pelanggan dan Kasir POS.
/// customer bernilai null berarti mode tambah, selain itu mode ubah.
/// Hasil pop berisi pelanggan yang disimpan, atau null jika dibatalkan.
Future<CustomerModel?> showCustomerFormDialog(BuildContext context, {CustomerModel? customer}) {
  return showDialog<CustomerModel>(
    context: context,
    builder: (ctx) => CustomerFormDialog(customer: customer),
  );
}

class CustomerFormDialog extends StatefulWidget {
  final CustomerModel? customer;

  const CustomerFormDialog({super.key, this.customer});

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  // key form untuk menjalankan validasi input
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  // getter cek mode ubah atau tambah
  bool get _isEdit => widget.customer != null;

  // nomor hp dikunci jika pelanggan sudah punya pesanan agar riwayat tetap terhubung
  bool get _isPhoneLocked =>
      _isEdit && OrderModel.dummyOrders.any((o) => o.customerPhone == widget.customer!.phone);

  // inisialisasi form dengan data lama memakai getter, atau kosong untuk data baru
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.customer?.name ?? '');
    _phoneController = TextEditingController(text: widget.customer?.phone ?? '');
  }

  @override
  void dispose() {
    // controller dibersihkan agar tidak memory leak
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // simpan data lalu kirim pelanggan ke halaman pemanggil lewat hasil pop
  void _save() {
    // hentikan proses jika ada input yang tidak valid
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    CustomerModel saved;
    if (_isEdit) {
      // ubah data lewat setter model
      saved = widget.customer!;
      saved.name = name;
      saved.phone = phone;
    } else {
      // buat pelanggan baru dan simpan ke daftar pelanggan
      saved = CustomerModel(
        id: 'CUST-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
        name: name,
        phone: phone,
      );
      CustomerModel.dummyCustomers.add(saved);
    }
    Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // isi dialog bisa di-scroll agar form tetap terlihat saat keyboard muncul (terutama landscape)
      scrollable: true,
      title: Text(_isEdit ? 'Ubah Data Pelanggan' : 'Registrasi Pelanggan Baru'),
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
              enabled: !_isPhoneLocked,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Nomor HP / WhatsApp',
                prefixIcon: const Icon(Icons.phone),
                hintText: '08...',
                helperText: _isPhoneLocked
                    ? 'Nomor HP terkunci karena sudah ada pesanan'
                    : (_isEdit ? null : 'Password default: ayamgoreng'),
              ),
              validator: (value) {
                final phone = value ?? '';
                final error = CustomerModel.validatePhone(phone);
                if (error != null) return error;
                // cek nomor hp tidak boleh sama dengan akun lain
                if (CustomerModel.isPhoneRegistered(phone, except: widget.customer)) {
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
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
