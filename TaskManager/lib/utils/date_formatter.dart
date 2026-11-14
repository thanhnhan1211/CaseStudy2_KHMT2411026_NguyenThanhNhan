class DateFormatter {
  static String _two(int n) => n.toString().padLeft(2, '0');

  // 05/12/2026
  static String date(DateTime? d) {
    if (d == null) return 'Chưa đặt';
    return '${_two(d.day)}/${_two(d.month)}/${d.year}';
  }

  // 05/12/2026 14:30
  static String dateTime(DateTime? d) {
    if (d == null) return '';
    return '${date(d)} ${_two(d.hour)}:${_two(d.minute)}';
  }
}
