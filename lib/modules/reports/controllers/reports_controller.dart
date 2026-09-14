import 'package:get/get.dart';

import '../../../core/services/app_logger.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../data/models/remote_report_model.dart';
import '../../../data/repositories/ecg_repository.dart';

/// Port of `ReportActivity` (the Reports tab): its primary list is the
/// account's server-side report history (`api/ecg-list`), independent of
/// what's saved on this device — `LoadDataActivity`/"Load Data" is the
/// separate, local-files-only screen. [records] mirrors this device's own
/// recordings (for the sync-status filter chips, which have no equivalent
/// in the original); [cloudRecords] mirrors the original's actual list.
class ReportsController extends GetxController {
  ReportsController({EcgRepository? repository}) : _repository = repository ?? EcgRepository();

  final EcgRepository _repository;

  final RxList<EcgRecordModel> records = <EcgRecordModel>[].obs;
  final RxList<RemoteReportModel> cloudRecords = <RemoteReportModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxnString cloudError = RxnString();
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

    // Best-effort: the device may be offline, or the account may have no
    // cloud history yet — either way local records above still show.
    cloudError.value = null;
    try {
      final remote = await _repository.fetchRemoteReports();
      cloudRecords.assignAll(remote);
    } catch (e, st) {
      AppLogger.w('Could not load cloud reports', e, st);
      cloudError.value = e.toString();
    }
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
