import '../utils/format_rupiah.dart';

class ServiceModel {
  final String id;
  String _name; // private, diubah lewat setter
  double _pricePerKG; // private, diubah lewat setter
  bool isActive;

  ServiceModel({
    required this.id,
    required this._name, // dipanggil dengan nama parameter name
    required this._pricePerKG, // dipanggil dengan nama parameter pricePerKG
    required this.isActive,
  });

  // getter nama layanan
  String get name => _name;

  // setter nama layanan, tidak boleh kosong
  set name(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError('Nama layanan tidak boleh kosong');
    }
    _name = value.trim();
  }

  // getter tarif per kg
  double get pricePerKG => _pricePerKG;

  // setter tarif per kg, harus lebih dari 0
  // perubahan tarif tidak mengubah pesanan lama karena order menyimpan snapshot harga
  set pricePerKG(double value) {
    if (value <= 0) {
      throw ArgumentError('Tarif per kg harus lebih dari 0');
    }
    _pricePerKG = value;
  }

  // getter format harga per kg
  String get formattedPrice => '${formatRupiah(pricePerKG)} / kg';

  // konversi dari map json ke object model
  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      pricePerKG: (json['pricePerKG'] as num).toDouble(),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  // konversi dari object model ke map json
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'pricePerKG': pricePerKG,
      'isActive': isActive,
    };
  }

  // data dummy layanan, dipakai bersama oleh halaman admin & pelanggan
  static List<ServiceModel> dummyServices = [
    ServiceModel(id: '1', name: 'Cuci Kering', pricePerKG: 6000, isActive: true),
    ServiceModel(id: '2', name: 'Cuci Setrika', pricePerKG: 8000, isActive: true),
    ServiceModel(id: '3', name: 'Setrika Saja', pricePerKG: 5000, isActive: true),
    ServiceModel(id: '4', name: 'Cuci Kilat', pricePerKG: 12000, isActive: true),
  ];
}
