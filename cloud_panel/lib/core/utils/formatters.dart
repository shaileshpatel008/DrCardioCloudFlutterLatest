import 'package:intl/intl.dart';

class Fmt {
  Fmt._();

  static final _number = NumberFormat.decimalPattern('en_IN');
  static final _date = DateFormat('d MMM yyyy');
  static final _time = DateFormat('hh:mm a');
  static final _dateTime = DateFormat('d MMM yyyy, hh:mm a');
  static final _dayLong = DateFormat('EEEE, d MMMM yyyy');

  static String number(num? v) => v == null ? '—' : _number.format(v);
  static String date(DateTime? d) => d == null ? '—' : _date.format(d);
  static String time(DateTime? d) => d == null ? '' : _time.format(d);
  static String dateTime(DateTime? d) => d == null ? '—' : _dateTime.format(d);
  static String dayLong(DateTime d) => _dayLong.format(d);

  static String ago(DateTime? d) {
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return date(d);
  }

  static String minutes(int? m) {
    if (m == null) return '—';
    if (m < 60) return '$m min';
    final h = m ~/ 60;
    final rest = m % 60;
    return rest == 0 ? '$h h' : '$h h $rest min';
  }

  static String greeting([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String initials(String name) {
    final parts = name
        .replaceAll(RegExp(r'^(dr\.?\s+)', caseSensitive: false), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    return parts.take(2).map((p) => p.substring(0, 1).toUpperCase()).join();
  }
}
