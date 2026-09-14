import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../core/services/bluetooth/ecg_transport.dart';

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
    error.value = null;
    devices.clear();

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
      onError: (e) {
        isScanning.value = false;
        error.value = e.toString();
      },
    );
  }

  Future<void> stopScan() async {
    await _scanSub?.cancel();
    await bluetoothService.stopScan();
    isScanning.value = false;
  }

  Future<void> connect(EcgDevice device) async {
    connectingId.value = device.id;
    try {
      await bluetoothService.connect(device);
      Get.back(result: device);
    } catch (e) {
      Get.snackbar('Could not connect', e.toString());
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
