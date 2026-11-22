import 'dart:async';

import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/sound/alert_sound.dart';
import '../../core/services/storage_service.dart';
import '../../core/widgets/app_toast.dart';
import '../../data/models/dashboard_model.dart';
import '../../data/models/network_models.dart';
import '../../data/repositories/ecg_repository.dart';
import '../../data/repositories/network_repository.dart';

/// Lives for the whole signed-in session: sidebar counts, the bell's
/// notifications (polled every 60 s like the web panel), and the
/// collapsed / expanded sidebar preference.
class ShellController extends GetxController {
  final _auth = Get.find<AuthService>();
  final _notifications = NotificationRepository();
  final _ecg = EcgRepository();

  final counts = Rxn<DashboardCounts>();
  final notifications = <NotificationItem>[].obs;
  final unread = 0.obs;
  final sidebarCollapsed = StorageService.instance.sidebarCollapsed.obs;

  Timer? _poll;
  bool _firstPoll = true;
  late final Worker _authWorker;

  @override
  void onInit() {
    super.onInit();
    _authWorker = ever(_auth.user, (u) => u == null ? _stop() : _start());
    if (_auth.isLoggedIn) _start();
  }

  @override
  void onClose() {
    _authWorker.dispose();
    _stop();
    super.onClose();
  }

  void _start() {
    refreshCounts();
    _firstPoll = true;
    pollNotifications();
    _poll?.cancel();
    _poll = Timer.periodic(AppConstants.notificationPoll, (_) => pollNotifications());
  }

  void _stop() {
    _poll?.cancel();
    _poll = null;
    counts.value = null;
    notifications.clear();
    unread.value = 0;
  }

  Future<void> refreshCounts() async {
    try {
      counts.value = (await _ecg.dashboard()).counts;
    } catch (_) {}
  }

  void setCounts(DashboardCounts value) => counts.value = value;

  int? countFor(String? key) {
    final c = counts.value;
    if (c == null || key == null) return null;
    return switch (key) {
      'ecg_records' => c.ecgRecords,
      'clients' => c.clients,
      'staffs' => c.staffs,
      'cardiologists' => c.cardiologists,
      'devices' => c.devices,
      _ => null,
    };
  }

  Future<void> pollNotifications() async {
    if (!_auth.isLoggedIn) return;
    try {
      final result = await _notifications.latest();
      final hadUnread = unread.value;
      notifications.assignAll(result.items);
      unread.value = result.unread;
      if (!_firstPoll && result.unread > hadUnread) {
        AlertSound.play();
        AppToast.info(result.items.isNotEmpty ? result.items.first.title : 'You have new notifications.', title: 'New ECG for review');
      }
      _firstPoll = false;
    } catch (_) {}
  }

  Future<void> markRead(NotificationItem n) async {
    notifications.remove(n);
    unread.value = (unread.value - 1).clamp(0, 1 << 30);
    try {
      await _notifications.read(n.id);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    notifications.clear();
    unread.value = 0;
    try {
      await _notifications.readAll();
      AppToast.success('All notifications marked as read.');
    } catch (_) {}
  }

  void toggleSidebar() {
    sidebarCollapsed.toggle();
    StorageService.instance.sidebarCollapsed = sidebarCollapsed.value;
  }
}
