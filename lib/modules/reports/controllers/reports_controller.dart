import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/record_file_naming.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../data/models/remote_report_model.dart';
import '../../../data/repositories/ecg_repository.dart';
import '../../home/controllers/home_controller.dart';

/// Port of `ReportActivity` (the Reports tab). Same exclusive-source
/// switch as the original's `onResume()`
/// (`if(PathUtil.INTERNET_STATUS) callGetReportsECGsListApi(); else
/// load_file_list();`): online shows the account's server-side report
/// history (`api/ecg-list`); offline shows what's saved on this device
/// instead — never both, so there's one consistent list at a time rather
/// than two visually different sections to reconcile. [records] backs the
/// offline view (plus the sync-status filter chips, which have no
/// equivalent in the original); [cloudRecords] backs the online view.
class ReportsController extends GetxController {
  ReportsController({EcgRepository? repository}) : _repository = repository ?? EcgRepository();

  final EcgRepository _repository;
  final connectivity = Get.find<ConnectivityService>();

  final RxList<EcgRecordModel> records = <EcgRecordModel>[].obs;
  final RxList<RemoteReportModel> cloudRecords = <RemoteReportModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxnString cloudError = RxnString();
  final RxString filter = 'All'.obs;
  final RxString searchQuery = ''.obs;

  /// `ecg_record_id`s with an assign-to-cardiologist call in flight, so a
  /// row's button disables itself instead of allowing a double-tap.
  final RxSet<String> assigningIds = <String>{}.obs;

  @override
  void onInit() {
    super.onInit();
    reload();
    // The original re-checks connectivity in onResume() (a fresh Activity
    // visit); this screen instead stays mounted for as long as its bottom-nav
    // tab does, so a live listener is this app's equivalent of "re-check
    // when the screen would next become current".
    ever(connectivity.isOnline, (_) => reload());
    // Reports lives inside Home's IndexedStack (see HomeBinding) — it's
    // created once and kept alive across tab switches, not rebuilt every
    // time it's shown, so nothing else here re-runs when the user comes
    // back to this tab after uploading/syncing a report elsewhere. Original
    // app parity: ReportActivity.onResume() re-hits
    // callGetReportsECGsListApi()/load_file_list() on every single visit;
    // watching HomeController's tab index is this port's equivalent of
    // that visit signal.
    if (Get.isRegistered<HomeController>()) {
      ever(Get.find<HomeController>().tabIndex, (index) {
        if (index == 1) reload();
      });
    }
  }

  Future<void> reload() async {
    isLoading.value = true;
    final online = connectivity.isOnline.value;

    if (online) {
      cloudError.value = null;
      try {
        final remote = await _repository.fetchRemoteReports();
        cloudRecords.assignAll(remote);
      } catch (e, st) {
        AppLogger.w('Could not load cloud reports', e, st);
        cloudError.value = e.toString();
      }
    } else {
      final all = await _repository.allRecords();
      records.assignAll(all);
    }
    isLoading.value = false;
  }

  List<EcgRecordModel> get filtered {
    Iterable<EcgRecordModel> result;
    switch (filter.value) {
      case 'Synced':
        result = records.where((r) => r.syncStatus == SyncStatus.synced);
        break;
      case 'Pending':
        result = records.where((r) => r.syncStatus == SyncStatus.pending);
        break;
      case 'Offline':
        result = records.where((r) => r.syncStatus == SyncStatus.failed || r.syncStatus == SyncStatus.offline);
        break;
      default:
        result = records;
    }

    final query = searchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((r) => r.patient.name.toLowerCase().contains(query) || r.patient.patientId.toLowerCase().contains(query));
    }
    return result.toList();
  }

  /// `cloudRecords` has no patient field of its own (see
  /// `RemoteReportModel`'s doc comment) — matched by document name
  /// instead. Deliberately NOT the original's raw-string search (which
  /// substring-matched literal internal tags like "@true"/"@reported@"
  /// alongside the filename — an artifact of its ad-hoc row encoding, not
  /// a real feature worth reproducing).
  List<RemoteReportModel> get filteredCloudRecords {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return cloudRecords;
    return cloudRecords.where((r) => r.documentName.toLowerCase().contains(query)).toList();
  }

  void setFilter(String value) => filter.value = value;
  void setSearchQuery(String value) => searchQuery.value = value;

  /// Port of `ReportActivity.callAssignToCardiologistApi()`: a per-report,
  /// always-available manual action independent of the "Auto-assign
  /// cardiologist" setting (that toggle only decides what a NEW recording
  /// sends automatically at upload time) — the original has no
  /// confirmation dialog before calling either, so this doesn't add one.
  Future<void> assignToCardiologist(String ecgRecordId) async {
    if (assigningIds.contains(ecgRecordId)) return;
    assigningIds.add(ecgRecordId);
    try {
      await _repository.assignCardiologist(ecgRecordId);
      AppToast.success('Sent for cardiologist review.');
      await reload();
    } catch (e, st) {
      AppLogger.e('Failed to assign cardiologist for $ecgRecordId', e, st);
      AppToast.error(e.toString());
    } finally {
      assigningIds.remove(ecgRecordId);
    }
  }

  /// Port of `ReportActivity.shareFile()`/`downloadAndSharePDF()` — PDF
  /// only, no message text or subject, same as the original's share
  /// intent.
  Future<void> shareLocalRecord(EcgRecordModel record) async {
    final path = record.pdfPath;
    if (path == null || !await File(path).exists()) {
      AppToast.warning('PDF not found on this device.');
      return;
    }
    await Printing.sharePdf(bytes: await File(path).readAsBytes(), filename: '${RecordFileNaming.stem(record)}.pdf');
  }

  Future<void> shareRemoteReport(RemoteReportModel report) async {
    try {
      final response = await DioClient.instance.dio.get<List<int>>(
        report.documentPath,
        options: Options(responseType: ResponseType.bytes),
      );
      await Printing.sharePdf(bytes: Uint8List.fromList(response.data!), filename: '${report.documentName}.pdf');
    } catch (e, st) {
      AppLogger.e('Failed to download report ${report.ecgRecordId} for sharing', e, st);
      AppToast.error('Could not download PDF to share.');
    }
  }
}
