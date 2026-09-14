import 'dart:io';
import 'dart:typed_data';

import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../../../core/services/pdf_report_service.dart';
import '../../../data/models/ecg_record_model.dart';

class PdfViewerController extends GetxController {
  late final EcgRecordModel record;
  final Rxn<Uint8ListWrapper> bytes = Rxn<Uint8ListWrapper>();
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    record = Get.arguments as EcgRecordModel;
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    File file;
    if (record.pdfPath != null && await File(record.pdfPath!).exists()) {
      file = File(record.pdfPath!);
    } else {
      file = await PdfReportService.generate(record);
    }
    bytes.value = Uint8ListWrapper(await file.readAsBytes());
    isLoading.value = false;
  }

  String get fileName => '${record.patient.name.replaceAll(' ', '_')}_ECG.pdf';

  Future<void> share() async {
    final data = bytes.value?.data;
    if (data == null) return;
    await Printing.sharePdf(bytes: data, filename: fileName);
  }

  Future<void> print() async {
    final data = bytes.value?.data;
    if (data == null) return;
    await Printing.layoutPdf(onLayout: (_) async => data);
  }
}

/// Rx doesn't like raw `Uint8List` well when nullable; this tiny wrapper
/// keeps `Rxn` happy without pulling in extra tooling.
class Uint8ListWrapper {
  Uint8ListWrapper(this.data);
  final Uint8List data;
}
