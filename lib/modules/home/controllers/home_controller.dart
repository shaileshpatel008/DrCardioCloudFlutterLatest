import 'package:get/get.dart';

import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../core/services/bluetooth/ecg_transport.dart';
import '../../../core/services/storage_service.dart';
import '../../../data/repositories/ecg_repository.dart';
import '../../../routes/app_routes.dart';

/// Port of `MainActivity`'s dashboard: shows connection state, the
/// "New ECG" call-to-action (disabled with a pulsing "tap to connect"
/// affordance when nothing is connected, highlighted once a device is),
/// and the bottom navigation between New ECG / Reports / Help / Settings
/// — matching `act_menu_new.xml`'s real tab set (not a generic "Home").
class HomeController extends GetxController {
  HomeController({EcgRepository? ecgRepository}) : _ecgRepository = ecgRepository ?? EcgRepository();

  final BluetoothService bluetoothService = Get.find<BluetoothService>();
  final EcgRepository _ecgRepository;
  final storage = StorageService.instance;

  final RxInt tabIndex = 0.obs;
  final RxInt pendingSyncCount = 0.obs;

  BtConnectionState get connectionState => bluetoothService.state.value;

  @override
  void onInit() {
    super.onInit();
    _refreshPendingCount();
    ever(bluetoothService.state, (_) {});
  }

  void changeTab(int index) => tabIndex.value = index;

  Future<void> _refreshPendingCount() async {
    final pending = await _ecgRepository.pendingUploads();
    pendingSyncCount.value = pending.length;
  }

  Future<void> connectDevice() async {
    final result = await Get.toNamed(AppRoutes.deviceScan);
    if (result is EcgDevice) {
      storage.savedDeviceName = result.name;
    }
  }

  void startNewEcg() {
    if (bluetoothService.state.value != BtConnectionState.connected) {
      Get.snackbar(
        'Not connected',
        'Connect to the ECG device first.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }
    Get.toNamed(AppRoutes.patientInfo);
  }
}
