import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/bluetooth/bluetooth_service.dart';
import '../../../core/services/csv_export_service.dart';
import '../../../core/services/dat_file_service.dart';
import '../../../core/services/ecg/ecg_analysis_service.dart';
import '../../../core/services/ecg/ecg_data.dart';
import '../../../core/services/ecg/ecg_engine.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/widgets/app_confirm_sheet.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../data/models/patient_model.dart';
import '../../../data/repositories/ecg_repository.dart';
import '../../../routes/app_routes.dart';
import '../../../theme/app_colors.dart';
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

  /// Reactive (not `late final`) because Load Data's "Change Patient Data"
  /// option can replace it mid-visit — a fresh recording never changes it
  /// after `onInit`, so this is a no-op extra layer for that flow.
  late final Rx<PatientModel> patient;
  StreamSubscription<int>? _secondsSub;

  /// Set when this screen was opened from Load Data (Get.arguments is the
  /// saved [EcgRecordModel] instead of a bare [PatientModel]) — port of
  /// `NewEcgActivity.checkFromLoadData()`: the 12-lead charts are filled
  /// from the record's already-captured, already-filtered samples instead
  /// of a live BLE stream, so there's nothing to Start/Stop, and Save
  /// regenerates the report in place rather than creating a new recording.
  EcgRecordModel? loadedRecord;
  bool get isLoadedMode => loadedRecord != null;

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

  /// Loaded data has no `rawDataCount` of its own (it's already-filtered
  /// samples, not a raw stream) and no minimum-duration gate to satisfy —
  /// the record was already long enough to have been saved once.
  bool get canSave => isLoadedMode ? !isSaving.value : (!isReading.value && !isSaving.value && recordedSeconds >= minRecordingSeconds);

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
    final args = Get.arguments;
    engine = EcgEngine(bluetoothService);
    _secondsSub = engine.onSecondTick.listen((s) => elapsedSeconds.value = s);

    final storage = StorageService.instance;
    isTestMode = storage.testMode;

    if (args is EcgRecordModel) {
      loadedRecord = args;
      patient = args.patient.obs;
      _loadIntoChart(args);
    } else {
      patient = (args as PatientModel).obs;
      // Port of `NewEcgActivity.checkFromLoadData()`'s fresh-recording
      // branch, which calls `setGain(settings.gain)` — both telling the
      // device which hardware gain to use for this session (it doesn't
      // remember this across connections/power cycles) and setting the
      // chart display scale to match.
      EcgData.instance.graphScale = double.tryParse(storage.gain) ?? 1;
      final actualGain = int.tryParse(storage.actualGain);
      if (actualGain != null) bluetoothService.sendGain(actualGain);
    }
  }

  /// Port of `ecgData.parseInfo()`/`mFile.readDatFile()`'s chart-filling
  /// half — the record's samples are already down-sampled and filtered
  /// (this app stores `chartData` directly, not raw ADC counts), so this
  /// is just a copy into the singleton the chart widgets read, followed by
  /// one manual `revision` bump so they actually repaint with it (nothing
  /// else will — there's no live packet stream driving it in this mode).
  void _loadIntoChart(EcgRecordModel record) {
    final ecg = EcgData.instance;
    for (var ch = 0; ch < EcgData.noOfChannels; ch++) {
      ecg.chartData[ch]
        ..clear()
        ..addAll(ch < record.leadData.length ? record.leadData[ch] : const []);
    }
    ecg.deviceName = record.deviceName;
    ecg.graphScale = double.tryParse(record.gain) ?? 1;
    engine.revision.value++;
  }

  /// Port of the "Patient Data" menu item's edit flow — opens the same
  /// Patient Details form pre-filled with the current values.
  /// `PatientInfoController.continueToRecording()`'s edit-mode branch
  /// writes the edited patient straight into [patient] (this controller is
  /// still registered underneath while that screen is pushed on top) and
  /// pops back, rather than routing the value back through a typed
  /// `Get.back(result:)`/`Get.toNamed<T>()` round trip.
  ///
  /// Wrapped in try/catch (unlike a plain fire-and-forget navigation)
  /// specifically so a failure here is never silent: this button has no
  /// other feedback affordance (no progress spinner, no disabled state),
  /// so an uncaught error would just look like the tap did nothing.
  Future<void> changePatientData() async {
    try {
      await Get.toNamed(AppRoutes.patientInfo, arguments: patient.value);
    } catch (e, st) {
      AppLogger.e('Could not open Patient Details from Load Data', e, st);
      AppToast.error('Could not open patient details. Please try again.');
    }
  }

  @override
  void onReady() {
    super.onReady();
    // Port of `NewEcgActivity.showTestModePopup()` — a one-time, must-
    // acknowledge notice so a fixed calibration waveform is never mistaken
    // for a patient's real ECG. Meaningless for already-captured data, so
    // skipped in loaded mode.
    if (isTestMode && !isLoadedMode) {
      AppConfirmSheet.show(
        Get.context!,
        icon: Icons.science_outlined,
        title: 'Test Mode',
        message: "This device is set to Test Mode. The waveform shown is the device's built-in fixed "
            "calibration signal, not a real ECG — switch to ECG Mode in Settings to acquire from a patient.",
        confirmText: 'OK',
        cancelText: null,
        confirmColor: AppColors.ink,
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
      var record = await _buildRecordToSave();

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
      // Returns immediately while offline (ConnectivityService gate inside
      // syncPendingQueue), so this never blocks getting to the report —
      // same as the original, which always writes the PDF/dat/csv first
      // and opens the viewer regardless of connectivity or upload result.
      await _repository.syncPendingQueue();
      // Port of `NewEcgActivity.generateReport()` -> `openGeneratedPDF()`:
      // the original opens the just-written PDF straight from disk rather
      // than returning to the main screen, and does this unconditionally
      // (no network involved) — PdfViewerController already prefers
      // record.pdfPath, which was just written above, so this works fully
      // offline the same way. Replaces this screen (not a plain push) so
      // Back from the viewer returns to wherever this screen was opened
      // from, not back into a finished recording/edit session.
      Get.offNamed(AppRoutes.pdfViewer, arguments: record);
      AppToast.success(isLoadedMode ? 'Report updated for ${patient.value.name}.' : 'Recording saved for ${patient.value.name}.');
    } finally {
      isSaving.value = false;
    }
  }

  /// Loaded mode reuses the existing record's id/dateTime/leadData (so
  /// `saveLocally`'s `ConflictAlgorithm.replace` updates the same row in
  /// place instead of creating a duplicate) with just the patient info
  /// possibly edited via [changePatientData] — matching the original's
  /// `checkFromLoadData()` regenerating the report from the same
  /// `ecgData.date_time`/samples rather than starting a fresh capture. A
  /// fresh recording builds the record from scratch from the live buffer,
  /// same as before this mode existed.
  Future<EcgRecordModel> _buildRecordToSave() async {
    if (isLoadedMode) {
      return loadedRecord!.copyWith(patient: patient.value, syncStatus: SyncStatus.pending);
    }
    final ecg = EcgData.instance;
    final storage = StorageService.instance;
    final position = await _tryGetLocation();

    // Port of NewEcgActivity.generateReport()'s ECGAnalysis pass — must run
    // here, against the live EcgData.filteredData buffer, and not later:
    // that buffer is full-resolution (500Hz) and gets reset by the next
    // recording, whereas the leadData saved below is down-sampled 10x for
    // charting/storage and would give this algorithm the wrong sample rate.
    final analysis = EcgAnalysisService.analyze(
      filteredData: ecg.filteredData,
      rawDataCount: ecg.rawDataCount,
      leadArrange: EcgData.leadArrange,
      valPerMv: ecg.valPerMv,
    );

    return EcgRecordModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      dateTime: DateTime.now(),
      patient: patient.value,
      deviceName: ecg.deviceName ?? '',
      filter: storage.filter,
      gain: storage.gain,
      leadData: ecg.chartData.map((l) => List<double>.from(l)).toList(),
      deviceId: storage.savedDeviceName,
      latitude: position?.latitude.toString() ?? '',
      longitude: position?.longitude.toString() ?? '',
      hr: analysis == null ? '' : analysis.heartRateBpm.toString(),
      r: analysis == null ? '' : _formatMeasurement(analysis.rAmplitudeMv),
      rr: analysis == null ? '' : analysis.rrIntervalMs.toString(),
      pr: analysis == null ? '' : analysis.prIntervalMs.toString(),
      qrs: analysis == null ? '' : analysis.qrsDurationMs.toString(),
      qt: analysis == null ? '' : analysis.qtIntervalMs.toString(),
      qtc: analysis == null ? '' : analysis.qtcMs.toString(),
      qtByQtc: analysis == null ? '' : _formatMeasurement(analysis.qtOverQtc),
    );
  }

  /// Matches `PdfGenerator.getEcgAnalysis()`'s `new DecimalFormat()` default
  /// formatting for R(II) and QT/QTc — up to 2 fraction digits, trailing
  /// zeros (and a trailing bare decimal point) trimmed.
  static String _formatMeasurement(double value) {
    var text = value.toStringAsFixed(2);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '');
      text = text.replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
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
