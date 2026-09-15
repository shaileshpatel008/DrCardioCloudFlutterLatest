import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../core/services/csv_export_service.dart';
import '../../../core/services/ecg/ecg_data.dart';
import '../../../core/services/ecg/ecg_engine.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../data/models/patient_model.dart';
import '../../../data/repositories/ecg_repository.dart';
import '../../../routes/app_routes.dart';
import 'package:flutter/foundation.dart';

class LiveEcgController extends GetxController {
  LiveEcgController({EcgRepository? repository}) : _repository = repository ?? EcgRepository();

  final BluetoothService bluetoothService = Get.find<BluetoothService>();
  final EcgRepository _repository;
  late final EcgEngine engine;

  late final PatientModel patient;
  StreamSubscription<int>? _secondsSub;

  final RxInt elapsedSeconds = 0.obs;
  final RxBool isReading = false.obs;
  final RxBool isSaving = false.obs;
  ValueNotifier<int> get revision => engine.revision;
  ValueNotifier<List<bool>> get leadStatus => EcgData.instance.leadStatus;

  @override
  void onInit() {
    super.onInit();
    patient = Get.arguments as PatientModel;
    engine = EcgEngine(bluetoothService);
    _secondsSub = engine.onSecondTick.listen((s) => elapsedSeconds.value = s);

    // Port of `NewEcgActivity.checkFromLoadData()`'s fresh-recording
    // branch, which calls `setGain(settings.gain)` — both telling the
    // device which hardware gain to use for this session (it doesn't
    // remember this across connections/power cycles) and setting the
    // chart display scale to match.
    final storage = StorageService.instance;
    EcgData.instance.graphScale = double.tryParse(storage.gain) ?? 1;
    final actualGain = int.tryParse(storage.actualGain);
    if (actualGain != null) bluetoothService.sendGain(actualGain);
  }

  void startRecording() {
    EcgData.instance.isReading = true;
    isReading.value = true;
    elapsedSeconds.value = 0;
    bluetoothService.sendStart();
  }

  void stopRecording() {
    bluetoothService.sendStop();
    EcgData.instance.isReading = false;
    isReading.value = false;
  }

  Future<void> saveAndExit() async {
    isSaving.value = true;
    try {
      final ecg = EcgData.instance;
      final storage = StorageService.instance;
      final position = await _tryGetLocation();
      var record = EcgRecordModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        dateTime: DateTime.now(),
        patient: patient,
        deviceName: ecg.deviceName ?? '',
        filter: storage.filter,
        gain: storage.gain,
        leadData: ecg.chartData.map((l) => List<double>.from(l)).toList(),
        deviceId: storage.savedDeviceName,
        latitude: position?.latitude.toString() ?? '',
        longitude: position?.longitude.toString() ?? '',
      );

      final pdfFile = await PdfReportService.generate(record);
      final csvFile = await CsvExportService.generate(record);
      record = record.copyWith(pdfPath: pdfFile.path, csvPath: csvFile.path);

      await _repository.saveLocally(record);
      await _repository.syncPendingQueue();
      Get.offAllNamed(AppRoutes.home);
      AppToast.success('Recording saved for ${patient.name}.');
    } finally {
      isSaving.value = false;
    }
  }

  /// Best-effort location tag for the upload payload's latitude/longitude
  /// fields — never blocks saving the recording if permission is denied
  /// or location is unavailable.
  Future<Position?> _tryGetLocation() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.reduced, timeLimit: Duration(seconds: 5)),
      );
    } catch (e, st) {
      AppLogger.w('Could not get location for recording', e, st);
      return null;
    }
  }

  @override
  void onClose() {
    if (EcgData.instance.isReading) {
      bluetoothService.sendStop();
      EcgData.instance.isReading = false;
    }
    _secondsSub?.cancel();
    engine.dispose();
    super.onClose();
  }
}
