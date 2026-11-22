import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/base/paged_list_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/widgets/select_field.dart';
import '../../../data/models/ecg_filters.dart';
import '../../../data/models/ecg_record_model.dart';
import '../../../data/models/paged.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/ecg_repository.dart';
import '../../../data/repositories/network_repository.dart';
import '../../../routes/app_routes.dart';
import '../ecg_actions.dart';

class EcgRecordsController extends PagedListController<EcgRecord> {
  final _repo = EcgRepository();
  final _lookups = LookupRepository();

  final filters = const EcgFilters().obs;
  final summary = const EcgSummary().obs;
  Timer? _autoRefresh;

  UserModel? get user => Get.find<AuthService>().current;
  bool get isAdminSide => user?.isAdminSide ?? false;
  bool get isCardiologist => user?.isCardiologist ?? false;

  /// Status tabs: the admin side has all four statuses; clients and
  /// cardiologists see Requested / Reported (the web "status_filter").
  List<ReportStatus?> get tabs => isAdminSide
      ? const [null, ReportStatus.pending, ReportStatus.requested, ReportStatus.reported, ReportStatus.noCredit]
      : const [null, ReportStatus.requested, ReportStatus.reported];

  @override
  void onInit() {
    final p = Get.parameters;
    var f = const EcgFilters();
    if (p['status'] != null) f = f.copyWith(status: reportStatusFrom(p['status']));
    if (p['ecg_status'] != null) f = f.copyWith(ecgStatus: p['ecg_status']);
    if (p['search'] != null) search.value = p['search']!;
    final hid = int.tryParse(p['hospital_id'] ?? '');
    if (hid != null) f = f.copyWith(hospital: LookupItem(hid, p['hospital_name'] ?? 'Hospital'));
    filters.value = f;
    super.onInit();
    loadSummary();
    _autoRefresh = Timer.periodic(AppConstants.ecgListAutoRefresh, (_) {
      refreshList();
      loadSummary();
    });
  }

  @override
  void onClose() {
    _autoRefresh?.cancel();
    super.onClose();
  }

  @override
  Future<Paged<EcgRecord>> fetch(ListQuery query) => _repo.list(
        filters.value.copyWith(search: query.search),
        page: query.page,
        perPage: query.perPage,
        sort: query.sort ?? 'date',
        dir: query.dir,
      );

  Future<void> loadSummary() async {
    try {
      summary.value = await _repo.summary(filters.value.copyWith(search: search.value));
    } catch (_) {}
  }

  void _apply(EcgFilters f) {
    filters.value = f;
    load(toPage: 1);
    loadSummary();
  }

  @override
  void setSearch(String value) {
    super.setSearch(value);
    loadSummary();
  }

  Future<void> reload() async {
    await load(silent: true);
    await loadSummary();
  }

  void setTab(ReportStatus? s) {
    if (filters.value.status == s) return;
    filters.value = filters.value.copyWith(status: s);
    load(toPage: 1);
  }

  void clearAll() => _apply(EcgFilters(status: filters.value.status));

  void clearHospital() => _apply(filters.value.copyWith(hospital: null, staff: null, device: null));
  void clearStaff() => _apply(filters.value.copyWith(staff: null));
  void clearDevice() => _apply(filters.value.copyWith(device: null));
  void clearCardiologist() => _apply(filters.value.copyWith(cardiologist: null));
  void clearEcgStatus() => _apply(filters.value.copyWith(ecgStatus: null));
  void clearDate() => _apply(filters.value.copyWith(datePreset: null, fromDate: null, toDate: null));

  Future<void> pickHospital() async {
    final r = await SelectSheet.pick<LookupItem>(
      title: 'Hospital',
      load: _lookups.hospitals,
      labelOf: (i) => i.name,
      selected: filters.value.hospital,
      allowClear: true,
      clearLabel: 'All hospitals',
    );
    if (r == null) return;
    // Staff and device lists depend on the hospital, like the web filters.
    _apply(filters.value.copyWith(hospital: r.value, staff: null, device: null));
  }

  Future<void> pickStaff() async {
    final h = filters.value.hospital;
    if (h == null) return;
    final r = await SelectSheet.pick<LookupItem>(
      title: 'Staff',
      subtitle: h.name,
      load: () => _lookups.staffs(h.id),
      labelOf: (i) => i.name,
      selected: filters.value.staff,
      allowClear: true,
      clearLabel: 'All staff',
    );
    if (r != null) _apply(filters.value.copyWith(staff: r.value));
  }

  Future<void> pickDevice() async {
    final h = filters.value.hospital;
    if (h == null) return;
    final r = await SelectSheet.pick<LookupItem>(
      title: 'Device',
      subtitle: h.name,
      load: () => _lookups.devices(h.id),
      labelOf: (i) => i.name,
      selected: filters.value.device,
      allowClear: true,
      clearLabel: 'All devices',
    );
    if (r != null) _apply(filters.value.copyWith(device: r.value));
  }

  Future<void> pickCardiologist() async {
    final r = await SelectSheet.pick<LookupItem>(
      title: 'Cardiologist',
      load: _lookups.cardiologists,
      labelOf: (i) => i.name,
      selected: filters.value.cardiologist,
      allowClear: true,
      clearLabel: 'All cardiologists',
    );
    if (r != null) _apply(filters.value.copyWith(cardiologist: r.value));
  }

  Future<void> pickEcgStatus() async {
    const options = [LookupItem(1, 'Normal'), LookupItem(2, 'Abnormal')];
    final current = switch (filters.value.ecgStatus) { 'normal' => options[0], 'abnormal' => options[1], _ => null };
    final r = await SelectSheet.pick<LookupItem>(
      title: 'ECG status',
      load: () async => options,
      labelOf: (i) => i.name,
      selected: current,
      allowClear: true,
      clearLabel: 'Any ECG status',
    );
    if (r == null) return;
    _apply(filters.value.copyWith(ecgStatus: r.value?.name.toLowerCase()));
  }

  Future<void> pickDate(BuildContext context) async {
    final presets = DatePreset.values.map((p) => LookupItem(p.index, p.label)).toList();
    final current = filters.value.datePreset == null ? null : presets[filters.value.datePreset!.index];
    final r = await SelectSheet.pick<LookupItem>(
      title: 'Date',
      load: () async => presets,
      labelOf: (i) => i.name,
      selected: current,
      allowClear: true,
      clearLabel: 'Any date',
    );
    if (r == null) return;
    if (r.value == null) {
      clearDate();
      return;
    }
    final preset = DatePreset.values[r.value!.id];
    if (preset != DatePreset.custom) {
      _apply(filters.value.copyWith(datePreset: preset, fromDate: null, toDate: null));
      return;
    }
    if (!context.mounted) return;
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: now,
      initialDateRange: DateTimeRange(start: filters.value.fromDate ?? now.subtract(const Duration(days: 6)), end: filters.value.toDate ?? now),
      helpText: 'Select ECG dates',
    );
    if (range != null) {
      _apply(filters.value.copyWith(datePreset: DatePreset.custom, fromDate: range.start, toDate: range.end));
    }
  }

  // Row actions -----------------------------------------------------------

  Future<void> openDetail(EcgRecord r) async {
    await Get.toNamed(AppRoutes.ecgDetailPath(r.id));
    reload();
  }

  Future<void> openDiagnose(EcgRecord r) async {
    final changed = await Get.toNamed(AppRoutes.diagnosePath(r.id));
    if (changed == true) reload();
  }

  Future<void> delete(EcgRecord r) async {
    if (await EcgRecordActions.delete(r)) reload();
  }

  Future<void> reassign(EcgRecord r) async {
    if (await EcgRecordActions.reassign(r)) reload();
  }

  Future<void> assign(EcgRecord r) async {
    if (await EcgRecordActions.assign(r)) reload();
  }
}
