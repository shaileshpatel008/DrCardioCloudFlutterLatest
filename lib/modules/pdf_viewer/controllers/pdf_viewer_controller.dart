import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:get/get.dart';
import 'package:pdfx/pdfx.dart';
import 'package:printing/printing.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/services/app_logger.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/services/record_file_naming.dart';
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
  final RxnString error = RxnString();

  /// Owns the pinch-zoom/page-scroll state for [PdfViewPinch]. Rebuilt
  /// fresh on every [_load]/[retry] rather than reused, since `pdfx`
  /// controllers are tied to one document load. `Rxn` (not a plain
  /// field) so the AppBar's page-number indicator actually notices the
  /// null-to-loaded transition instead of staying hidden forever.
  final Rxn<PdfControllerPinch> pdfController = Rxn<PdfControllerPinch>();

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

  Future<void> retry() => _load();

  Future<void> _load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final Uint8List data;
      final remote = _remote;
      if (remote != null) {
        final response = await DioClient.instance.dio.get<List<int>>(
          remote.url,
          options: Options(responseType: ResponseType.bytes),
        );
        data = Uint8List.fromList(response.data!);
      } else {
        final record = _record!;
        File file;
        if (record.pdfPath != null && await File(record.pdfPath!).exists()) {
          file = File(record.pdfPath!);
        } else {
          file = await PdfReportService.generate(record);
        }
        data = await file.readAsBytes();
      }

      bytes.value = Uint8ListWrapper(data);
      pdfController.value?.dispose();
      pdfController.value = PdfControllerPinch(document: PdfDocument.openData(data));
    } catch (e, st) {
      AppLogger.e('Failed to load PDF for viewer ($fileName)', e, st);
      error.value = 'Could not load this PDF.';
    } finally {
      isLoading.value = false;
    }
  }

  // Same name a saved record's file already has on disk/on the server
  // (see RecordFileNaming) — so the title bar, a share sheet, and the
  // actual file on device all agree instead of showing three different
  // names for the same recording.
  String get fileName => _remote?.fileName ?? '${RecordFileNaming.stem(_record!)}.pdf';

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

  @override
  void onClose() {
    pdfController.value?.dispose();
    super.onClose();
  }
}

/// Rx doesn't like raw `Uint8List` well when nullable; this tiny wrapper
/// keeps `Rxn` happy without pulling in extra tooling.
class Uint8ListWrapper {
  Uint8ListWrapper(this.data);
  final Uint8List data;
}
