import 'package:get/get.dart';

import '../../data/models/paged.dart';
import '../../data/repositories/network_repository.dart';
import '../network/api_exception.dart';

/// Shared state for every server-paginated list: page, page size, search,
/// sorting, loading / error state. Subclasses only implement [fetch].
abstract class PagedListController<T> extends GetxController {
  final items = <T>[].obs;
  final isLoading = true.obs;
  final error = RxnString();

  final page = 1.obs;
  final perPage = 10.obs;
  final total = 0.obs;
  final lastPage = 1.obs;
  final from = 0.obs;
  final to = 0.obs;

  final search = ''.obs;
  late final RxString sortKey = defaultSort.obs;
  final sortAsc = false.obs;

  int _requestId = 0;

  String get defaultSort => 'date';

  /// Extra query parameters (filters) added by subclasses.
  Map<String, dynamic> get extraQuery => const {};

  Future<Paged<T>> fetch(ListQuery query);

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({int? toPage, bool silent = false}) async {
    if (toPage != null) page.value = toPage;
    final id = ++_requestId;
    if (!silent) isLoading.value = true;
    error.value = null;
    try {
      final result = await fetch(ListQuery(
        page: page.value,
        perPage: perPage.value,
        search: search.value,
        sort: sortKey.value,
        dir: sortAsc.value ? 'asc' : 'desc',
        extra: extraQuery,
      ));
      if (id != _requestId) return; // a newer request superseded this one
      items.assignAll(result.items);
      total.value = result.total;
      lastPage.value = result.lastPage;
      from.value = result.from;
      to.value = result.to;
      if (page.value > result.lastPage && result.total > 0) {
        await load(toPage: result.lastPage);
      }
    } on ApiException catch (e) {
      if (id == _requestId) error.value = e.message;
    } catch (e) {
      if (id == _requestId) error.value = 'Something went wrong. Please try again.';
    } finally {
      if (id == _requestId) isLoading.value = false;
    }
  }

  Future<void> refreshList() => load(silent: items.isNotEmpty);

  void setSearch(String value) {
    if (value.trim() == search.value) return;
    search.value = value.trim();
    load(toPage: 1);
  }

  void setPage(int p) => load(toPage: p);

  void setPerPage(int n) {
    perPage.value = n;
    load(toPage: 1);
  }

  void toggleSort(String key) {
    if (sortKey.value == key) {
      sortAsc.toggle();
    } else {
      sortKey.value = key;
      sortAsc.value = key == 'name' || key == 'hospital' || key == 'email';
    }
    load(toPage: 1);
  }
}
