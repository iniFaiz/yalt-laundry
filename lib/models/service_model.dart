import '../utils/format_rupiah.dart';

class ServiceModel {
  final String id;
  String _name; // private, diubah lewat setter
  double _pricePerKG; // private, diubah lewat setter
  int _durationHours; // private, estimasi lama pengerjaan (jam)
  bool isActive;

  ServiceModel({
    required this.id,
    required this._name, // dipanggil dengan nama parameter name
    required this._pricePerKG, // dipanggil dengan nama parameter pricePerKG
    required this.isActive,
    this._durationHours = 48, // dipanggil dengan nama parameter durationHours
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

  // getter estimasi lama pengerjaan
  int get durationHours => _durationHours;

  // setter estimasi lama pengerjaan, 1 jam - 30 hari (sama dengan constraint database)
  set durationHours(int value) {
    if (value < 1 || value > 720) {
      throw ArgumentError('Estimasi pengerjaan harus 1 - 720 jam');
    }
    _durationHours = value;
  }

  // getter format harga per kg
  String get formattedPrice => '${formatRupiah(pricePerKG)} / kg';

  // getter format estimasi, contoh "6 jam" atau "2 hari"
  String get formattedDuration =>
      durationHours % 24 == 0 ? '${durationHours ~/ 24} hari' : '$durationHours jam';

  // konversi dari baris json tabel services (Supabase) ke object model
  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      pricePerKG: (json['price_per_kg'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      durationHours: (json['duration_hours'] as num?)?.toInt() ?? 48,
    );
  }

  // konversi dari object model ke map json sesuai kolom tabel services
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price_per_kg': pricePerKG,
      'is_active': isActive,
      'duration_hours': durationHours,
    };
  }
}
