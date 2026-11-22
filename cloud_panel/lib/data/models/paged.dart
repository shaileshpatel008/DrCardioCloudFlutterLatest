import '../../core/utils/json_utils.dart';

/// One page of a server-paginated list (`{data: [...], meta: {...}}`).
class Paged<T> {
  Paged({required this.items, required this.page, required this.perPage, required this.total, required this.lastPage});

  final List<T> items;
  final int page;
  final int perPage;
  final int total;
  final int lastPage;

  int get from => total == 0 ? 0 : (page - 1) * perPage + 1;
  int get to => (from + items.length - 1).clamp(0, total);

  factory Paged.fromJson(Map<String, dynamic> json, T Function(Map<String, dynamic>) parse) {
    final meta = asMap(json['meta']);
    final items = asMapList(json['data']).map(parse).toList();
    return Paged(
      items: items,
      page: asIntOr(meta['page'], 1),
      perPage: asIntOr(meta['per_page'], 10),
      total: asIntOr(meta['total'], items.length),
      lastPage: asIntOr(meta['last_page'], 1),
    );
  }

  static Paged<T> empty<T>() => Paged<T>(items: const [], page: 1, perPage: 10, total: 0, lastPage: 1);
}

/// A simple id/name pair for dropdowns (hospitals, staff, devices, doctors).
class LookupItem {
  const LookupItem(this.id, this.name);

  final int id;
  final String name;

  factory LookupItem.fromJson(Map<String, dynamic> json) =>
      LookupItem(asIntOr(json['id']), asStringOr(json['name'], '—'));

  @override
  bool operator ==(Object other) => other is LookupItem && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
