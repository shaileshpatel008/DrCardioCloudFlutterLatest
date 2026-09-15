import 'package:get/get.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../data/repositories/ecg_repository.dart';

/// Port of `OfflineReportListActivity` — the pending/failed upload queue,
/// with a manual "retry all" action mirroring
/// `sendOfflineECGDataToServer()`.
class OfflineReportsController extends GetxController {
  OfflineReportsController({EcgRepository? repository}) : _repository = repository ?? EcgRepository();

  final EcgRepository _repository;
  final connectivity = Get.find<ConnectivityService>();

  final RxList<EcgRecordModel> pending = <EcgRecordModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxBool isRetrying = false.obs;

  @override
  void onInit() {
    super.onInit();
    reload();
  }

  Future<void> reload() async {
    isLoading.value = true;
    pending.assignAll(await _repository.pendingUploads());
    isLoading.value = false;
  }

  Future<void> retryAll() async {
    if (!connectivity.isOnline.value) {
      AppToast.warning('Connect to the internet and try again.', title: 'Still offline');
      return;
    }
    isRetrying.value = true;
    await _repository.syncPendingQueue();
    await reload();
    isRetrying.value = false;
  }

  Future<void> retryOne(EcgRecordModel record) async {
    await _repository.syncOne(record);
    await reload();
  }
}
