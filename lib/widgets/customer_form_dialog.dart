import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';

/// Membuka dialog form pelanggan yang dipakai bersama oleh tab Pelanggan dan Kasir POS.
/// customer bernilai null berarti mode tambah, selain itu mode ubah.
/// Data disimpan ke Supabase (akun login + profil). Hasil pop berisi pelanggan
/// yang tersimpan di server, atau null jika dibatalkan.
Future<CustomerModel?> showCustomerFormDialog(BuildContext context, {CustomerModel? customer}) {
  return showDialog<CustomerModel>(
    context: context,
    barrierDismissible: false,
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
  final _passwordController = TextEditingController(); // password awal, hanya mode tambah
  bool _obscurePassword = true;

  bool _isSaving = false;
  String? _phoneError; // pesan dari server jika nomor hp sudah dipakai
  String? _errorMessage; // pesan error lain dari server

  // getter cek mode ubah atau tambah
  bool get _isEdit => widget.customer != null;

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
    _passwordController.dispose();
    super.dispose();
  }

  // simpan ke server lalu kirim pelanggan ke halaman pemanggil lewat hasil pop
  Future<void> _save() async {
    _phoneError = null;
    // hentikan proses jika ada input yang tidak valid
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final repository = CustomerRepository.instance;

    try {
      final saved = _isEdit
          ? await repository.updateCustomer(widget.customer!.id, name, phone)
          : await repository.createCustomer(name, phone, _passwordController.text);
      if (!mounted) return;
      Navigator.pop(context, saved);
    } catch (e) {
      debugPrint('Gagal menyimpan pelanggan: $e');
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (CustomerRepository.isPhoneTaken(e)) {
        // tampilkan pesan di bawah kolom nomor hp
        _phoneError = 'Nomor HP sudah terdaftar';
        _formKey.currentState!.validate();
      } else {
        setState(() => _errorMessage = CustomerRepository.errorMessage(e));
      }
    }
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
              enabled: !_isSaving,
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
              enabled: !_isSaving,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'Nomor HP / WhatsApp',
                prefixIcon: const Icon(Icons.phone),
                hintText: '08...',
                helperMaxLines: 2,
                helperText: 'Nomor HP juga dipakai pelanggan untuk login',
              ),
              validator: (value) => CustomerModel.validatePhone(value ?? '') ?? _phoneError,
            ),
            // password awal diisi admin lalu diberikan ke pelanggan; pelanggan bisa menggantinya di tab Profil
            if (!_isEdit) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                enabled: !_isSaving,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password Awal',
                  prefixIcon: const Icon(Icons.lock),
                  helperMaxLines: 2,
                  helperText: 'Berikan ke pelanggan, bisa diganti di menu Profil',
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword ? 'Tampilkan password' : 'Sembunyikan password',
                    icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) => CustomerModel.validatePassword(value ?? ''),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
