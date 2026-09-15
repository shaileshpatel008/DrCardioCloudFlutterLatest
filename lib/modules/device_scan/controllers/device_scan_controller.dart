import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../core/services/bluetooth/ecg_transport.dart';
import '../../../core/widgets/app_toast.dart';

class DeviceScanController extends GetxController {
  final BluetoothService bluetoothService = Get.find<BluetoothService>();

  final RxList<EcgDevice> devices = <EcgDevice>[].obs;
  final RxBool isScanning = false.obs;
  final RxnString error = RxnString();
  final RxnString connectingId = RxnString();

  StreamSubscription<EcgDevice>? _scanSub;

  @override
  void onInit() {
    super.onInit();
    startScan();
  }

  Future<void> startScan() async {
    // Defensive: if this fires twice (e.g. GetX re-running onInit) without
    // cleaning up first, the underlying plugin's discovery stream can only
    // be listened to once at a time and throws a bare "Bad state" with no
    // context of its own — stop any scan already in flight first.
    await stopScan();

    error.value = null;
    devices.clear();

    try {
      if (Platform.isAndroid) {
        await [Permission.bluetoothScan, Permission.bluetoothConnect, Permission.locationWhenInUse].request();
      } else {
        await Permission.bluetooth.request();
      }

      final paired = await bluetoothService.pairedDevices();
      devices.addAll(paired);

      isScanning.value = true;
      _scanSub = bluetoothService.scan().listen(
        (device) {
          if (!devices.any((d) => d.id == device.id)) devices.add(device);
        },
        onDone: () => isScanning.value = false,
        onError: (Object e, StackTrace st) {
          AppLogger.e('Device scan stream error', e, st);
          isScanning.value = false;
          error.value = e.toString();
        },
      );
    } catch (e, st) {
      AppLogger.e('Failed to start device scan', e, st);
      isScanning.value = false;
      error.value = e.toString();
    }
  }

  Future<void> stopScan() async {
    try {
      await _scanSub?.cancel();
      _scanSub = null;
      await bluetoothService.stopScan();
    } catch (e, st) {
      AppLogger.w('Error stopping device scan', e, st);
    }
    isScanning.value = false;
  }

  Future<void> connect(EcgDevice device) async {
    connectingId.value = device.id;
    try {
      await bluetoothService.connect(device);
      Get.back(result: device);
    } catch (e, st) {
      AppLogger.e('Failed to connect to ${device.name} (${device.id})', e, st);
      AppToast.error(e.toString(), title: 'Could not connect');
    } finally {
      connectingId.value = null;
    }
  }

  @override
  void onClose() {
    _scanSub?.cancel();
    bluetoothService.stopScan();
    super.onClose();
  }
}
