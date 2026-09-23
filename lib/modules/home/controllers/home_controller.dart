import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../data/models/remote_report_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/ecg_repository.dart';
import '../../../routes/app_routes.dart';

/// Port of `MainActivity`'s dashboard: shows connection state, the
/// "New ECG" call-to-action (disabled with a pulsing "tap to connect"
/// affordance when nothing is connected, highlighted once a device is),
/// and the bottom navigation between New ECG / Reports / Help / Settings
/// — matching `act_menu_new.xml`'s real tab set (not a generic "Home").
class HomeController extends GetxController with WidgetsBindingObserver {
  HomeController({EcgRepository? ecgRepository, AuthRepository? authRepository})
      : _ecgRepository = ecgRepository ?? EcgRepository(),
        _authRepository = authRepository ?? AuthRepository();

  final BluetoothService bluetoothService = Get.find<BluetoothService>();
  final EcgRepository _ecgRepository;
  final AuthRepository _authRepository;
  final storage = StorageService.instance;
  final connectivity = Get.find<ConnectivityService>();

  final RxInt tabIndex = 0.obs;
  final RxInt pendingSyncCount = 0.obs;

  /// Newest 5 for the dashboard's "Recent Reports" section — the full
  /// list lives on the Reports tab, reached via "View All". Same
  /// exclusive online/offline source switch as `ReportsController`
  /// (online -> account/server history; offline -> this device's own
  /// saved recordings), so this preview always matches what "View All"
  /// would actually show instead of a locals-only preview linking to a
  /// screen that might currently be showing something else entirely.
  static const _recentLimit = 5;
  final RxList<EcgRecordModel> recentRecords = <EcgRecordModel>[].obs;
  final RxList<RemoteReportModel> recentCloudRecords = <RemoteReportModel>[].obs;

  /// Port of `MainActivity`'s "ECG Left" plan-count badge
  /// (`layout_plan_count`/`tvCount`), seeded from whatever `login()` last
  /// persisted so the badge doesn't flash hidden-then-shown, then
  /// refreshed from `api/get-token` every time Home becomes current again
  /// — see [didChangeAppLifecycleState] — matching `callGetLatestTokenApi()`
  /// (called from `MainActivity.onResume()`, which fires on every return to
  /// the foreground, not just once at launch).
  final RxBool reportLimitEnabled = false.obs;
  final RxInt reportLimit = 0.obs;

  BtConnectionState get connectionState => bluetoothService.state.value;

  @override
  void onInit() {
    super.onInit();
    _refreshPendingCount();
    _refreshRecentRecords();
    reportLimitEnabled.value = storage.reportLimitEnabled;
    reportLimit.value = storage.reportLimit;
    _refreshReportLimit();
    // Port of `MainActivity.checkLastConnectedDevice()`, called from Home
    // the same way it's called from `onCreate()`/app launch — reconnects
    // to whatever device was last used without sending the user back
    // through Device Scan for a device that's already connected and
    // therefore won't show up in a fresh scan.
    bluetoothService.autoReconnectIfNeeded();
    ever(bluetoothService.state, (_) {});
    ever(connectivity.isOnline, (_) {
      _refreshRecentRecords();
      _refreshReportLimit();
    });

    // This controller is created once per login (Get.offAllNamed on
    // login/logout) and then lives for the rest of the session — every
    // other screen is pushed on top of Home rather than replacing it, so
    // onInit() above only ever runs once. The original re-hits
    // api/get-token on every single MainActivity.onResume() (app reopened,
    // returned from background, unlocked, etc.), which is what actually
    // keeps its token from going stale over a long session. Without this
    // observer, this port's token/report-limit/recent-records only ever
    // refreshed at login, so API calls could start failing hours into a
    // session with no obvious cause short of logging out and back in.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPendingCount();
      _refreshRecentRecords();
      _refreshReportLimit();
    }
  }

  void changeTab(int index) => tabIndex.value = index;

  Future<void> _refreshPendingCount() async {
    final pending = await _ecgRepository.pendingUploads();
    pendingSyncCount.value = pending.length;
  }

  Future<void> _refreshRecentRecords() async {
    if (connectivity.isOnline.value) {
      try {
        final remote = await _ecgRepository.fetchRemoteReports();
        recentCloudRecords.assignAll(remote.take(_recentLimit));
      } catch (e, st) {
        AppLogger.w('Could not load recent cloud reports for dashboard', e, st);
      }
    } else {
      // Already newest-first (EcgLocalDataSource.all() orders by
      // date_time DESC) — just take the top few.
      final all = await _ecgRepository.allRecords();
      recentRecords.assignAll(all.take(_recentLimit));
    }
  }

  Future<void> _refreshReportLimit() async {
    // Matches `if(PathUtil.INTERNET_STATUS) { callGetLatestTokenApi(); }` —
    // skip silently when offline rather than showing an error for a
    // background refresh nobody asked for; the seeded value from storage
    // (above) stands until the next successful load.
    if (!connectivity.isOnline.value) return;
    try {
      final user = await _authRepository.refreshToken();
      reportLimitEnabled.value = user.reportLimitEnabled;
      reportLimit.value = user.reportLimit;
    } catch (e, st) {
      AppLogger.w('Could not refresh report-limit quota', e, st);
    }
  }

  /// "View All" on the dashboard's Recent Reports section — Reports is a
  /// bottom-nav tab, not a separate route, so this just switches tabs.
  void viewAllReports() => changeTab(1);

  // DeviceScanController.connect() already handles connecting, server
  // validation, and updating storage.savedDeviceName on success — this
  // just opens that screen.
  Future<void> connectDevice() async {
    await Get.toNamed(AppRoutes.deviceScan);
  }

  /// Port of `MainActivity`'s "Acquire New ECG" click handler: connected ->
  /// proceed; still connecting -> toast rather than doing anything (a
  /// second tap shouldn't kick off a second connection attempt); not
  /// connected at all -> straight to Device Scan instead of just refusing,
  /// since that's the only thing tapping this button could sensibly do
  /// next anyway.
  ///
  /// Which screen opens first once connected is a Settings toggle
  /// (`patientInfoFirst`) — the original always went straight to Live ECG
  /// and collected patient info afterward, right before generating the
  /// report; this port's own default flips that order (Patient Info
  /// first), so this only takes the original's path when a client has
  /// explicitly asked to switch back.
  void startNewEcg() {
    switch (bluetoothService.state.value) {
      case BtConnectionState.connecting:
        AppToast.warning('Please wait, trying to connect…', title: 'Connecting');
        return;
      case BtConnectionState.disconnected:
        connectDevice();
        return;
      case BtConnectionState.connected:
        Get.toNamed(storage.patientInfoFirst ? AppRoutes.patientInfo : AppRoutes.liveEcg);
    }
  }
}
