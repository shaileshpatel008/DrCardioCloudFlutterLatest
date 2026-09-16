import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Port of the original app's `NetworkLiveData`: a single observable
/// online/offline flag the rest of the app (upload queue, offline-reports
/// banner) reacts to instead of polling.
class ConnectivityService extends GetxService {
  final RxBool isOnline = true.obs;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final List<Future<void> Function()> _onReconnectCallbacks = [];

  /// Registers a callback to run shortly after connectivity comes back —
  /// port of `MainActivity.onCreate()`'s `NetworkLiveData` observer, which
  /// waits 2s after `isConnected==true` then calls
  /// `sendOfflineECGDataToServer()` to drain the offline queue. Kept as a
  /// callback (rather than this service reaching into the data layer
  /// directly) so a core service doesn't depend on repositories — wired up
  /// once at app start in `main.dart`.
  void onReconnect(Future<void> Function() callback) {
    _onReconnectCallbacks.add(callback);
  }

  Future<ConnectivityService> init() async {
    final initial = await Connectivity().checkConnectivity();
    isOnline.value = !initial.contains(ConnectivityResult.none);

    _sub = Connectivity().onConnectivityChanged.listen((results) async {
      final nowOnline = !results.contains(ConnectivityResult.none);
      final wasOffline = !isOnline.value;
      isOnline.value = nowOnline;

      if (wasOffline && nowOnline) {
        await Future.delayed(const Duration(seconds: 2));
        if (!isOnline.value) return; // flapped back offline during the settle delay
        for (final callback in _onReconnectCallbacks) {
          await callback();
        }
      }
    });
    return this;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
