import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/html_text.dart';
import '../../../core/utils/navigation.dart';
import '../../../core/widgets/app_dialogs.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../data/repositories/ecg_repository.dart';
import '../../../routes/app_routes.dart';

/// Cardiologist report editor (web: /ecg/{id}/diagnose).
///  - Save draft -> status stays "requested"
///  - Publish    -> status "reported"; the server builds the report PDF,
///                  merges it with the ECG and notifies the technician.
class DiagnoseController extends GetxController {
  final _repo = EcgRepository();
  late final int id = int.tryParse(Get.parameters['id'] ?? '') ?? 0;

  final record = Rxn<EcgRecord>();
  final templates = <ReportTemplate>[].obs;
  final loading = true.obs;
  final error = RxnString();
  final saving = RxnString(); // 'draft' | 'publish'
  final ecgStatus = RxnString();
  final ecgStatusError = RxnString();

  final advice = TextEditingController();
  final hr = TextEditingController();
  final r = TextEditingController();
  final rr = TextEditingController();
  final pr = TextEditingController();
  final qrs = TextEditingController();
  final qt = TextEditingController();
  final qtc = TextEditingController();
  final qtByQtc = TextEditingController();

  bool _dirty = false;

  @override
  void onInit() {
    super.onInit();
    qt.addListener(_computeRatio);
    qtc.addListener(_computeRatio);
    for (final c in [advice, hr, r, rr, pr, qrs, qt, qtc]) {
      c.addListener(() => _dirty = true);
    }
    load();
  }

  Future<void> load() async {
    loading.value = true;
    error.value = null;
    try {
      final res = await _repo.diagnoseForm(id);
      record.value = res.record;
      templates.assignAll(res.templates);
      final m = res.record.measurements;
      ecgStatus.value = res.record.ecgStatus;
      advice.text = HtmlText.toPlain(res.record.cardiologistReport);
      hr.text = m.hr ?? '';
      r.text = m.r ?? '';
      rr.text = m.rr ?? '';
      pr.text = m.pr ?? '';
      qrs.text = m.qrs ?? '';
      qt.text = m.qt ?? '';
      qtc.text = m.qtc ?? '';
      qtByQtc.text = m.qtByQtc ?? '';
      _dirty = false;
    } on ApiException catch (e) {
      error.value = e.message;
    } finally {
      loading.value = false;
    }
  }

  /// Same formula as the web page: QT / QTc, two decimals.
  void _computeRatio() {
    final a = double.tryParse(qt.text.trim());
    final b = double.tryParse(qtc.text.trim());
    qtByQtc.text = (a != null && b != null && b != 0) ? (a / b).toStringAsFixed(2) : '';
  }

  void setEcgStatus(String v) {
    ecgStatus.value = v;
    ecgStatusError.value = null;
    _dirty = true;
  }

  Future<void> applyTemplate(ReportTemplate t) async {
    if (advice.text.trim().isNotEmpty) {
      final ok = await AppDialogs.confirm(
        title: 'Replace the advice?',
        message: 'Using "${t.title}" replaces the text you have written.',
        confirmLabel: 'Use template',
        danger: false,
        icon: Icons.description_outlined,
      );
      if (!ok) return;
    }
    advice.text = HtmlText.toPlain(t.body);
  }

  Future<void> save({required bool publish}) async {
    if (publish && (ecgStatus.value != 'normal' && ecgStatus.value != 'abnormal')) {
      ecgStatusError.value = 'Please select the ECG status before publishing.';
      AppToast.error('Please select Normal or Abnormal before publishing.');
      return;
    }
    if (publish) {
      final ok = await AppDialogs.confirm(
        title: 'Publish this report?',
        message: 'The report PDF will be generated and attached to the ECG, and the technician will be notified.',
        confirmLabel: 'Publish',
        danger: false,
        icon: Icons.verified_outlined,
      );
      if (!ok) return;
    }
    saving.value = publish ? 'publish' : 'draft';
    try {
      final res = await _repo.diagnose(id, publish: publish, fields: {
        'ecg_status': ecgStatus.value ?? '0',
        'cardiologist_report': HtmlText.toHtml(advice.text),
        'hr': hr.text.trim(),
        'r': r.text.trim(),
        'rr': rr.text.trim(),
        'pr': pr.text.trim(),
        'qrs': qrs.text.trim(),
        'qt': qt.text.trim(),
        'qtc': qtc.text.trim(),
        'qt_by_qtc': qtByQtc.text.trim(),
      });
      _dirty = false;
      AppToast.success(res.message);
      closeRoute(true, AppRoutes.ecgRecords);
    } on ApiException catch (e) {
      ecgStatusError.value = e.errorFor('ecg_status');
      AppToast.error(e.message);
    } finally {
      saving.value = null;
    }
  }

  Future<bool> confirmLeave() async {
    if (!_dirty) return true;
    return AppDialogs.confirm(
      title: 'Discard changes?',
      message: 'You have unsaved changes to this report.',
      confirmLabel: 'Discard',
    );
  }

  @override
  void onClose() {
    for (final c in [advice, hr, r, rr, pr, qrs, qt, qtc, qtByQtc]) {
      c.dispose();
    }
    super.onClose();
  }
}
