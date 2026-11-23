import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// In-memory copy of the demo data set, loaded once at start-up.
///
/// The sample data was captured at a fixed moment; on load every timestamp is
/// moved forward by the time since then, so "12 minutes ago", "Today" and the
/// 14-day chart always look current.
class DemoStore {
  DemoStore._();
  static final DemoStore instance = DemoStore._();

  /// ECG records by id, shared by every role (a report published by the
  /// cardiologist shows up for the admin and the hospital too).
  final Map<int, Map<String, dynamic>> records = {};

  /// Staff edit-form data by staff user id.
  final Map<int, Map<String, dynamic>> staffDetails = {};

  /// Per-role state: user, dashboard, lists, details, lookups, record ids.
  final Map<String, Map<String, dynamic>> roles = {};

  bool _loaded = false;
  int _nextId = 50000;

  int nextId() => _nextId++;

  static final _display = DateFormat('dd-MM-yyyy hh:mm a');
  static final _fileStamp = DateFormat('yyyy-MM-dd_HH-mm-ss');
  static final _isoRe = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}');
  static final _dayRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _fileDateRe = RegExp(r'\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}');

  Future<void> load() async {
    if (_loaded) return;
    final raw = jsonDecode(await rootBundle.loadString('assets/demo/demo_data.json')) as Map<String, dynamic>;
    final captured = DateTime.parse(raw['captured_at'] as String);
    final now = DateTime.now();
    final delta = now.difference(captured);
    final capturedDay = DateTime(captured.toLocal().year, captured.toLocal().month, captured.toLocal().day);
    final today = DateTime(now.year, now.month, now.day);
    final dayShift = today.difference(capturedDay).inDays;

    final data = _shift(raw, delta, dayShift) as Map<String, dynamic>;

    (data['records'] as Map<String, dynamic>).forEach((k, v) {
      final r = Map<String, dynamic>.from(v as Map);
      // ECGs without a hospital cardiologist show "NA" while pending.
      r['_has_cc'] = r['status_label'] != 'NA';
      final created = DateTime.tryParse('${r['created_at']}');
      if (created != null) {
        r['file_name'] = '${r['file_name']}'.replaceFirst(_fileDateRe, _fileStamp.format(created.toLocal()));
      }
      records[int.parse(k)] = r;
    });
    (data['staff_details'] as Map<String, dynamic>).forEach((k, v) => staffDetails[int.parse(k)] = Map<String, dynamic>.from(v as Map));
    (data['roles'] as Map<String, dynamic>).forEach((k, v) => roles[k] = Map<String, dynamic>.from(v as Map));
    _loaded = true;
  }

  /// Moves every timestamp forward and refreshes the "…_display" strings.
  dynamic _shift(dynamic node, Duration delta, int dayShift) {
    if (node is Map) {
      final out = <String, dynamic>{};
      node.forEach((key, value) {
        final k = key as String;
        if (value is String && _isoRe.hasMatch(value)) {
          out[k] = DateTime.parse(value).add(delta).toUtc().toIso8601String();
        } else if (k == 'date' && value is String && _dayRe.hasMatch(value)) {
          final d = DateTime.parse(value).add(Duration(days: dayShift));
          out[k] = DateFormat('yyyy-MM-dd').format(d);
        } else {
          out[k] = _shift(value, delta, dayShift);
        }
      });
      for (final k in out.keys.toList()) {
        if (k.endsWith('_display')) {
          final base = DateTime.tryParse('${out[k.substring(0, k.length - 8)]}');
          if (base != null) out[k] = _display.format(base.toLocal());
        }
      }
      return out;
    }
    if (node is List) return node.map((e) => _shift(e, delta, dayShift)).toList();
    return node;
  }

  String nowIso() => DateTime.now().toUtc().toIso8601String();
  String nowDisplay() => _display.format(DateTime.now());

  /// "5 minutes ago" style text, like Laravel's diffForHumans().
  static String ago(DateTime when) {
    final d = DateTime.now().difference(when);
    String unit(int n, String u) => '$n $u${n == 1 ? '' : 's'} ago';
    if (d.inSeconds < 60) return unit(d.inSeconds.clamp(1, 59), 'second');
    if (d.inMinutes < 60) return unit(d.inMinutes, 'minute');
    if (d.inHours < 24) return unit(d.inHours, 'hour');
    if (d.inDays < 7) return unit(d.inDays, 'day');
    if (d.inDays < 30) return unit(d.inDays ~/ 7, 'week');
    return unit(d.inDays ~/ 30, 'month');
  }

  /// Every e-mail address in the demo (for "already taken" checks).
  Set<String> allEmails() {
    final out = <String>{};
    void scan(dynamic n) {
      if (n is Map) {
        n.forEach((k, v) {
          if (k == 'email' && v is String) out.add(v.toLowerCase());
          scan(v);
        });
      } else if (n is List) {
        for (final e in n) {
          scan(e);
        }
      }
    }

    scan(roles);
    scan(staffDetails);
    return out;
  }
}
