import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/app_dialogs.dart';
import '../../core/widgets/app_toast.dart';
import '../../core/widgets/select_field.dart';
import '../../data/models/ecg_record_model.dart';
import '../../data/models/paged.dart';
import '../../data/repositories/ecg_repository.dart';
import '../../data/repositories/network_repository.dart';

/// ECG row actions shared by the list and the detail screen. Each returns
/// true when the record changed and the caller should reload.
class EcgRecordActions {
  EcgRecordActions._();

  static final _repo = EcgRepository();
  static final _lookups = LookupRepository();

  static Future<bool> delete(EcgRecord r) async {
    final ok = await AppDialogs.confirm(
      title: 'Delete this ECG record?',
      message: '${r.fileName} and its cardiologist report will be removed for everyone. This can\'t be undone.',
    );
    if (!ok) return false;
    try {
      AppToast.success(await _repo.delete(r.id));
      return true;
    } on ApiException catch (e) {
      AppToast.error(e.message);
      return false;
    }
  }

  static Future<bool> reassign(EcgRecord r) async {
    final picked = await SelectSheet.pick<LookupItem>(
      title: 'Re-assign cardiologist',
      subtitle: r.fileName,
      load: _lookups.cardiologists,
      labelOf: (i) => r.cardiologistId == i.id ? '${i.name}  (current)' : i.name,
      selected: r.cardiologistId == null ? null : LookupItem(r.cardiologistId!, r.cardiologistName ?? ''),
    );
    final c = picked?.value;
    if (c == null || c.id == r.cardiologistId) return false;
    final ok = await AppDialogs.confirm(
      title: 'Re-assign to ${c.name}?',
      message: 'The ECG moves to ${c.name}\'s worklist and they are notified.',
      confirmLabel: 'Re-assign',
      danger: false,
      icon: Icons.swap_horiz_rounded,
    );
    if (!ok) return false;
    try {
      AppToast.success(await _repo.reassign(r.id, c.id));
      return true;
    } on ApiException catch (e) {
      AppToast.error(e.message);
      return false;
    }
  }

  static Future<bool> assign(EcgRecord r) async {
    final ok = await AppDialogs.confirm(
      title: 'Send to the cardiologist?',
      message: 'This ECG was not sent for reporting because the client had no credit. Send it to the client\'s cardiologist now?',
      confirmLabel: 'Send for report',
      danger: false,
      icon: Icons.send_rounded,
    );
    if (!ok) return false;
    try {
      AppToast.success(await _repo.assign(r.id));
      return true;
    } on ApiException catch (e) {
      AppToast.error(e.message);
      return false;
    }
  }
}
