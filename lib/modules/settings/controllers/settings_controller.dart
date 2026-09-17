import 'package:get/get.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/ecg/ecg_data.dart';
import '../../../core/services/ecg/ecg_filter.dart';
import '../../../core/services/storage_service.dart';

class SettingsController extends GetxController {
  final storage = StorageService.instance;

  /// Port of `R.array.spinner_filter`/`spinner_actual_filter`: the original
  /// app's own full 6-option list ('No', '0 to 25 Hz', '0 to 40 Hz',
  /// '5 to 25 Hz', '5 to 40 Hz', '50 Hz Notch') is commented out there too
  /// ("20210121: BARC only 2 options for filter to be shown") in favor of
  /// just these 3 that actually ship. EcgFilter still implements all six —
  /// only the ones offered here are restricted — so re-enabling the rest
  /// later is just adding them back to this list.
  static const filterOptions = ['No', '50 Hz Notch', '0 to 40 Hz'];

  /// `R.array.spinner_gain` / `spinner_actual_gain` — the original app's
  /// full 1/2/3/4/6/8/12 gain list is commented out in favor of this
  /// 3-option one ("20210121: BARC only 3 options for gain to be shown:
  /// 0.5 -> 3, 1 -> 6, 2 -> 12"), which is what actually ships. gainOptions
  /// are display labels; gainActualValues (index-matched) are both the
  /// storage/device-lookup value and the software descale divisor.
  static const gainOptions = ['0.5', '1', '2'];
  static const gainActualValues = [3, 6, 12];

  static const modeOptions = ['ECG', 'Test'];

  /// Port of `R.array.longLeadList` — which of the 12 leads the PDF
  /// report's rhythm strip plots (`SettingsActivity.openLongLeadSelectionDialog()`).
  static const longLeadOptions = EcgData.leadName;

  final RxString filter = ''.obs;
  final RxString gain = ''.obs;
  final RxBool autoSave = true.obs;
  final RxBool autoAssignCardiologist = false.obs;
  final RxInt xAxisScale = 25.obs;
  final RxBool testMode = false.obs;
  final RxString longLead = ''.obs;

  @override
  void onInit() {
    super.onInit();
    filter.value = filterOptions.contains(storage.filter) ? storage.filter : '0 to 40 Hz';
    gain.value = gainOptions.contains(storage.gain) ? storage.gain : '1';
    autoSave.value = storage.autoSave;
    autoAssignCardiologist.value = storage.autoAssignCardiologist;
    xAxisScale.value = storage.xAxisScale;
    testMode.value = storage.testMode;
    longLead.value = longLeadOptions.contains(storage.longLead) ? storage.longLead : 'II';
  }

  void setFilter(String value) {
    filter.value = value;
    storage.filter = value;
    EcgFilter.setFilter(value);
  }

  void setGain(String value) {
    final index = gainOptions.indexOf(value);
    gain.value = value;
    storage.gain = value;
    storage.actualGain = gainActualValues[index].toString();
  }

  void setAutoSave(bool value) {
    autoSave.value = value;
    storage.autoSave = value;
  }

  void setAutoAssignCardiologist(bool value) {
    autoAssignCardiologist.value = value;
    storage.autoAssignCardiologist = value;
  }

  void setXAxisScale(int value) {
    xAxisScale.value = value;
    storage.xAxisScale = value;
  }

  void setLongLead(String value) {
    longLead.value = value;
    storage.longLead = value;
  }

  /// [value] is the display label ('ECG'/'Test'), not the stored bool —
  /// matches the pattern of every other dropdown here (setFilter/setGain
  /// also take the label and translate it).
  void setMode(String value) {
    final isTest = value == 'Test';
    testMode.value = isTest;
    storage.testMode = isTest;
  }

  Future<void> shareDebugLogs() => AppLogger.shareLogFile();
}
