import 'package:get/get.dart';

import '../../../data/models/ecg_record_model.dart';
import '../../../data/repositories/ecg_repository.dart';

/// Port of `LoadDataActivity` / the Reports tab: lists locally-saved
/// recordings and their sync status (there is no server-side "list my
/// reports" endpoint in the original app — see `ApiConstants` — so this
/// reads from the local store only, same as the Java app does).
class ReportsController extends GetxController {
  ReportsController({EcgRepository? repository}) : _repository = repository ?? EcgRepository();

  final EcgRepository _repository;

  final RxList<EcgRecordModel> records = <EcgRecordModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxString filter = 'All'.obs;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  Future<void> reload() async {
    isLoading.value = true;
    final all = await _repository.allRecords();
    records.assignAll(all);
    isLoading.value = false;
  }

  List<EcgRecordModel> get filtered {
    switch (filter.value) {
      case 'Synced':
        return records.where((r) => r.syncStatus == SyncStatus.synced).toList();
      case 'Pending':
        return records.where((r) => r.syncStatus == SyncStatus.pending).toList();
      case 'Offline':
        return records.where((r) => r.syncStatus == SyncStatus.failed || r.syncStatus == SyncStatus.offline).toList();
      default:
        return records;
    }
  }

  void setFilter(String value) => filter.value = value;
}
