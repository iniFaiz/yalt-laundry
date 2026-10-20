import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import '../../models/order_model.dart';

/// Halaman profil pelanggan, ditampilkan sebagai tab ketiga di beranda pelanggan.
/// Berisi data akun dan form ganti password.
class ProfileScreen extends StatefulWidget {
  final CustomerModel customer;

  const ProfileScreen({super.key, required this.customer});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // key form untuk menjalankan validasi input
  final _formKey = GlobalKey<FormState>();

  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // status sembunyikan teks tiap kolom password
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isSaving = false; // status loading saat proses simpan asinkron

  @override
  void dispose() {
    // controller dibersihkan agar tidak memory leak
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // fungsi simpan password baru secara asinkron
  Future<void> _changePassword() async {
    // tutup keyboard lalu hentikan proses jika ada input yang tidak valid
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    // simulasi request penyimpanan password ke server
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() {
      // ubah password lewat setter model
      widget.customer.password = _newPasswordController.text;
      _isSaving = false;
    });

    // kosongkan semua kolom form setelah berhasil
    _formKey.currentState!.reset();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.green,
        content: Text('Password berhasil diubah. Gunakan password baru saat login berikutnya.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;
    // hitung jumlah pesanan milik pelanggan berdasarkan nomor hp
    final orderCount = OrderModel.dummyOrders.where((o) => o.customerPhone == customer.phone).length;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // KARTU DATA AKUN
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF007BFF).withValues(alpha: 0.12),
                child: Text(
                  customer.name[0].toUpperCase(),
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF007BFF)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                customer.name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text('Pelanggan', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const Divider(height: 28),
              _buildInfoRow(Icons.badge_outlined, 'ID Pelanggan', customer.id),
              _buildInfoRow(Icons.phone_outlined, 'Nomor HP', customer.phone),
              _buildInfoRow(Icons.receipt_long_outlined, 'Jumlah Pesanan', '$orderCount pesanan'),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // FORM GANTI PASSWORD
        const Text(
          'Ganti Password',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPasswordField(
                  controller: _oldPasswordController,
                  label: 'Password Lama',
                  obscure: _obscureOld,
                  onToggle: () => setState(() => _obscureOld = !_obscureOld),
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Password lama tidak boleh kosong';
                    // cocokkan dengan password akun memakai getter
                    if (value != customer.password) return 'Password lama salah';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _newPasswordController,
                  label: 'Password Baru',
                  helperText: 'Minimal 6 karakter, tanpa spasi',
                  obscure: _obscureNew,
                  onToggle: () => setState(() => _obscureNew = !_obscureNew),
                  validator: (value) {
                    // validasi format memakai fungsi dari model
                    final error = CustomerModel.validatePassword(value ?? '');
                    if (error != null) return error;
                    if (value == _oldPasswordController.text) {
                      return 'Password baru harus berbeda dari password lama';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildPasswordField(
                  controller: _confirmPasswordController,
                  label: 'Konfirmasi Password Baru',
                  obscure: _obscureConfirm,
                  onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  validator: (value) {
                    if (value != _newPasswordController.text) return 'Konfirmasi password tidak sama';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _changePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007BFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.lock_reset),
                    label: Text(_isSaving ? 'Menyimpan...' : 'Simpan Password Baru'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // baris info akun: ikon, label di kiri, nilai di kanan
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade600),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(width: 12),
          // Expanded agar nilai panjang dipotong, bukan overflow
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // kolom password dengan tombol tampilkan / sembunyikan
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required FormFieldValidator<String> validator,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: const Icon(Icons.lock_outline),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          tooltip: obscure ? 'Tampilkan Password' : 'Sembunyikan Password',
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }
}
