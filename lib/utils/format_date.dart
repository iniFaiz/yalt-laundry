// helper format tanggal & berat dalam bahasa Indonesia tanpa paket tambahan

const List<String> _days = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
const List<String> _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String _twoDigits(int n) => n.toString().padLeft(2, '0');

// contoh: 7 Nov 2026, 14:05
String formatDateTime(DateTime value) {
  final d = value.toLocal();
  return '${d.day} ${_months[d.month - 1]} ${d.year}, ${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
}

// contoh: Sabtu, 7 Nov • 14:05
String formatDayTime(DateTime value) {
  final d = value.toLocal();
  return '${_days[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} • ${_twoDigits(d.hour)}:${_twoDigits(d.minute)}';
}

// contoh: 2 kg, 2,5 kg, 1,25 kg (desimal memakai koma)
String formatKg(double value) {
  var text = value.toStringAsFixed(2);
  text = text.replaceFirst(RegExp(r'\.?0+$'), '');
  return '${text.replaceAll('.', ',')} kg';
}
