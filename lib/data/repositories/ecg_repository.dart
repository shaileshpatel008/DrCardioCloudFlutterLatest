import 'package:get/get.dart';

import '../../core/services/app_logger.dart';
import '../../core/services/bluetooth/bluetooth_service.dart';
import '../../core/services/connectivity_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/app_toast.dart';
import '../datasources/local/ecg_local_datasource.dart';
import '../datasources/remote/auth_remote_datasource.dart';
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
  ///
  /// [autoAssignCardiologist] defaults to whatever Settings' "Auto-assign
  /// cardiologist" toggle currently is (`settings.auto_assign`, read fresh
  /// at upload time in the original too) so every call site — a
  /// just-finished recording, the reconnect-triggered background sync, a
  /// manual retry from Offline Reports — honors it without each one having
  /// to know to look it up. Pass it explicitly only to override that.
  Future<SyncOutcome> syncOne(EcgRecordModel record, {bool? autoAssignCardiologist}) async {
    final assignFlag = autoAssignCardiologist ?? StorageService.instance.autoAssignCardiologist;
    try {
      await _remote.uploadReport(record: record, autoAssignCardiologist: assignFlag);
      await _local.updateSyncStatus(record.id, SyncStatus.synced);
      return const SyncOutcome.success();
    } on ApiStatusException catch (e) {
      if (e.message.toLowerCase().contains('already uploaded')) {
        // The server already has this exact record — most likely a prior
        // upload that succeeded but never got as far as updating the local
        // status (an app kill, or losing connectivity right after the
        // response). Without this branch every retry, manual or the
        // reconnect-triggered background sync, would keep failing with the
        // same "ECG already uploaded" error forever, trapping the record in
        // the offline queue with no way to clear it.
        await _local.updateSyncStatus(record.id, SyncStatus.synced);
        AppLogger.i('Report ${record.id} was already uploaded — marking synced locally.');
        return const SyncOutcome.alreadyUploaded();
      }
      AppLogger.e('Failed to upload report ${record.id}', e);
      await _local.updateSyncStatus(record.id, SyncStatus.failed);
      return SyncOutcome.failure(e.message);
    } catch (e, st) {
      AppLogger.e('Failed to upload report ${record.id}', e, st);
      await _local.updateSyncStatus(record.id, SyncStatus.failed);
      return const SyncOutcome.failure('Could not upload this report. Please check your connection and try again.');
    }
  }

  /// Drains the pending/failed queue one at a time while online, mirroring
  /// the original's recursive `sendOfflineECGDataToServer()` retry loop.
  /// Silent by design (this also runs unattended after a reconnect, see
  /// `main.dart`) — a screen driving a retry itself should call [syncOne]
  /// directly instead, so it can surface each [SyncOutcome] to the user.
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

  /// A device connected for the first time while offline is let through
  /// unvalidated (see `DeviceScanController._validateWithServer`) so a
  /// brand-new device isn't unusable just because there's no signal at
  /// that exact moment — this is the other half: retries validation once
  /// connectivity is back (wired via `ConnectivityService.onReconnect` in
  /// `main.dart`, same as the pending-uploads queue is drained then too).
  /// A rejection now means the account genuinely doesn't own this device,
  /// so it disconnects — same outcome as a rejection at connect time.
  Future<void> revalidateConnectedDevice(BluetoothService bluetoothService) async {
    if (bluetoothService.state.value != BtConnectionState.connected) return;
    final storage = StorageService.instance;
    final name = bluetoothService.connectedDeviceName.value;
    if (name.isEmpty || storage.savedDeviceName == name) return;

    try {
      await authDevice(name);
      storage.savedDeviceName = name;
    } on ApiStatusException catch (e) {
      AppToast.error(e.message, title: 'Device not registered');
      await bluetoothService.disconnect();
    } catch (e, st) {
      AppLogger.w('Could not re-validate device $name after reconnect', e, st);
    }
  }
}

/// Result of a single [EcgRepository.syncOne] attempt — three cases a caller
/// showing feedback needs to tell apart, not just pass/fail: a clean upload
/// (no message to show at all), the server reporting this exact record was
/// already uploaded (a synced success, but worth an informational note
/// rather than a scary "failed" one), and a genuine failure whose [message]
/// is the server's own `error_data` (e.g. "ECG already uploaded." would
/// never reach here — it's the [alreadyUploaded] case instead).
class SyncOutcome {
  const SyncOutcome._(this.success, this.alreadyUploaded, this.message);

  const SyncOutcome.success() : this._(true, false, null);
  const SyncOutcome.alreadyUploaded() : this._(true, true, 'This report was already uploaded — marked as synced.');
  const SyncOutcome.failure(String message) : this._(false, false, message);

  final bool success;
  final bool alreadyUploaded;
  final String? message;
}
