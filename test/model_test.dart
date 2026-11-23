import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/customer_model.dart';
import 'package:my_app/models/order_model.dart';
import 'package:my_app/models/service_model.dart';
import 'package:my_app/repositories/order_repository.dart';
import 'package:my_app/utils/format_date.dart';
import 'package:my_app/utils/format_rupiah.dart';

// contoh JSON hasil GET /rest/v1/orders?select=...,customer:profiles(...),order_items(...),order_status_histories(...)
Map<String, dynamic> _orderJson({String status = 'dicuci'}) => {
      'id': '11111111-1111-4111-8111-111111111111',
      'order_code': 'ORD-00007',
      'customer_id': '00000000-0000-4000-a000-000000000002',
      'status': status,
      'total_amount': 27000,
      'notes': null,
      'estimated_completion_at': '2026-11-09T06:00:00+00:00',
      'pickup_token_used_at': status == 'diambil' ? '2026-11-09T07:00:00+00:00' : null,
      'created_at': '2026-11-07T06:00:00+00:00',
      'customer': {'id': '00000000-0000-4000-a000-000000000002', 'full_name': 'Prabowo', 'phone': '081234567890'},
      'order_items': [
        {
          'id': 'a',
          'service_name_snapshot': 'Cuci Kering',
          'weight_kg': 2.5,
          'price_per_kg_snapshot': 6000,
          'subtotal': 15000,
        },
        {
          'id': 'b',
          'service_name_snapshot': 'Cuci Kilat',
          'weight_kg': '1.00', // kolom numeric bisa datang sebagai string
          'price_per_kg_snapshot': '12000.00',
          'subtotal': '12000.00',
        },
      ],
      'order_status_histories': [
        {'from_status': 'diterima', 'to_status': 'dicuci', 'changed_at': '2026-11-07T08:00:00+00:00'},
        {'from_status': null, 'to_status': 'diterima', 'changed_at': '2026-11-07T06:00:00+00:00'},
      ],
    };

void main() {
  group('OrderModel', () {
    test('fromJson membaca pesanan, item, dan riwayat dari PostgREST', () {
      final order = OrderModel.fromJson(_orderJson());
      expect(order.code, 'ORD-00007');
      expect(order.customerName, 'Prabowo');
      expect(order.items, hasLength(2));
      expect(order.weight, 3.5);
      expect(order.serviceName, 'Cuci Kering, Cuci Kilat');
      expect(order.formattedTotalPrice, 'Rp 27.000');
      expect(order.formattedWeight, '3,5 kg');
      // riwayat diurutkan dari yang paling lama
      expect(order.histories.first.toStatus, 'diterima');
      expect(order.reachedAt('dicuci'), isNotNull);
      expect(order.reachedAt('siap_diambil'), isNull);
    });

    test('alur status hanya boleh maju satu langkah', () {
      expect(OrderModel.isValidTransition('diterima', 'dicuci'), isTrue);
      expect(OrderModel.isValidTransition('dicuci', 'siap_diambil'), isTrue);
      expect(OrderModel.isValidTransition('siap_diambil', 'diambil'), isTrue);
      expect(OrderModel.isValidTransition('diterima', 'diambil'), isFalse);
      expect(OrderModel.isValidTransition('dicuci', 'diterima'), isFalse);
      expect(OrderModel.isValidTransition('asal', 'dicuci'), isFalse);
    });

    test('tombol admin tidak pernah menawarkan status diambil (wajib scan QR)', () {
      expect(OrderModel.fromJson(_orderJson(status: 'diterima')).nextAdminStatus, 'dicuci');
      expect(OrderModel.fromJson(_orderJson(status: 'dicuci')).nextAdminStatus, 'siap_diambil');
      expect(OrderModel.fromJson(_orderJson(status: 'siap_diambil')).nextAdminStatus, isNull);
      final collected = OrderModel.fromJson(_orderJson(status: 'diambil'));
      expect(collected.nextAdminStatus, isNull);
      expect(collected.isCollected, isTrue);
      expect(collected.statusLabel, 'Selesai');
    });
  });

  group('QR pengambilan', () {
    test('isi QR memakai awalan dan bisa diurai kembali menjadi token', () {
      const token = '0123456789abcdef0123456789abcdef';
      final payload = OrderRepository.qrPayload(token);
      expect(payload, 'yalt:pickup:$token');
      expect(OrderRepository.parseQrToken(payload), token);
      expect(OrderRepository.parseQrToken('  $token  '), token);
      expect(OrderRepository.parseQrToken('YALT:PICKUP:$token'), token);
    });
  });

  group('Setter ServiceModel', () {
    test('nama, tarif, dan estimasi bisa diubah lewat setter', () {
      final service = ServiceModel(id: 'S1', name: 'Cuci Kering', pricePerKG: 6000, isActive: true);
      service.name = '  Cuci Bedcover  ';
      service.pricePerKG = 15000;
      service.durationHours = 72;
      expect(service.name, 'Cuci Bedcover');
      expect(service.formattedPrice, 'Rp 15.000 / kg');
      expect(service.formattedDuration, '3 hari');
    });

    test('nama kosong, tarif <= 0, dan estimasi di luar 1-720 jam ditolak', () {
      final service = ServiceModel(id: 'S1', name: 'Cuci Kering', pricePerKG: 6000, isActive: true);
      expect(() => service.name = '   ', throwsArgumentError);
      expect(() => service.pricePerKG = 0, throwsArgumentError);
      expect(() => service.durationHours = 0, throwsArgumentError);
      expect(() => service.durationHours = 721, throwsArgumentError);
      expect(service.pricePerKG, 6000);
      expect(service.formattedDuration, '2 hari');
    });

    test('fromJson membaca kolom duration_hours dan harga berbentuk string', () {
      final service = ServiceModel.fromJson(
        {'id': 'x', 'name': 'Cuci Kilat', 'price_per_kg': '12000.00', 'is_active': true, 'duration_hours': 6},
      );
      expect(service.pricePerKG, 12000);
      expect(service.formattedDuration, '6 jam');
      expect(() => service.name = 'a' * 101, throwsArgumentError);
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

    test('validasi password minimal 6 karakter tanpa spasi atau whitespace', () {
      expect(CustomerModel.validatePassword('rahasia123'), isNull);
      expect(CustomerModel.validatePassword('12345'), isNotNull);
      expect(CustomerModel.validatePassword('ada spasi'), isNotNull);
      expect(CustomerModel.validatePassword('ada\ttab'), isNotNull);
      expect(CustomerModel.validateName('a' * 101), isNotNull);
    });

    test('fromJson membaca baris profiles / customer_summary_view', () {
      final admin = CustomerModel.fromJson({'id': 'a', 'full_name': 'Admin YALT', 'phone': '081111111111', 'role': 'admin'});
      final customer = CustomerModel.fromJson({'id': 'c', 'full_name': 'Jokowi', 'phone': '089876543210', 'order_count': 3});
      expect(admin.isAdmin, isTrue);
      expect(customer.isAdmin, isFalse);
      expect(customer.orderCount, 3);
    });
  });

  test('formatRupiah memakai pemisah ribuan dan aman untuk angka negatif', () {
    expect(formatRupiah(0), 'Rp 0');
    expect(formatRupiah(500), 'Rp 500');
    expect(formatRupiah(24000), 'Rp 24.000');
    expect(formatRupiah(1250000), 'Rp 1.250.000');
    expect(formatRupiah(-100), '-Rp 100');
    expect(formatRupiah(-12500), '-Rp 12.500');
  });

  test('formatKg memakai koma desimal', () {
    expect(formatKg(2), '2 kg');
    expect(formatKg(2.5), '2,5 kg');
    expect(formatKg(1.25), '1,25 kg');
  });
}
