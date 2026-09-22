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

    // Looping over syncOne directly here (rather than the repository's own
    // syncPendingQueue, which stays silent for its other caller — the
    // reconnect-triggered background sync in main.dart) so this screen can
    // show the server's actual error instead of leaving a failed retry
    // unexplained.
    String? lastFailure;
    var alreadyUploadedCount = 0;
    for (final record in List<EcgRecordModel>.from(pending)) {
      if (!connectivity.isOnline.value) break;
      final outcome = await _repository.syncOne(record);
      if (outcome.alreadyUploaded) {
        alreadyUploadedCount++;
      } else if (!outcome.success) {
        lastFailure = outcome.message;
      }
    }

    await reload();
    isRetrying.value = false;

    if (lastFailure != null) {
      AppToast.error(lastFailure, title: 'Upload failed');
    } else if (alreadyUploadedCount > 0) {
      AppToast.info('$alreadyUploadedCount report${alreadyUploadedCount == 1 ? '' : 's'} were already uploaded.');
    }
  }

  Future<void> retryOne(EcgRecordModel record) async {
    final outcome = await _repository.syncOne(record);
    await reload();
    if (outcome.alreadyUploaded) {
      AppToast.info(outcome.message!);
    } else if (!outcome.success) {
      AppToast.error(outcome.message ?? 'Could not upload this report.', title: 'Upload failed');
    }
  }
}
