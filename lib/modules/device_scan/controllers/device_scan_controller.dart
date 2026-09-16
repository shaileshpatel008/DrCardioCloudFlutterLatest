import 'dart:async';
import 'dart:io';

import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../core/services/bluetooth/ecg_transport.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/datasources/remote/auth_remote_datasource.dart';
import '../../../data/repositories/ecg_repository.dart';

class DeviceScanController extends GetxController {
  DeviceScanController({EcgRepository? repository}) : _repository = repository ?? EcgRepository();

  final BluetoothService bluetoothService = Get.find<BluetoothService>();
  final EcgRepository _repository;

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
          final idx = devices.indexWhere((d) => d.id == device.id);
          if (idx == -1) {
            devices.add(device);
          } else if (devices[idx].transport != TransportType.ble && device.transport == TransportType.ble) {
            // Prefer the BLE result for the same id: these ECG units are
            // BLE-only and pairing-free, but classic-SPP discovery often
            // reports the same MAC first, which would otherwise lock the
            // row into the classic-SPP (bond-then-connect) path that
            // always fails pairing for this hardware.
            devices[idx] = device;
          }
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
      await _validateWithServer(device);
      Get.back(result: device);
    } catch (e, st) {
      AppLogger.e('Failed to connect to ${device.name} (${device.id})', e, st);
      AppToast.error(e.toString(), title: 'Could not connect');
      await bluetoothService.disconnect();
    } finally {
      connectingId.value = null;
    }
  }

  /// Port of `MainActivity.connectedToDevice()`'s device-validation branch:
  /// reconnecting to the *same* device already validated last time skips
  /// straight through (no need to hit the server every time); connecting
  /// to a different/new device calls `api/auth-device`, and a rejection
  /// ("Device is not registered" in the original's AlertDialog) disconnects
  /// rather than leaving a half-trusted session.
  ///
  /// Offline + a device never validated before is let through instead of
  /// blocked — an earlier version threw here and forced a disconnect,
  /// which made a brand-new device completely unusable with no signal at
  /// all. `EcgRepository.revalidateConnectedDevice` (wired to
  /// `ConnectivityService.onReconnect` in `main.dart`) retries this
  /// automatically the moment connectivity returns; a rejection then
  /// disconnects, same as a rejection here would.
  Future<void> _validateWithServer(EcgDevice device) async {
    final storage = StorageService.instance;
    if (storage.savedDeviceName == device.name) return;

    final connectivity = Get.find<ConnectivityService>();
    if (!connectivity.isOnline.value) {
      AppToast.info(
        'This device will be verified with your account once you\'re back online.',
        title: 'Using offline for now',
      );
      return;
    }

    try {
      await _repository.authDevice(device.name);
    } on ApiStatusException catch (e) {
      throw StateError(e.message);
    }
    storage.savedDeviceName = device.name;
  }

  @override
  void onClose() {
    _scanSub?.cancel();
    bluetoothService.stopScan();
    super.onClose();
  }
}
