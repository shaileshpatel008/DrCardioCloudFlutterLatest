import 'package:get/get.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/ecg/ecg_filter.dart';
import '../../../core/services/storage_service.dart';

class SettingsController extends GetxController {
  final storage = StorageService.instance;

  static const filterOptions = ['No', '0 to 25 Hz', '0 to 40 Hz', '5 to 25 Hz', '5 to 40 Hz', '50 Hz Notch'];

  /// `R.array.spinner_gain` / `spinner_actual_gain` — the original app's
  /// full 1/2/3/4/6/8/12 gain list is commented out in favor of this
  /// 3-option one ("20210121: BARC only 3 options for gain to be shown:
  /// 0.5 -> 3, 1 -> 6, 2 -> 12"), which is what actually ships. gainOptions
  /// are display labels; gainActualValues (index-matched) are both the
  /// storage/device-lookup value and the software descale divisor.
  static const gainOptions = ['0.5', '1', '2'];
  static const gainActualValues = [3, 6, 12];

  final RxString filter = ''.obs;
  final RxString gain = ''.obs;
  final RxBool autoSave = true.obs;
  final RxBool autoAssignCardiologist = false.obs;
  final RxInt xAxisScale = 25.obs;

  @override
  void onInit() {
    super.onInit();
    filter.value = filterOptions.contains(storage.filter) ? storage.filter : '0 to 40 Hz';
    gain.value = gainOptions.contains(storage.gain) ? storage.gain : '1';
    autoSave.value = storage.autoSave;
    autoAssignCardiologist.value = storage.autoAssignCardiologist;
    xAxisScale.value = storage.xAxisScale;
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

  Future<void> shareDebugLogs() => AppLogger.shareLogFile();
}
