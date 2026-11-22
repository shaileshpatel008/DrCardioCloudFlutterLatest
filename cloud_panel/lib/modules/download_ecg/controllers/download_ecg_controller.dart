import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/download/file_saver.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/select_field.dart';
import '../../../data/models/paged.dart';
import '../../../data/repositories/network_repository.dart';

/// "Download ECG": filter, then export a zip of ECG/report PDFs or CSVs.
class DownloadEcgController extends GetxController {
  final _lookups = LookupRepository();
  final _export = ExportRepository();

  final hospital = Rxn<LookupItem>();
  final staff = Rxn<LookupItem>();
  final datePreset = Rxn<DatePreset>();
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();
  final ecgStatus = RxnString();

  final count = RxnInt();
  final counting = false.obs;
  final exporting = RxnString(); // 'pdf' | 'csv'
  final recent = <({String name, String detail, DateTime at})>[].obs;

  Timer? _debounce;

  Map<String, dynamic> get filters {
    final iso = DateFormat('yyyy-MM-dd');
    return {
      'hospital_id': hospital.value?.id,
      'staff_id': staff.value?.id,
      'ecg_status': ecgStatus.value,
      'date_filter': datePreset.value?.apiValue,
      if (datePreset.value == DatePreset.custom && fromDate.value != null) 'from_date': iso.format(fromDate.value!),
      if (datePreset.value == DatePreset.custom && toDate.value != null) 'to_date': iso.format(toDate.value!),
    };
  }

  @override
  void onInit() {
    super.onInit();
    refreshCount();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }

  void _changed() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), refreshCount);
  }

  Future<void> refreshCount() async {
    if (datePreset.value == DatePreset.custom && (fromDate.value == null || toDate.value == null)) return;
    counting.value = true;
    try {
      count.value = await _export.count(filters);
    } catch (_) {
      count.value = null;
    } finally {
      counting.value = false;
    }
  }

  Future<void> pickHospital() async {
    final r = await SelectSheet.pick<LookupItem>(
      title: 'Hospital',
      load: _lookups.hospitals,
      labelOf: (i) => i.name,
      selected: hospital.value,
      allowClear: true,
      clearLabel: 'All hospitals',
    );
    if (r == null) return;
    hospital.value = r.value;
    staff.value = null; // staff list depends on the hospital
    _changed();
  }

  Future<void> pickStaff() async {
    final h = hospital.value;
    if (h == null) {
      AppToast.info('Choose a hospital first to pick its staff.');
      return;
    }
    final r = await SelectSheet.pick<LookupItem>(
      title: 'Staff',
      subtitle: h.name,
      load: () => _lookups.staffs(h.id),
      labelOf: (i) => i.name,
      selected: staff.value,
      allowClear: true,
      clearLabel: 'All staff',
    );
    if (r == null) return;
    staff.value = r.value;
    _changed();
  }

  Future<void> setPreset(BuildContext context, DatePreset? p) async {
    if (p == DatePreset.custom) {
      final now = DateTime.now();
      final range = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2023),
        lastDate: now,
        initialDateRange: DateTimeRange(start: fromDate.value ?? now.subtract(const Duration(days: 6)), end: toDate.value ?? now),
      );
      if (range == null) return;
      fromDate.value = range.start;
      toDate.value = range.end;
    }
    datePreset.value = p;
    _changed();
  }

  void setEcgStatus(String? v) {
    ecgStatus.value = v;
    _changed();
  }

  Future<void> export(String type) async {
    exporting.value = type;
    try {
      final file = await _export.ecg(type, filters);
      final name = file.fileName ?? (type == 'pdf' ? 'ECG_Export.zip' : 'CSV_Export.zip');
      final stamped = name.replaceFirst('.zip', '_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.zip');
      await FileSaver.save(file.bytes, stamped, mimeType: 'application/zip');
      recent.insert(0, (
        name: stamped,
        detail: '${hospital.value?.name ?? 'All hospitals'} · ${datePreset.value?.label ?? 'Any date'}',
        at: DateTime.now(),
      ));
      AppToast.success('$stamped is ready.', title: 'Export complete');
    } on ApiException catch (e) {
      AppToast.error(e.message);
    } finally {
      exporting.value = null;
    }
  }
}
