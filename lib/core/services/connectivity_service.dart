import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Port of the original app's `NetworkLiveData`: a single observable
/// online/offline flag the rest of the app (upload queue, offline-reports
/// banner) reacts to instead of polling.
class ConnectivityService extends GetxService {
  final RxBool isOnline = true.obs;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<ConnectivityService> init() async {
    final initial = await Connectivity().checkConnectivity();
    isOnline.value = !initial.contains(ConnectivityResult.none);

    _sub = Connectivity().onConnectivityChanged.listen((results) {
      isOnline.value = !results.contains(ConnectivityResult.none);
    });
    return this;
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
