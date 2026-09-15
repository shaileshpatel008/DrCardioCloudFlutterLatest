import 'package:get/get.dart';

import '../../core/services/app_logger.dart';
import '../../core/services/connectivity_service.dart';
import '../datasources/local/ecg_local_datasource.dart';
import '../datasources/remote/ecg_remote_datasource.dart';
import '../models/ecg_record_model.dart';
import '../models/remote_report_model.dart';

/// Save-locally-then-sync-opportunistically, matching the original's
/// `PrefHelper.ECGDataList` queue + `sendOfflineECGDataToServer()`: every
/// recording lands in local storage immediately (so nothing is lost if
/// there's no signal), and gets uploaded in the background whenever
/// connectivity allows.
class EcgRepository {
  EcgRepository({EcgLocalDataSource? local, EcgRemoteDataSource? remote})
      : _local = local ?? EcgLocalDataSource(),
        _remote = remote ?? EcgRemoteDataSource();

  final EcgLocalDataSource _local;
  final EcgRemoteDataSource _remote;

  Future<void> saveLocally(EcgRecordModel record) => _local.save(record);

  Future<List<EcgRecordModel>> allRecords() => _local.all();

  Future<List<EcgRecordModel>> pendingUploads() => _local.pendingOrFailed();

  Future<List<EcgRecordModel>> search(String query) => _local.search(query);

  /// Uploads one record; on success marks it synced, on failure marks it
  /// failed (so the offline-reports screen can offer a manual retry) —
  /// same outcome branching as the Java `uploadPDF` response handler.
  Future<bool> syncOne(EcgRecordModel record, {bool autoAssignCardiologist = false}) async {
    try {
      await _remote.uploadReport(record: record, autoAssignCardiologist: autoAssignCardiologist);
      await _local.updateSyncStatus(record.id, SyncStatus.synced);
      return true;
    } catch (e, st) {
      AppLogger.e('Failed to upload report ${record.id}', e, st);
      await _local.updateSyncStatus(record.id, SyncStatus.failed);
      return false;
    }
  }

  /// Drains the pending/failed queue one at a time while online, mirroring
  /// the original's recursive `sendOfflineECGDataToServer()` retry loop.
  Future<void> syncPendingQueue() async {
    final connectivity = Get.find<ConnectivityService>();
    if (!connectivity.isOnline.value) return;

    final queue = await pendingUploads();
    for (final record in queue) {
      if (!connectivity.isOnline.value) break;
      await syncOne(record);
    }
  }

  /// The account's full server-side report history (`api/ecg-list`) —
  /// same call `ReportActivity` makes, independent of what's saved
  /// locally on this device.
  Future<List<RemoteReportModel>> fetchRemoteReports() => _remote.fetchEcgList();

  Future<void> assignCardiologist(String ecgRecordId) => _remote.assignCardiologist(ecgRecordId);

  /// Re-validates a device (by its Bluetooth name) against the signed-in
  /// account — throws with the server's rejection message if it isn't
  /// registered to this account.
  Future<void> authDevice(String deviceId) => _remote.authDevice(deviceId);
}
