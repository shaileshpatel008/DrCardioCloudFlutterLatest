import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../core/services/csv_export_service.dart';
import '../../../core/services/dat_file_service.dart';
import '../../../core/services/ecg/ecg_data.dart';
import '../../../core/services/ecg/ecg_engine.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../data/models/patient_model.dart';
import '../../../data/repositories/ecg_repository.dart';
import '../../../routes/app_routes.dart';
import '../../settings/controllers/settings_controller.dart';
import 'package:flutter/foundation.dart';

class LiveEcgController extends GetxController {
  LiveEcgController({EcgRepository? repository}) : _repository = repository ?? EcgRepository();

  /// Port of `NewEcgActivity.min_saved_seconds` — the shortest recording
  /// the original ever lets you save; below this it just shows a toast on
  /// Stop instead of enabling Save.
  static const minRecordingSeconds = 20;

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
  ValueNotifier<int?> get heartRateBpm => engine.heartRateBpm;

  /// Total ECG actually captured this screen visit, in seconds —
  /// cumulative across separate Start/Stop attempts (a Stop before 20s
  /// followed by another Start keeps counting rather than resetting),
  /// matching the original's own `rawDataCount / sampleRatePerSec` check,
  /// which never resets on a fresh Start either. [elapsedSeconds] resets
  /// every Start on purpose — it's "how long has this attempt run", a
  /// different, purely cosmetic number shown in the header timer chip.
  int get recordedSeconds => EcgData.instance.rawDataCount ~/ EcgData.instance.sampleRatePerSec;

  bool get canSave => !isReading.value && !isSaving.value && recordedSeconds >= minRecordingSeconds;

  /// 0 once [canSave] is true; counts down the seconds still needed so the
  /// Save button's progress ring has something to animate toward.
  int get secondsUntilSaveReady => (minRecordingSeconds - recordedSeconds).clamp(0, minRecordingSeconds);

  /// Port of `settings.test_mode`: true acquires the device's built-in
  /// fixed calibration waveform (`CMD_TEST_START`) instead of the
  /// patient's real signal (`CMD_START`) — read once per screen the same
  /// way gain/filter are, since switching it mid-recording isn't a
  /// supported flow in the original either.
  late final bool isTestMode;

  @override
  void onInit() {
    super.onInit();
    patient = Get.arguments as PatientModel;
    engine = EcgEngine(bluetoothService);
    _secondsSub = engine.onSecondTick.listen((s) => elapsedSeconds.value = s);

    final storage = StorageService.instance;
    isTestMode = storage.testMode;

    // Port of `NewEcgActivity.checkFromLoadData()`'s fresh-recording
    // branch, which calls `setGain(settings.gain)` — both telling the
    // device which hardware gain to use for this session (it doesn't
    // remember this across connections/power cycles) and setting the
    // chart display scale to match.
    EcgData.instance.graphScale = double.tryParse(storage.gain) ?? 1;
    final actualGain = int.tryParse(storage.actualGain);
    if (actualGain != null) bluetoothService.sendGain(actualGain);
  }

  @override
  void onReady() {
    super.onReady();
    // Port of `NewEcgActivity.showTestModePopup()` — a one-time, must-
    // acknowledge notice so a fixed calibration waveform is never mistaken
    // for a patient's real ECG.
    if (isTestMode) {
      Get.dialog(
        AlertDialog(
          title: const Text('Test Mode'),
          content: const Text(
            "This device is set to Test Mode. The waveform shown is the device's built-in fixed "
            "calibration signal, not a real ECG — switch to ECG Mode in Settings to acquire from a patient.",
          ),
          actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
        ),
      );
    }
  }

  void startRecording() {
    EcgData.instance.isReading = true;
    isReading.value = true;
    elapsedSeconds.value = 0;
    engine.resetHeartRate();
    if (isTestMode) {
      bluetoothService.sendTestStart();
    } else {
      bluetoothService.sendStart();
    }
  }

  void stopRecording() {
    bluetoothService.sendStop();
    EcgData.instance.isReading = false;
    isReading.value = false;
    if (!canSave) {
      AppToast.warning('Need to acquire for at least $minRecordingSeconds seconds.', title: 'Recording too short');
    }
  }

  /// Applied immediately: `EcgFilter.filter()`/`highPassFilter()` read the
  /// persisted filter on every sample, so this takes effect on the very
  /// next one, same as the original's always-available toolbar menu.
  void changeFilter(String label) => Get.find<SettingsController>().setFilter(label);

  /// Unlike filter, gain is partly hardware-side: `sendGain` re-arms the
  /// device's analog front-end, and `graphScale` re-scales the chart to
  /// match, matching what `onInit` does for the gain already selected
  /// when this screen opens.
  void changeGain(String label) {
    Get.find<SettingsController>().setGain(label);
    EcgData.instance.graphScale = double.tryParse(label) ?? 1;
    final actualGain = int.tryParse(StorageService.instance.actualGain);
    if (actualGain != null) bluetoothService.sendGain(actualGain);
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

      // All exports are written to local storage first, unconditionally —
      // same as the original (`NewEcgActivity.generateReport()` always
      // writes .dat/.csv/.pdf/Filtered-Data before ever checking
      // connectivity). Uploading is a separate, best-effort step below.
      final pdfFile = await PdfReportService.generate(record);
      final csvFile = await CsvExportService.generate(record);
      final filteredCsvFile = await CsvExportService.generateFiltered(record);
      final datFile = await DatFileService.generate(record);
      record = record.copyWith(
        pdfPath: pdfFile.path,
        csvPath: csvFile.path,
        datPath: datFile.path,
        filteredCsvPath: filteredCsvFile.path,
      );

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
