import 'package:intl/intl.dart';

import '../../core/constants/app_constants.dart';
import 'ecg_record_model.dart';
import 'paged.dart';

/// Every filter the ECG Records and Download ECG screens offer, mapped to
/// the API query parameters.
class EcgFilters {
  const EcgFilters({
    this.hospital,
    this.staff,
    this.device,
    this.cardiologist,
    this.status,
    this.ecgStatus,
    this.datePreset,
    this.fromDate,
    this.toDate,
    this.search = '',
  });

  final LookupItem? hospital;
  final LookupItem? staff;
  final LookupItem? device;
  final LookupItem? cardiologist;
  final ReportStatus? status;
  final String? ecgStatus; // normal | abnormal
  final DatePreset? datePreset;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String search;

  static const _keep = Object();

  EcgFilters copyWith({
    Object? hospital = _keep,
    Object? staff = _keep,
    Object? device = _keep,
    Object? cardiologist = _keep,
    Object? status = _keep,
    Object? ecgStatus = _keep,
    Object? datePreset = _keep,
    Object? fromDate = _keep,
    Object? toDate = _keep,
    String? search,
  }) {
    return EcgFilters(
      hospital: identical(hospital, _keep) ? this.hospital : hospital as LookupItem?,
      staff: identical(staff, _keep) ? this.staff : staff as LookupItem?,
      device: identical(device, _keep) ? this.device : device as LookupItem?,
      cardiologist: identical(cardiologist, _keep) ? this.cardiologist : cardiologist as LookupItem?,
      status: identical(status, _keep) ? this.status : status as ReportStatus?,
      ecgStatus: identical(ecgStatus, _keep) ? this.ecgStatus : ecgStatus as String?,
      datePreset: identical(datePreset, _keep) ? this.datePreset : datePreset as DatePreset?,
      fromDate: identical(fromDate, _keep) ? this.fromDate : fromDate as DateTime?,
      toDate: identical(toDate, _keep) ? this.toDate : toDate as DateTime?,
      search: search ?? this.search,
    );
  }

  bool get hasAny =>
      hospital != null ||
      staff != null ||
      device != null ||
      cardiologist != null ||
      ecgStatus != null ||
      datePreset != null ||
      search.isNotEmpty;

  String get dateLabel {
    if (datePreset == null) return 'Any date';
    if (datePreset == DatePreset.custom && fromDate != null && toDate != null) {
      final f = DateFormat('d MMM');
      final y = DateFormat('d MMM yyyy');
      return '${f.format(fromDate!)} – ${y.format(toDate!)}';
    }
    return datePreset!.label;
  }

  Map<String, dynamic> toQuery({bool includeStatus = true}) {
    final iso = DateFormat('yyyy-MM-dd');
    return {
      'hospital_id': hospital?.id,
      'staff_id': staff?.id,
      'device_id': device?.id,
      'cardiologist_id': cardiologist?.id,
      if (includeStatus) 'status': status?.apiValue,
      'ecg_status': ecgStatus,
      'date_filter': datePreset?.apiValue,
      if (datePreset == DatePreset.custom && fromDate != null) 'from_date': iso.format(fromDate!),
      if (datePreset == DatePreset.custom && toDate != null) 'to_date': iso.format(toDate!),
      'search': search.trim(),
    };
  }
}
