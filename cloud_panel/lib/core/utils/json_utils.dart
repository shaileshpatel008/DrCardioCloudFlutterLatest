/// Tolerant JSON readers: the panel API returns numbers as int or string
/// depending on the column, and many fields are nullable.
int? asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

int asIntOr(dynamic v, [int fallback = 0]) => asInt(v) ?? fallback;

String? asString(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty || s.toLowerCase() == 'null' ? null : s;
}

String asStringOr(dynamic v, [String fallback = '']) => asString(v) ?? fallback;

bool asBool(dynamic v) {
  if (v is bool) return v;
  if (v is num) return v != 0;
  if (v is String) return v == '1' || v.toLowerCase() == 'true';
  return false;
}

DateTime? asDate(dynamic v) {
  final s = asString(v);
  if (s == null) return null;
  return DateTime.tryParse(s)?.toLocal();
}

Map<String, dynamic> asMap(dynamic v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return Map<String, dynamic>.from(v);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(dynamic v) {
  if (v is List) return v.map(asMap).toList();
  return const [];
}
