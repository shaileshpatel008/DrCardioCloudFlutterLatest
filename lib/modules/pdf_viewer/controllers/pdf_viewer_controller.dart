import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../data/models/ecg_record_model.dart';

/// Arguments for opening a cloud-only report (`RemoteReportModel`, which
/// carries no PDF bytes of its own) — matches `PDFViewerActivity`
/// downloading straight from `document_path` when that path is a URL.
class RemotePdfArgs {
  RemotePdfArgs({required this.url, required this.fileName});
  final String url;
  final String fileName;
}

class PdfViewerController extends GetxController {
  EcgRecordModel? _record;
  RemotePdfArgs? _remote;
  final Rxn<Uint8ListWrapper> bytes = Rxn<Uint8ListWrapper>();
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is RemotePdfArgs) {
      _remote = args;
    } else {
      _record = args as EcgRecordModel;
    }
    _load();
  }

  Future<void> _load() async {
    isLoading.value = true;
    final remote = _remote;
    if (remote != null) {
      final response = await DioClient.instance.dio.get<List<int>>(
        remote.url,
        options: Options(responseType: ResponseType.bytes),
      );
      bytes.value = Uint8ListWrapper(Uint8List.fromList(response.data!));
      isLoading.value = false;
      return;
    }

    final record = _record!;
    File file;
    if (record.pdfPath != null && await File(record.pdfPath!).exists()) {
      file = File(record.pdfPath!);
    } else {
      file = await PdfReportService.generate(record);
    }
    bytes.value = Uint8ListWrapper(await file.readAsBytes());
    isLoading.value = false;
  }

  String get fileName => _remote?.fileName ?? '${_record!.patient.name.replaceAll(' ', '_')}_ECG.pdf';

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
