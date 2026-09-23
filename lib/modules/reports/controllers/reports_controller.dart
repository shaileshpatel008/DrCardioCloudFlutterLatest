import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' show DateTimeRange;
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

/// Which slice of a report's date range to show — an addition with no
/// equivalent in the original, which never offered any date filtering.
enum ReportDateFilter { all, today, yesterday, last7Days, last30Days, last3Months, lastYear, custom }

/// Port of `ReportActivity` (the Reports tab). Same exclusive-source
/// switch as the original's `onResume()`
/// (`if(PathUtil.INTERNET_STATUS) callGetReportsECGsListApi(); else
/// load_file_list();`): online shows the account's server-side report
/// history (`api/ecg-list`); offline shows what's saved on this device
/// instead — never both, so there's one consistent list at a time rather
/// than two visually different sections to reconcile. [records] backs the
/// offline view (plus [filter], the local sync-status filter — no
/// equivalent in the original); [cloudRecords] backs the online view (plus
/// [cloudStatusFilter], the "has a cardiologist reported on this yet"
/// filter). [dateFilter]/[customDateRange] apply to whichever list is
/// currently showing.
class ReportsController extends GetxController {
  ReportsController({EcgRepository? repository}) : _repository = repository ?? EcgRepository();

  final EcgRepository _repository;
  final connectivity = Get.find<ConnectivityService>();

  final RxList<EcgRecordModel> records = <EcgRecordModel>[].obs;
  final RxList<RemoteReportModel> cloudRecords = <RemoteReportModel>[].obs;
  final RxBool isLoading = true.obs;
  final RxnString cloudError = RxnString();
  final RxString searchQuery = ''.obs;

  /// Local (offline-view) sync-status filter.
  static const localStatusOptions = ['All', 'Synced', 'Pending', 'Offline'];
  final RxString filter = 'All'.obs;

  /// Cloud (online-view) reporting-status filter — matches the three
  /// states `_CloudStatusBadge` can show.
  static const cloudStatusOptions = ['All', 'Not Reported', 'Reported', 'Assigned'];
  final RxString cloudStatusFilter = 'All'.obs;

  final Rx<ReportDateFilter> dateFilter = ReportDateFilter.all.obs;
  final Rx<DateTimeRange?> customDateRange = Rx<DateTimeRange?>(null);

  bool get hasActiveFilters => filter.value != 'All' || cloudStatusFilter.value != 'All' || dateFilter.value != ReportDateFilter.all;

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

    final range = _effectiveDateRange;
    if (range != null) {
      result = result.where((r) => !r.dateTime.isBefore(range.start) && r.dateTime.isBefore(range.end));
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
    Iterable<RemoteReportModel> result = cloudRecords;
    switch (cloudStatusFilter.value) {
      case 'Not Reported':
        result = result.where((r) => !r.isReported);
        break;
      case 'Reported':
        result = result.where((r) => r.isReported && !r.assignedToCardiologist);
        break;
      case 'Assigned':
        result = result.where((r) => r.isReported && r.assignedToCardiologist);
        break;
    }

    // A report whose document_name doesn't parse to a date (see
    // RecordFileNaming.parse) can't be confirmed to fall inside any date
    // range, so a specific range excludes it rather than guessing —
    // "All Time" (range == null) still shows it.
    final range = _effectiveDateRange;
    if (range != null) {
      result = result.where((r) {
        final dt = RecordFileNaming.parse(r.documentName).dateTime;
        return dt != null && !dt.isBefore(range.start) && dt.isBefore(range.end);
      });
    }

    final query = searchQuery.value.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where((r) => r.documentName.toLowerCase().contains(query));
    }
    return result.toList();
  }

  /// The half-open start-inclusive/end-exclusive window [dateFilter]
  /// currently selects, or null for "All Time". Each preset is inclusive
  /// of today.
  DateTimeRange? get _effectiveDateRange {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    switch (dateFilter.value) {
      case ReportDateFilter.all:
        return null;
      case ReportDateFilter.today:
        return DateTimeRange(start: todayStart, end: tomorrowStart);
      case ReportDateFilter.yesterday:
        return DateTimeRange(start: todayStart.subtract(const Duration(days: 1)), end: todayStart);
      case ReportDateFilter.last7Days:
        return DateTimeRange(start: todayStart.subtract(const Duration(days: 6)), end: tomorrowStart);
      case ReportDateFilter.last30Days:
        return DateTimeRange(start: todayStart.subtract(const Duration(days: 29)), end: tomorrowStart);
      case ReportDateFilter.last3Months:
        return DateTimeRange(start: DateTime(now.year, now.month - 3, now.day), end: tomorrowStart);
      case ReportDateFilter.lastYear:
        return DateTimeRange(start: DateTime(now.year - 1, now.month, now.day), end: tomorrowStart);
      case ReportDateFilter.custom:
        final range = customDateRange.value;
        if (range == null) return null;
        final start = DateTime(range.start.year, range.start.month, range.start.day);
        final end = DateTime(range.end.year, range.end.month, range.end.day).add(const Duration(days: 1));
        return DateTimeRange(start: start, end: end);
    }
  }

  void setFilter(String value) => filter.value = value;
  void setCloudStatusFilter(String value) => cloudStatusFilter.value = value;
  void setSearchQuery(String value) => searchQuery.value = value;

  void setDateFilter(ReportDateFilter value) {
    dateFilter.value = value;
    if (value != ReportDateFilter.custom) customDateRange.value = null;
  }

  void setCustomDateRange(DateTimeRange range) {
    customDateRange.value = range;
    dateFilter.value = ReportDateFilter.custom;
  }

  void clearFilters() {
    filter.value = 'All';
    cloudStatusFilter.value = 'All';
    dateFilter.value = ReportDateFilter.all;
    customDateRange.value = null;
  }

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
