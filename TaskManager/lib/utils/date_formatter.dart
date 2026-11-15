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

  // "5 phút trước", "2 giờ trước"...
  static String relative(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    return dateTime(d);
  }
}
