import 'package:get/get.dart';

import '../../../core/services/app_logger.dart';
import '../../../core/services/ecg/ecg_filter.dart';
import '../../../core/services/storage_service.dart';

class SettingsController extends GetxController {
  final storage = StorageService.instance;

  static const filterOptions = ['No', '0 to 25 Hz', '0 to 40 Hz', '5 to 25 Hz', '5 to 40 Hz', '50 Hz Notch'];
  static const gainOptions = ['x1', 'x2', 'x4', 'x6', 'x8', 'x12'];
  static const gainActualValues = [1, 2, 4, 6, 8, 12];

  final RxString filter = ''.obs;
  final RxString gain = ''.obs;
  final RxBool autoSave = true.obs;
  final RxBool autoAssignCardiologist = false.obs;
  final RxInt xAxisScale = 25.obs;

  @override
  void onInit() {
    super.onInit();
    filter.value = filterOptions.contains(storage.filter) ? storage.filter : '0 to 40 Hz';
    gain.value = gainOptions.contains(storage.gain) ? storage.gain : 'x6';
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
