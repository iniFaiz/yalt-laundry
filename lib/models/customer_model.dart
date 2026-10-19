class CustomerModel {
  final String id;
  final String name;
  final String phone;
  final String password;
  final String role; // 'Customer' atau 'Admin'

  CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
    this.password = 'ayamgoreng',
    this.role = 'Customer',
  });

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
