class ServiceModel {
  final String id;
  String name;
  double pricePerKG;
  bool isActive;

  ServiceModel({
    required this.id,
    required this.name,
    required this.pricePerKG,
    required this.isActive,
  });

  // getter format harga per kg
  String get formattedPrice => 'Rp ${pricePerKG.toStringAsFixed(0)} / kg';

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
}
