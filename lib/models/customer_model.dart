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