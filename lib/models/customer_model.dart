class CustomerModel {
  final String id;
  String _name; // private, diubah lewat setter
  String _phone; // private, diubah lewat setter
  final String role; // 'Customer' atau 'Admin'
  final int orderCount; // jumlah pesanan (dari customer_summary_view)

  CustomerModel({
    required this.id,
    required this._name, // dipanggil dengan nama parameter name
    required this._phone, // dipanggil dengan nama parameter phone
    this.role = 'Customer',
    this.orderCount = 0,
  });

  // getter nama pelanggan
  String get name => _name;

  // setter nama pelanggan, divalidasi dulu sebelum disimpan
  set name(String value) {
    final error = validateName(value);
    if (error != null) {
      throw ArgumentError(error);
    }
    _name = value.trim();
  }

  // getter nomor hp pelanggan
  String get phone => _phone;

  // setter nomor hp pelanggan, divalidasi dulu sebelum disimpan
  set phone(String value) {
    final error = validatePhone(value);
    if (error != null) {
      throw ArgumentError(error);
    }
    _phone = value.trim();
  }

  // validasi password baru, minimal 6 karakter tanpa spasi / whitespace
  static String? validatePassword(String value) {
    if (value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }
    if (RegExp(r'\s').hasMatch(value)) {
      return 'Password tidak boleh mengandung spasi';
    }
    return null;
  }

  // validasi nama, return pesan error atau null jika valid
  static String? validateName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Nama tidak boleh kosong';
    }
    if (trimmed.length < 3) {
      return 'Nama minimal 3 huruf';
    }
    if (trimmed.length > 100) {
      return 'Nama maksimal 100 huruf';
    }
    return null;
  }

  // validasi format nomor hp (diawali 08, 10-13 digit angka), sama dengan constraint database
  static String? validatePhone(String value) {
    final phone = value.trim();
    if (phone.isEmpty) {
      return 'Nomor HP tidak boleh kosong';
    }
    if (!RegExp(r'^08[0-9]{8,11}$').hasMatch(phone)) {
      return 'Nomor HP harus diawali 08 dan berisi 10-13 angka';
    }
    return null;
  }

  // getter cek role admin
  bool get isAdmin => role == 'Admin';

  // konversi dari baris profiles / customer_summary_view / hasil RPC
  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    final role = (json['role'] as String? ?? 'customer').toLowerCase();
    return CustomerModel(
      id: json['id'] as String,
      name: (json['full_name'] ?? json['name']) as String,
      phone: json['phone'] as String,
      role: role == 'admin' ? 'Admin' : 'Customer',
      orderCount: (json['order_count'] as num?)?.toInt() ?? 0,
    );
  }

  // konversi dari object model ke map json sesuai kolom tabel profiles
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': name,
      'phone': phone,
      'role': isAdmin ? 'admin' : 'customer',
    };
  }
}
