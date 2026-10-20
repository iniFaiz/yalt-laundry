class CustomerModel {
  final String id;
  String _name; // private, diubah lewat setter
  String _phone; // private, diubah lewat setter
  final String password;
  final String role; // 'Customer' atau 'Admin'

  CustomerModel({
    required this.id,
    required this._name, // dipanggil dengan nama parameter name
    required this._phone, // dipanggil dengan nama parameter phone
    this.password = 'ayamgoreng',
    this.role = 'Customer',
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

  // validasi nama, return pesan error atau null jika valid
  static String? validateName(String value) {
    if (value.trim().isEmpty) {
      return 'Nama tidak boleh kosong';
    }
    if (value.trim().length < 3) {
      return 'Nama minimal 3 huruf';
    }
    return null;
  }

  // validasi format nomor hp (diawali 08, 10-13 digit angka)
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

  // cek apakah nomor hp sudah dipakai akun lain
  static bool isPhoneRegistered(String phone, {CustomerModel? except}) {
    return dummyCustomers.any((c) => c.phone == phone.trim() && c != except);
  }

  // getter cek role admin
  bool get isAdmin => role == 'Admin';

  // konversi dari map json ke object model
  factory CustomerModel.fromJson(Map<String, dynamic> json) {
    return CustomerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      password: json['password'] as String? ?? 'ayamgoreng',
      role: json['role'] as String? ?? 'Customer',
    );
  }

  // konversi dari object model ke map json
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'password': password,
      'role': role,
    };
  }

  // DAFTAR AKUN YANG TERDAFTAR (BISA LOGIN DENGAN NO HP & PASSWORD 'ayamgoreng')
  static List<CustomerModel> dummyCustomers = [
    CustomerModel(
      id: 'ADM-01',
      name: 'Admin YALT',
      phone: '081111111111',
      password: 'ayamgoreng',
      role: 'Admin',
    ),
    CustomerModel(
      id: 'CUST-01',
      name: 'Prabowo',
      phone: '081234567890',
      password: 'ayamgoreng',
      role: 'Customer',
    ),
    CustomerModel(
      id: 'CUST-02',
      name: 'Jokowi',
      phone: '089876543210',
      password: 'ayamgoreng',
      role: 'Customer',
    ),
  ];
}
