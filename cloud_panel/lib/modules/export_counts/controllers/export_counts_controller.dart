import 'package:get/get.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/download/file_saver.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/repositories/network_repository.dart';

/// Cardiologist: monthly CSV of reported ECGs (hospital, patient name, age,
/// gender, patient ID, report date) — web "Export ECG Counts".
class ExportCountsController extends GetxController {
  final _export = ExportRepository();

  final month = DateTime.now().month.obs;
  final year = DateTime.now().year.obs;
  final exporting = false.obs;

  List<int> get years {
    final now = DateTime.now().year;
    return [for (var y = now - 5; y <= now + 1; y++) y];
  }

  String get monthLabel => AppConstants.months[month.value - 1];

  Future<void> export() async {
    exporting.value = true;
    try {
      final mm = month.value.toString().padLeft(2, '0');
      final file = await _export.ecgCounts(mm, '${year.value}');
      final name = 'ECG_Counts_${monthLabel}_${year.value}.csv';
      await FileSaver.save(file.bytes, name, mimeType: 'text/csv');
      AppToast.success('$name is ready.', title: 'Export complete');
    } on ApiException catch (e) {
      AppToast.error(e.message);
    } finally {
      exporting.value = false;
    }
  }
}
