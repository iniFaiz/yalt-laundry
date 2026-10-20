import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/customer_model.dart';
import 'package:my_app/models/order_model.dart';
import 'package:my_app/models/service_model.dart';
import 'package:my_app/utils/format_rupiah.dart';

// buat order baru dengan status tertentu untuk pengujian
OrderModel _buildOrder(String status) {
  return OrderModel(
    id: 'ORD-TEST',
    customerName: 'Tester',
    customerPhone: '080000000000',
    serviceName: 'Cuci Kering',
    weight: 2.0,
    pricePerKgSnapshot: 6000,
    totalPrice: 12000,
    status: status,
    pickupToken: 'TOKEN-TEST',
    createdAt: DateTime.now(),
  );
}

void main() {
  group('Setter status OrderModel', () {
    test('status maju sesuai alur diterima -> dicuci -> siap_diambil -> diambil', () {
      final order = _buildOrder('diterima');
      order.status = 'dicuci';
      order.status = 'siap_diambil';
      order.status = 'diambil';
      expect(order.status, 'diambil');
      expect(order.isCollected, isTrue);
    });

    test('status tidak boleh melompat atau mundur', () {
      final order = _buildOrder('diterima');
      expect(() => order.status = 'diambil', throwsArgumentError);
      expect(() => order.status = 'diterima', throwsArgumentError);
      expect(() => order.status = 'asal', throwsArgumentError);
      expect(order.status, 'diterima');
    });
  });

  group('Setter ServiceModel', () {
    test('nama dan tarif bisa diubah lewat setter', () {
      final service = ServiceModel(id: 'S1', name: 'Cuci Kering', pricePerKG: 6000, isActive: true);
      service.name = '  Cuci Bedcover  ';
      service.pricePerKG = 15000;
      expect(service.name, 'Cuci Bedcover');
      expect(service.formattedPrice, 'Rp 15.000 / kg');
    });

    test('nama kosong dan tarif <= 0 ditolak', () {
      final service = ServiceModel(id: 'S1', name: 'Cuci Kering', pricePerKG: 6000, isActive: true);
      expect(() => service.name = '   ', throwsArgumentError);
      expect(() => service.pricePerKG = 0, throwsArgumentError);
      expect(service.pricePerKG, 6000);
    });
  });

  group('Setter & validasi CustomerModel', () {
    test('nama dan nomor hp bisa diubah lewat setter', () {
      final customer = CustomerModel(id: 'C1', name: 'Budi', phone: '081200000000');
      customer.name = '  Budi Santoso ';
      customer.phone = '081299999999';
      expect(customer.name, 'Budi Santoso');
      expect(customer.phone, '081299999999');
    });

    test('nama terlalu pendek dan nomor hp salah format ditolak', () {
      final customer = CustomerModel(id: 'C1', name: 'Budi', phone: '081200000000');
      expect(() => customer.name = 'Bu', throwsArgumentError);
      expect(() => customer.phone = '12345', throwsArgumentError);
      expect(() => customer.phone = '08abc1234567', throwsArgumentError);
      expect(customer.phone, '081200000000');
    });

    test('password default bisa diganti lewat setter, password tidak valid ditolak', () {
      final customer = CustomerModel(id: 'C1', name: 'Budi', phone: '081200000000');
      expect(customer.password, 'ayamgoreng');
      customer.password = 'rahasia123';
      expect(customer.password, 'rahasia123');
      expect(() => customer.password = '12345', throwsArgumentError);
      expect(() => customer.password = 'ada spasi', throwsArgumentError);
      expect(customer.password, 'rahasia123');
    });

    test('nomor hp yang sudah dipakai akun lain terdeteksi', () {
      final prabowo = CustomerModel.dummyCustomers.firstWhere((c) => c.phone == '081234567890');
      expect(CustomerModel.isPhoneRegistered('081234567890'), isTrue);
      // nomor milik sendiri tidak dihitung saat mode ubah
      expect(CustomerModel.isPhoneRegistered('081234567890', except: prabowo), isFalse);
      expect(CustomerModel.isPhoneRegistered('089900000000'), isFalse);
    });
  });

  test('formatRupiah memakai pemisah ribuan', () {
    expect(formatRupiah(0), 'Rp 0');
    expect(formatRupiah(500), 'Rp 500');
    expect(formatRupiah(24000), 'Rp 24.000');
    expect(formatRupiah(1250000), 'Rp 1.250.000');
  });
}
