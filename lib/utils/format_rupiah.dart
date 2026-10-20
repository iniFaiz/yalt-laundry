// helper format angka ke rupiah dengan pemisah ribuan, contoh: 24000 -> Rp 24.000
String formatRupiah(double value) {
  final digits = value.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    // sisipkan titik setiap 3 digit dihitung dari belakang
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }
  return 'Rp $buffer';
}
