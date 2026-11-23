import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'demo_exports.dart';
import 'demo_store.dart';

/// A response produced on the device in demo mode.
class DemoResponse {
  DemoResponse(this.status, this.data, {this.headers = const {}});

  final int status;
  final Object? data;
  final Map<String, List<String>> headers;
}

/// Answers every Panel API v2 call from [DemoStore] — same paths, query
/// parameters and JSON shapes as laravel_api_v2, including writes.
class DemoApi {
  DemoApi._();
  static final DemoApi instance = DemoApi._();

  final _s = DemoStore.instance;

  // ------------------------------------------------------------------ helpers

  DemoResponse _ok(Object? data, {String? message, Map<String, dynamic> extra = const {}}) =>
      DemoResponse(200, {'status': 'success', 'message': ?message, 'data': data, ...extra});

  DemoResponse _fail(int status, String message, [Map<String, List<String>>? errors]) =>
      DemoResponse(status, {'status': 'error', 'message': message, 'errors': ?errors});

  DemoResponse _forbidden() => _fail(403, 'You do not have access to this section.');
  DemoResponse _notFound(String what) => _fail(404, '$what not found.');

  Map<String, dynamic> _body(RequestOptions o) {
    final d = o.data;
    if (d is Map) return Map<String, dynamic>.from(d);
    if (d is FormData) return {for (final f in d.fields) f.key: f.value};
    if (d is String && d.isNotEmpty) {
      try {
        return Map<String, dynamic>.from(jsonDecode(d) as Map);
      } catch (_) {}
    }
    return {};
  }

  String _str(dynamic v) => v == null ? '' : '$v'.trim();
  int? _int(dynamic v) => v == null ? null : int.tryParse('$v');
  bool _bool(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

  List<Map<String, dynamic>>? _list(Map<String, dynamic> role, String name) {
    final l = (role['lists'] as Map)[name];
    if (l == null) return null;
    return (l as List).cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> _map(Map<String, dynamic> role, String key) => (role[key] ??= <String, dynamic>{}) as Map<String, dynamic>;

  String get _now => _s.nowIso();
  String get _nowDisplay => _s.nowDisplay();

  bool _isAdminSide(String role) => role == 'admin' || role == 'oem';

  /// Validation shared by the user forms (client, staff, cardiologist, OEM).
  Map<String, List<String>> _validateUser(Map<String, dynamic> b, {required bool creating, String? currentEmail, List<String> required = const []}) {
    final e = <String, List<String>>{};
    for (final f in ['name', 'email', ...required]) {
      if (_str(b[f]).isEmpty) e[f] = ['The ${f.replaceAll('_', ' ')} field is required.'];
    }
    final email = _str(b['email']).toLowerCase();
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      e['email'] = ['The email field must be a valid email address.'];
    } else if (email.isNotEmpty && email != currentEmail?.toLowerCase() && _s.allEmails().contains(email)) {
      e['email'] = ['The email has already been taken.'];
    }
    final pw = _str(b['password']);
    if (creating && pw.isEmpty) {
      e['password'] = ['The password field is required.'];
    } else if (pw.isNotEmpty && pw.length < 6) {
      e['password'] = ['The password field must be at least 6 characters.'];
    } else if (pw.isNotEmpty && pw != _str(b['password_confirmation'])) {
      e['password'] = ['The password field confirmation does not match.'];
    }
    return e;
  }

  DemoResponse _invalid(Map<String, List<String>> errors) => _fail(422, errors.values.first.first, errors);

  /// Server-style paging, search and sorting over an in-memory list.
  DemoResponse _paged(
    List<Map<String, dynamic>> items,
    Map<String, dynamic> q, {
    required List<String> searchIn,
    required Map<String, String> sortMap,
    required String defaultSort,
    Map<String, dynamic> Function(Map<String, dynamic>)? present,
  }) {
    var list = items;
    final search = _str(q['search']).toLowerCase();
    if (search.isNotEmpty) {
      list = list.where((m) => searchIn.any((k) => _str(_path(m, k)).toLowerCase().contains(search))).toList();
    }
    final sortField = sortMap[_str(q['sort'])] ?? sortMap[defaultSort]!;
    final desc = _str(q['dir']).isEmpty ? true : _str(q['dir']) == 'desc';
    list = [...list]
      ..sort((a, b) {
        final c = _cmp(_path(a, sortField), _path(b, sortField));
        return desc ? -c : c;
      });
    final perPage = (_int(q['per_page']) ?? 10).clamp(1, 100);
    final total = list.length;
    final lastPage = math.max(1, (total / perPage).ceil());
    final page = (_int(q['page']) ?? 1).clamp(1, lastPage);
    final slice = list.skip((page - 1) * perPage).take(perPage).map(present ?? (m) => m).toList();
    return _ok(
      slice,
      extra: {
        'meta': {'page': page, 'per_page': perPage, 'total': total, 'last_page': lastPage},
      },
    );
  }

  dynamic _path(Map<String, dynamic> m, String path) {
    dynamic cur = m;
    for (final p in path.split('.')) {
      if (cur is Map) {
        cur = cur[p];
      } else {
        return null;
      }
    }
    return cur;
  }

  int _cmp(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is num && b is num) return a.compareTo(b);
    return '$a'.toLowerCase().compareTo('$b'.toLowerCase());
  }

  // ------------------------------------------------------------------ router

  Future<DemoResponse> handle(RequestOptions o) async {
    // Feels like a network call: list skeletons and button spinners show.
    await Future<void>.delayed(Duration(milliseconds: o.method == 'GET' ? 220 : 420));

    final path = o.path.replaceFirst(RegExp(r'^https?://[^/]+'), '').replaceFirst(RegExp(r'^/api/v2'), '');
    final seg = path.split('/').where((s) => s.isNotEmpty).toList();
    final m = o.method.toUpperCase();
    final q = Map<String, dynamic>.from(o.queryParameters);

    if (seg.length == 2 && seg[0] == 'auth' && seg[1] == 'login' && m == 'POST') return _login(_body(o));
    if (seg.length == 2 && seg[0] == 'auth' && seg[1] == 'forgot-password') {
      return _ok(null, message: 'We have emailed your password reset link.');
    }

    final token = '${o.headers['Authorization'] ?? ''}'.replaceFirst('Bearer ', '');
    final roleKey = token.startsWith('demo-') ? token.substring(5) : '';
    final role = _s.roles[roleKey];
    if (role == null) return _fail(401, 'Unauthenticated.');

    try {
      return await _route(m, seg, q, o, roleKey, role);
    } catch (e) {
      return _fail(500, 'Demo error: $e');
    }
  }

  Future<DemoResponse> _route(String m, List<String> seg, Map<String, dynamic> q, RequestOptions o, String rk, Map<String, dynamic> role) async {
    final s0 = seg.isEmpty ? '' : seg[0];
    final id = seg.length > 1 ? int.tryParse(seg[1]) : null;

    switch (s0) {
      case 'auth':
        if (seg.length > 1 && seg[1] == 'me') return _ok(role['user']);
        if (seg.length > 1 && seg[1] == 'logout') return _ok(null, message: 'Signed out.');
      case 'dashboard':
        return _ok(_dashboard(rk, role));
      case 'ecg-records':
        if (seg.length == 1) return _ecgList(rk, role, q);
        if (seg[1] == 'summary') return _ecgSummary(rk, role, q);
        if (id == null) break;
        if (seg.length == 2 && m == 'GET') return _ecgDetail(rk, role, id);
        if (seg.length == 2 && m == 'DELETE') return _ecgDelete(rk, id);
        if (seg.length == 3 && seg[2] == 'reassign') return _ecgReassign(rk, role, id, _body(o));
        if (seg.length == 3 && seg[2] == 'assign') return _ecgAssign(rk, role, id);
        if (seg.length == 3 && seg[2] == 'diagnose' && m == 'GET') return _diagnoseForm(rk, role, id);
        if (seg.length == 3 && seg[2] == 'diagnose' && m == 'POST') return _diagnose(rk, role, id, _body(o));
      case 'clients':
        if (seg.length == 1 && m == 'GET') return _clientsList(role, q);
        if (seg.length == 1 && m == 'POST') return _clientCreate(rk, role, _body(o));
        if (id == null) break;
        if (seg.length == 3 && seg[2] == 'staff') return _clientStaff(role, id, q);
        if (m == 'GET') return _clientDetail(role, id);
        if (m == 'PUT' || m == 'POST') return _clientUpdate(role, id, _body(o));
        if (m == 'DELETE') return _clientDelete(role, id);
      case 'admin-staffs':
        final l = _list(role, 'admin_staffs');
        return l == null ? _forbidden() : _staffPaged(l, q);
      case 'staffs':
        final l = _list(role, 'staffs');
        return l == null ? _forbidden() : _staffPaged(l, q);
      case 'staff':
        if (seg.length == 1 && m == 'POST') return _staffCreate(rk, role, _body(o));
        if (id == null) break;
        if (m == 'GET') {
          final d = _s.staffDetails[id];
          return d == null ? _notFound('Staff member') : _ok(d);
        }
        if (m == 'PUT' || m == 'POST') return _staffUpdate(role, id, _body(o));
        if (m == 'DELETE') return _staffDelete(role, id);
      case 'cardiologists':
        if (seg.length == 1 && m == 'GET') {
          final l = _list(role, 'cardiologists');
          return l == null ? _forbidden() : _paged(l, q, searchIn: ['name', 'email', 'phone_number', 'address'], sortMap: _userSort, defaultSort: 'name');
        }
        if (seg.length == 1 && m == 'POST') return _cardiologistCreate(role, _body(o));
        if (id == null) break;
        if (m == 'GET') {
          final d = _map(role, 'cardiologist_details')['$id'];
          return d == null ? _notFound('Cardiologist') : _ok(d);
        }
        if (m == 'PUT' || m == 'POST') return _cardiologistUpdate(role, id, _body(o));
        if (m == 'DELETE') return _cardiologistDelete(role, id);
      case 'devices':
        if (seg.length == 1 && m == 'GET') return _devicesList(role, q);
        if (seg.length == 1 && m == 'POST') return _deviceSave(role, null, _body(o));
        if (id == null) break;
        if (m == 'PUT' || m == 'POST') return _deviceSave(role, id, _body(o));
        if (m == 'DELETE') return _deviceDelete(role, id);
      case 'oem-users':
        if (seg.length == 1 && m == 'GET') {
          final l = _list(role, 'oem_users');
          return l == null ? _forbidden() : _paged(l, q, searchIn: ['name', 'email', 'phone_number'], sortMap: _userSort, defaultSort: 'name');
        }
        if (seg.length == 1 && m == 'POST') return _oemCreate(role, _body(o));
        if (id == null) break;
        if (m == 'GET') {
          final d = _map(role, 'oem_user_details')['$id'];
          return d == null ? _notFound('OEM user') : _ok(d);
        }
        if (m == 'PUT' || m == 'POST') return _oemUpdate(role, id, _body(o));
        if (m == 'DELETE') return _oemDelete(role, id);
      case 'lookups':
        final lk = role['lookups'] as Map<String, dynamic>;
        final what = seg.length > 1 ? seg[1] : '';
        if (what == 'hospitals' || what == 'cardiologists') return _ok(lk[what]);
        if (what == 'staffs' || what == 'devices') return _ok((lk[what] as Map)['${q['hospital_id']}'] ?? const []);
      case 'exports':
        if (seg.length == 3 && seg[1] == 'ecg' && seg[2] == 'count') {
          return _ok({'total': _filteredRecords(rk, role, q).length});
        }
        if (seg.length == 2 && seg[1] == 'ecg') return _exportEcg(rk, role, _body(o));
        if (seg.length == 2 && seg[1] == 'ecg-counts') return _exportCounts(rk, role, _body(o));
      case 'notifications':
        return _notifications(role, seg, m);
      case 'profile':
        return _profile(rk, role, seg, m, o);
    }
    return _fail(404, 'The route ${seg.join('/')} could not be found.');
  }

  static const _userSort = {'name': 'name', 'email': 'email', 'date': 'updated_at'};

  // ------------------------------------------------------------------ auth

  DemoResponse _login(Map<String, dynamic> b) {
    final email = _str(b['email']).toLowerCase();
    if (email.isEmpty || _str(b['password']).isEmpty) {
      return _invalid({
        'email': ['Please enter your email and password.'],
      });
    }
    for (final entry in _s.roles.entries) {
      if ('${entry.value['email']}'.toLowerCase() == email) {
        return _ok({'token': 'demo-${entry.key}', 'user': entry.value['user']}, message: 'Signed in successfully.');
      }
    }
    if (_s.staffDetails.values.any((d) => '${d['email']}'.toLowerCase() == email)) {
      return _fail(403, 'This account cannot sign in to the panel. Please use the Dr. Cardio mobile app.');
    }
    return _invalid({
      'email': ['The credentials do not match.'],
    });
  }

  // ------------------------------------------------------------------ ECG records

  List<int> _ids(Map<String, dynamic> role) => (role['record_ids'] as List).cast<int>();

  Map<String, dynamic> _present(String rk, Map<String, dynamic> r) {
    final out = <String, dynamic>{};
    r.forEach((k, v) {
      if (!k.startsWith('_')) out[k] = v;
    });
    final status = r['status'];
    final admin = _isAdminSide(rk);
    final cardio = rk == 'cardio';
    final hasCc = r['_has_cc'] == true;
    out['actions'] = {
      'view_report': r['report_pdf_url'] != null,
      'delete': admin,
      'reassign': admin && status == 'requested' && hasCc,
      'assign': admin && status == 'no_credit' && hasCc,
      'diagnose': cardio && status == 'requested',
      'edit_report': cardio && status == 'reported',
    };
    return out;
  }

  List<Map<String, dynamic>> _roleRecords(Map<String, dynamic> role) => _ids(role).map((i) => _s.records[i]).whereType<Map<String, dynamic>>().toList();

  List<Map<String, dynamic>> _filteredRecords(String rk, Map<String, dynamic> role, Map<String, dynamic> q, {bool includeStatus = true}) {
    var list = _roleRecords(role);
    bool eq(dynamic a, dynamic b) => '$a' == '$b';
    if (_str(q['hospital_id']).isNotEmpty) list = list.where((r) => eq(r['client_id'], q['hospital_id'])).toList();
    if (_str(q['staff_id']).isNotEmpty) list = list.where((r) => eq(r['staff_id'], q['staff_id'])).toList();
    if (_str(q['device_id']).isNotEmpty) list = list.where((r) => eq(r['device_id'], q['device_id'])).toList();
    if (_str(q['cardiologist_id']).isNotEmpty) list = list.where((r) => eq(r['cardiologist_id'], q['cardiologist_id'])).toList();
    final ecg = _str(q['ecg_status']);
    if (ecg.isNotEmpty) list = list.where((r) => r['ecg_status'] == ecg).toList();
    final status = _str(q['status']);
    if (includeStatus && status.isNotEmpty) list = list.where((r) => r['status'] == status).toList();
    final search = _str(q['search']).toLowerCase();
    if (search.isNotEmpty) {
      final admin = _isAdminSide(rk);
      list = list.where((r) {
        final fields = [r['hospital_name'], r['instrument_id'], r['staff_name'], r['file_name'], r['address'], if (admin) (r['patient'] as Map?)?['name']];
        return fields.any((f) => _str(f).toLowerCase().contains(search));
      }).toList();
    }
    final range = _dateRange(_str(q['date_filter']), _str(q['from_date']), _str(q['to_date']));
    if (range != null) {
      list = list.where((r) {
        final d = DateTime.tryParse('${r['created_at']}')?.toLocal();
        return d != null && !d.isBefore(range.$1) && d.isBefore(range.$2);
      }).toList();
    }
    return list;
  }

  (DateTime, DateTime)? _dateRange(String preset, String from, String to) {
    if (preset.isEmpty) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final monday = today.subtract(Duration(days: today.weekday - 1));
    switch (preset) {
      case 'today':
        return (today, tomorrow);
      case 'yesterday':
        return (today.subtract(const Duration(days: 1)), today);
      case '7':
      case '14':
      case '30':
        return (today.subtract(Duration(days: int.parse(preset) - 1)), tomorrow);
      case 'this_week':
        return (monday, tomorrow);
      case 'last_week':
        return (monday.subtract(const Duration(days: 7)), monday);
      case 'this_month':
        return (DateTime(now.year, now.month), tomorrow);
      case 'last_month':
        return (DateTime(now.year, now.month - 1), DateTime(now.year, now.month));
      case 'custom':
        final f = DateTime.tryParse(from);
        final t = DateTime.tryParse(to);
        if (f == null || t == null) return null;
        return (f, t.add(const Duration(days: 1)));
    }
    return null;
  }

  DemoResponse _ecgList(String rk, Map<String, dynamic> role, Map<String, dynamic> q) => _paged(
    _filteredRecords(rk, role, q),
    {...q, 'search': ''},
    searchIn: const [],
    sortMap: const {
      'date': 'updated_at',
      'staff': 'staff_name',
      'hospital': 'hospital_name',
      'device': 'instrument_id',
      'status': 'status',
      'file': 'file_name',
    },
    defaultSort: 'date',
    present: (r) => _present(rk, r),
  );

  DemoResponse _ecgSummary(String rk, Map<String, dynamic> role, Map<String, dynamic> q) {
    final list = _filteredRecords(rk, role, q, includeStatus: false);
    int n(String s) => list.where((r) => r['status'] == s).length;
    return _ok({
      'all': list.length,
      'by_status': {'pending': n('pending'), 'requested': n('requested'), 'reported': n('reported'), 'no_credit': n('no_credit')},
    });
  }

  Map<String, dynamic>? _visible(Map<String, dynamic> role, int id) => _ids(role).contains(id) ? _s.records[id] : null;

  DemoResponse _ecgDetail(String rk, Map<String, dynamic> role, int id) {
    final r = _visible(role, id);
    return r == null ? _notFound('ECG record') : _ok(_present(rk, r));
  }

  DemoResponse _ecgDelete(String rk, int id) {
    if (!_isAdminSide(rk)) return _forbidden();
    _s.records.remove(id);
    for (final r in _s.roles.values) {
      (r['record_ids'] as List).remove(id);
    }
    return _ok(null, message: 'ECG record deleted.');
  }

  int? get _cardioUserId => _int((_s.roles['cardio']?['user'] as Map?)?['id']);

  void _syncCardioWorklist(int recordId) {
    final r = _s.records[recordId];
    final cardio = _s.roles['cardio'];
    if (r == null || cardio == null) return;
    final ids = cardio['record_ids'] as List;
    final mine = r['cardiologist_id'] == _cardioUserId && (r['status'] == 'requested' || r['status'] == 'reported');
    if (mine && !ids.contains(recordId)) ids.insert(0, recordId);
    if (!mine) ids.remove(recordId);
  }

  DemoResponse _ecgReassign(String rk, Map<String, dynamic> role, int id, Map<String, dynamic> b) {
    if (!_isAdminSide(rk)) return _forbidden();
    final r = _visible(role, id);
    if (r == null) return _notFound('ECG record');
    final cid = _int(b['cardiologist_id']);
    final lk = ((role['lookups'] as Map)['cardiologists'] as List).cast<Map>();
    final doc = lk.where((c) => c['id'] == cid).firstOrNull;
    if (doc == null) {
      return _invalid({
        'cardiologist_id': ['Please choose a cardiologist.'],
      });
    }
    r['cardiologist_id'] = cid;
    r['cardiologist_name'] = doc['name'];
    r['is_reassigned'] = true;
    r['updated_at'] = _now;
    r['updated_at_display'] = _nowDisplay;
    _syncCardioWorklist(id);
    return _ok(null, message: 'ECG re-assigned to ${doc['name']}.');
  }

  DemoResponse _ecgAssign(String rk, Map<String, dynamic> role, int id) {
    if (!_isAdminSide(rk)) return _forbidden();
    final r = _visible(role, id);
    if (r == null) return _notFound('ECG record');
    final client = _map(role, 'client_details')['${r['client_user_id']}'] as Map?;
    if (client == null || client['cardiologist_id'] == null) {
      return _fail(422, 'This client has no cardiologist assigned.');
    }
    r['status'] = 'requested';
    r['status_label'] = 'Requested';
    r['cardiologist_id'] = client['cardiologist_id'];
    r['cardiologist_name'] = client['cardiologist_name'];
    r['requested_at'] = _now;
    r['updated_at'] = _now;
    r['updated_at_display'] = _nowDisplay;
    _syncCardioWorklist(id);
    return _ok(null, message: 'ECG sent to ${client['cardiologist_name']} for reporting.');
  }

  DemoResponse _diagnoseForm(String rk, Map<String, dynamic> role, int id) {
    if (rk != 'cardio') return _forbidden();
    final r = _visible(role, id);
    if (r == null) return _notFound('ECG record');
    return _ok({'record': _present(rk, r), 'templates': role['templates']});
  }

  DemoResponse _diagnose(String rk, Map<String, dynamic> role, int id, Map<String, dynamic> b) {
    if (rk != 'cardio') return _forbidden();
    final r = _visible(role, id);
    if (r == null) return _notFound('ECG record');
    final publish = b['action'] == 'publish';
    final ecg = _str(b['ecg_status']);
    if (publish && ecg != 'normal' && ecg != 'abnormal') {
      return _invalid({
        'ecg_status': ['Please select the ECG status.'],
      });
    }
    if (ecg.isNotEmpty) r['ecg_status'] = ecg;
    r['cardiologist_report'] = b['cardiologist_report'];
    final mm = Map<String, dynamic>.from(r['measurements'] as Map);
    for (final k in ['hr', 'r', 'rr', 'pr', 'qrs', 'qt', 'qtc', 'qt_by_qtc']) {
      if (b.containsKey(k)) mm[k] = _str(b[k]).isEmpty ? null : _str(b[k]);
    }
    r['measurements'] = mm;
    r['updated_at'] = _now;
    r['updated_at_display'] = _nowDisplay;
    if (publish) {
      final first = r['status'] != 'reported';
      r['status'] = 'reported';
      r['status_label'] = 'Reported';
      r['report_pdf_url'] = 'demo://report/$id';
      r['cardiologist_report_pdf_url'] = 'demo://report/$id';
      if (first) {
        r['reported_at'] = _now;
        final req = DateTime.tryParse('${r['requested_at']}');
        if (req != null) r['tat_minutes'] = DateTime.now().difference(req).inMinutes;
      }
    }
    return _ok(_present(rk, r), message: publish ? 'Report published.' : 'Draft saved.');
  }

  // ------------------------------------------------------------------ dashboard

  Map<String, dynamic> _dashboard(String rk, Map<String, dynamic> role) {
    final d = Map<String, dynamic>.from(role['dashboard'] as Map);
    final recs = _roleRecords(role);
    final now = DateTime.now();
    DateTime? local(dynamic v) => DateTime.tryParse('$v')?.toLocal();
    final month = recs.where((r) {
      final c = local(r['created_at']);
      return c != null && c.year == now.year && c.month == now.month;
    }).toList();
    int count(List<Map<String, dynamic>> l, String k, String v) => l.where((r) => r[k] == v).length;

    final counts = Map<String, dynamic>.from(d['counts'] as Map);
    counts['ecg_records'] = recs.length;
    if (rk == 'cardio') {
      counts['normal_ecg'] = count(recs, 'ecg_status', 'normal');
      counts['abnormal_ecg'] = count(recs, 'ecg_status', 'abnormal');
    }
    for (final entry in {'clients': 'clients', 'devices': 'devices', 'cardiologists': 'cardiologists'}.entries) {
      final l = _list(role, entry.value);
      if (l != null && (rk == 'admin' || rk == 'oem')) counts[entry.key] = l.length;
    }
    final staffList = _list(role, 'staffs');
    if (staffList != null) counts['staffs'] = staffList.length;
    d['counts'] = counts;

    final today = DateTime(now.year, now.month, now.day);
    final fmt = DateFormat('yyyy-MM-dd');
    final reported = month.where((r) => r['tat_minutes'] != null).map((r) => r['tat_minutes'] as num).toList();
    d['insights'] = {
      'daily': [
        for (var i = 13; i >= 0; i--)
          {
            'date': fmt.format(today.subtract(Duration(days: i))),
            'total': recs.where((r) {
              final c = local(r['created_at']);
              return c != null && fmt.format(c) == fmt.format(today.subtract(Duration(days: i)));
            }).length,
          },
      ],
      'month_status': {
        for (final s in ['pending', 'requested', 'reported', 'no_credit']) s: count(month, 'status', s),
      },
      'month_ecg_status': {'normal': count(month, 'ecg_status', 'normal'), 'abnormal': count(month, 'ecg_status', 'abnormal')},
      'avg_tat_minutes': reported.isEmpty ? null : (reported.reduce((a, b) => a + b) / reported.length).round(),
    };
    final recent = [...recs]..sort((a, b) => _cmp(b['created_at'], a['created_at']));
    d['recent'] = recent.take(6).map((r) => _present(rk, r)).toList();
    d.remove('recent_ids');
    return d;
  }

  // ------------------------------------------------------------------ clients

  DemoResponse _clientsList(Map<String, dynamic> role, Map<String, dynamic> q) {
    final l = _list(role, 'clients');
    if (l == null) return _forbidden();
    final cid = _str(q['cardiologist_id']);
    final items = cid.isEmpty ? l : l.where((c) => '${c['cardiologist_id']}' == cid).toList();
    return _paged(
      items,
      q,
      searchIn: ['name', 'email', 'hospital_name', 'doctor_name', 'phone_number', 'address'],
      sortMap: const {'name': 'name', 'email': 'email', 'hospital': 'hospital_name', 'doctor': 'doctor_name', 'date': 'created_at'},
      defaultSort: 'date',
    );
  }

  DemoResponse _clientDetail(Map<String, dynamic> role, int id) {
    final d = _map(role, 'client_details')['$id'];
    return d == null ? _notFound('Client') : _ok(d);
  }

  (int?, String?) _cardiologistChoice(Map<String, dynamic> role, dynamic raw) {
    final cid = _int(raw);
    if (cid == null) return (null, null);
    final lk = ((role['lookups'] as Map)['cardiologists'] as List).cast<Map>();
    final doc = lk.where((c) => c['id'] == cid).firstOrNull;
    return doc == null ? (null, null) : (cid, '${doc['name']}');
  }

  Set<String> _allInstrumentIds() {
    final out = <String>{};
    for (final r in _s.roles.values) {
      for (final d in (((r['lists'] as Map)['devices'] as List?) ?? const [])) {
        out.add('${(d as Map)['instrument_id']}'.toLowerCase());
      }
    }
    return out;
  }

  DemoResponse _clientCreate(String rk, Map<String, dynamic> role, Map<String, dynamic> b) {
    final l = _list(role, 'clients');
    if (l == null) return _forbidden();
    final errors = _validateUser(b, creating: true, required: ['hospital_name', 'doctor_name', 'phone_number', 'address']);
    final devices = ((b['devices'] as List?) ?? const []).map((e) => _str(e)).where((e) => e.isNotEmpty).toList();
    final taken = _allInstrumentIds();
    for (var i = 0; i < devices.length; i++) {
      if (taken.contains(devices[i].toLowerCase())) errors['devices.$i'] = ['Device ${devices[i]} is already registered.'];
    }
    if (errors.isNotEmpty) return _invalid(errors);

    final userId = _s.nextId();
    final clientId = _s.nextId();
    final multi = _bool(b['multi_hospital_access']);
    final (cid, cname) = multi ? (null, null) : _cardiologistChoice(role, b['cardiologist']);
    final limitOn = _bool(b['report_limit_enabled']);
    final limit = _int(b['report_limit']) ?? 0;
    final item = <String, dynamic>{
      'id': userId,
      'client_id': clientId,
      'name': _str(b['name']),
      'email': _str(b['email']),
      'phone_number': _str(b['phone_number']),
      'hospital_name': _str(b['hospital_name']),
      'doctor_name': _str(b['doctor_name']),
      'address': _str(b['address']),
      'cardiologist_id': cid,
      'cardiologist_name': cname,
      'report_limit_enabled': limitOn,
      'report_limit': limit,
      'ecg_balance': limitOn ? limit : null,
      'multi_hospital_access': multi,
      'created_at': _now,
      'created_at_display': _nowDisplay,
    };
    l.insert(0, item);

    final deviceRows = <Map<String, dynamic>>[];
    final roleDevices = _list(role, 'devices');
    final lk = role['lookups'] as Map<String, dynamic>;
    for (final instrument in devices) {
      final devId = _s.nextId();
      deviceRows.add({'id': devId, 'instrument_id': instrument, 'updated_at': _now});
      roleDevices?.insert(0, {
        'id': devId,
        'instrument_id': instrument,
        'hospital_id': clientId,
        'hospital_name': item['hospital_name'],
        'client_user_id': userId,
        'updated_at': _now,
        'updated_at_display': _nowDisplay,
      });
    }
    _map(role, 'client_details')['$userId'] = {
      ...item,
      'webhook_url': _str(b['webhook_url']).isEmpty ? null : _str(b['webhook_url']),
      'get_patient_api_enabled': _bool(b['get_patient_api_enabled']),
      'get_patient_url': _str(b['get_patient_url']),
      'staff_count': 0,
      'devices': deviceRows,
    }..remove('ecg_balance');
    _map(role, 'client_staff')['$userId'] = <Map<String, dynamic>>[];
    (lk['hospitals'] as List).add({'id': clientId, 'name': item['hospital_name'], 'user_id': userId});
    (lk['staffs'] as Map)['$clientId'] = <Map<String, dynamic>>[];
    (lk['devices'] as Map)['$clientId'] = [
      for (final d in deviceRows) {'id': d['id'], 'name': d['instrument_id']},
    ];
    return _ok(null, message: 'Client created successfully.');
  }

  DemoResponse _clientUpdate(Map<String, dynamic> role, int id, Map<String, dynamic> b) {
    final l = _list(role, 'clients');
    if (l == null) return _forbidden();
    final item = l.where((c) => c['id'] == id).firstOrNull;
    if (item == null) return _notFound('Client');
    final errors = _validateUser(b, creating: false, currentEmail: '${item['email']}', required: ['hospital_name', 'doctor_name', 'phone_number', 'address']);
    if (errors.isNotEmpty) return _invalid(errors);
    final multi = _bool(b['multi_hospital_access']);
    final (cid, cname) = multi ? (null, null) : _cardiologistChoice(role, b['cardiologist']);
    final limitOn = _bool(b['report_limit_enabled']);
    final changes = <String, dynamic>{
      for (final k in ['name', 'email', 'phone_number', 'hospital_name', 'doctor_name', 'address']) k: _str(b[k]),
      'cardiologist_id': cid,
      'cardiologist_name': cname,
      'report_limit_enabled': limitOn,
      'report_limit': _int(b['report_limit']) ?? 0,
      'multi_hospital_access': multi,
    };
    item.addAll(changes);
    item['ecg_balance'] = limitOn ? item['report_limit'] : null;
    final detail = _map(role, 'client_details')['$id'] as Map<String, dynamic>?;
    detail?.addAll({
      ...changes,
      'webhook_url': _str(b['webhook_url']).isEmpty ? null : _str(b['webhook_url']),
      'get_patient_api_enabled': _bool(b['get_patient_api_enabled']),
      'get_patient_url': _str(b['get_patient_url']),
    });
    for (final h in ((role['lookups'] as Map)['hospitals'] as List).cast<Map>()) {
      if (h['user_id'] == id) h['name'] = item['hospital_name'];
    }
    return _ok(null, message: 'Client updated successfully.');
  }

  DemoResponse _clientDelete(Map<String, dynamic> role, int id) {
    final l = _list(role, 'clients');
    if (l == null) return _forbidden();
    final item = l.where((c) => c['id'] == id).firstOrNull;
    if (item == null) return _notFound('Client');
    l.remove(item);
    _map(role, 'client_details').remove('$id');
    _list(role, 'devices')?.removeWhere((d) => d['client_user_id'] == id);
    _list(role, 'admin_staffs')?.removeWhere((s) => s['client_user_id'] == id);
    final lk = role['lookups'] as Map;
    (lk['hospitals'] as List).removeWhere((h) => (h as Map)['user_id'] == id);
    return _ok(null, message: 'Client deleted successfully.');
  }

  DemoResponse _clientStaff(Map<String, dynamic> role, int id, Map<String, dynamic> q) {
    final l = _map(role, 'client_staff')['$id'];
    if (l == null) return _notFound('Client');
    return _staffPaged((l as List).cast<Map<String, dynamic>>(), q);
  }

  // ------------------------------------------------------------------ staff

  DemoResponse _staffPaged(List<Map<String, dynamic>> l, Map<String, dynamic> q) =>
      _paged(l, q, searchIn: ['name', 'email', 'phone_number', 'client_name'], sortMap: _userSort, defaultSort: 'name');

  /// Every list in this role that can hold the staff member with [id].
  Iterable<List<Map<String, dynamic>>> _staffLists(Map<String, dynamic> role) sync* {
    for (final name in ['admin_staffs', 'staffs']) {
      final l = _list(role, name);
      if (l != null) yield l;
    }
    for (final l in _map(role, 'client_staff').values) {
      yield (l as List).cast<Map<String, dynamic>>();
    }
  }

  DemoResponse _staffCreate(String rk, Map<String, dynamic> role, Map<String, dynamic> b) {
    final errors = _validateUser(b, creating: true, required: ['phone_number']);
    Map<String, dynamic>? client;
    if (_isAdminSide(rk)) {
      final cid = _int(b['client_id']);
      client = _list(role, 'clients')?.where((c) => c['client_id'] == cid).firstOrNull;
      if (client == null) errors['client_id'] = ['Please choose a valid client.'];
    }
    if (errors.isNotEmpty) return _invalid(errors);

    final id = _s.nextId();
    final (docId, docName) = _cardiologistChoice(role, b['cardiologist_id']);
    final me = role['user'] as Map;
    final item = <String, dynamic>{
      'id': id,
      'name': _str(b['name']),
      'email': _str(b['email']),
      'phone_number': _str(b['phone_number']),
      'client_id': client?['client_id'] ?? (me['client'] as Map?)?['id'],
      'client_name': client?['hospital_name'],
      'client_user_id': client?['id'],
      'cardiologist_id': docId,
      'cardiologist_name': docName,
      'updated_at': _now,
      'updated_at_display': _nowDisplay,
    };
    _s.staffDetails[id] = {
      'id': id,
      'name': item['name'],
      'email': item['email'],
      'phone_number': item['phone_number'],
      'client_id': item['client_id'],
      'cardiologist_id': docId,
    };
    if (client != null) {
      _list(role, 'admin_staffs')?.insert(0, item);
      final cs = _map(role, 'client_staff');
      ((cs['${client['id']}'] ??= <Map<String, dynamic>>[]) as List).insert(0, Map<String, dynamic>.from(item));
      final detail = _map(role, 'client_details')['${client['id']}'] as Map?;
      if (detail != null) detail['staff_count'] = (_int(detail['staff_count']) ?? 0) + 1;
      final lk = (role['lookups'] as Map)['staffs'] as Map;
      ((lk['${client['client_id']}'] ??= <Map<String, dynamic>>[]) as List).add({'id': id, 'name': item['name']});
    } else {
      _list(role, 'staffs')?.insert(0, {...item, 'client_name': null, 'client_user_id': null});
    }
    return _ok(null, message: 'Staff member added.');
  }

  DemoResponse _staffUpdate(Map<String, dynamic> role, int id, Map<String, dynamic> b) {
    final current = _s.staffDetails[id];
    if (current == null) return _notFound('Staff member');
    final errors = _validateUser(b, creating: false, currentEmail: '${current['email']}', required: ['phone_number']);
    if (errors.isNotEmpty) return _invalid(errors);
    final changes = {
      for (final k in ['name', 'email', 'phone_number']) k: _str(b[k]),
    };
    current.addAll(changes);
    final hasDoc = b.containsKey('cardiologist_id');
    final (docId, docName) = _cardiologistChoice(role, b['cardiologist_id']);
    if (hasDoc) current['cardiologist_id'] = docId;
    for (final l in _staffLists(role)) {
      for (final s in l.where((s) => s['id'] == id)) {
        s.addAll(changes);
        if (hasDoc) s.addAll({'cardiologist_id': docId, 'cardiologist_name': docName});
        s['updated_at'] = _now;
        s['updated_at_display'] = _nowDisplay;
      }
    }
    return _ok(null, message: 'Staff member updated.');
  }

  DemoResponse _staffDelete(Map<String, dynamic> role, int id) {
    var found = false;
    for (final l in _staffLists(role)) {
      final before = l.length;
      l.removeWhere((s) => s['id'] == id);
      found = found || l.length != before;
    }
    if (!found) return _notFound('Staff member');
    _s.staffDetails.remove(id);
    return _ok(null, message: 'Staff member deleted.');
  }

  // ------------------------------------------------------------------ cardiologists

  DemoResponse _cardiologistCreate(Map<String, dynamic> role, Map<String, dynamic> b) {
    final l = _list(role, 'cardiologists');
    if (l == null) return _forbidden();
    final errors = _validateUser(b, creating: true, required: ['phone_number']);
    if (errors.isNotEmpty) return _invalid(errors);
    final id = _s.nextId();
    final item = {
      'id': id,
      'name': _str(b['name']),
      'email': _str(b['email']),
      'phone_number': _str(b['phone_number']),
      'address': _str(b['address']),
      'clients_count': 0,
      'updated_at': _now,
      'updated_at_display': _nowDisplay,
    };
    l.insert(0, item);
    _map(role, 'cardiologist_details')['$id'] = {...item, 'created_at': _now, 'clients': <dynamic>[]}..remove('clients_count');
    ((role['lookups'] as Map)['cardiologists'] as List).add({'id': id, 'name': item['name']});
    return _ok(null, message: 'Cardiologist saved successfully.');
  }

  DemoResponse _cardiologistUpdate(Map<String, dynamic> role, int id, Map<String, dynamic> b) {
    final item = _list(role, 'cardiologists')?.where((c) => c['id'] == id).firstOrNull;
    if (item == null) return _notFound('Cardiologist');
    final errors = _validateUser(b, creating: false, currentEmail: '${item['email']}', required: ['phone_number']);
    if (errors.isNotEmpty) return _invalid(errors);
    final changes = {
      for (final k in ['name', 'email', 'phone_number', 'address']) k: _str(b[k]),
      'updated_at': _now,
      'updated_at_display': _nowDisplay,
    };
    item.addAll(changes);
    (_map(role, 'cardiologist_details')['$id'] as Map?)?.addAll(changes);
    for (final c in ((role['lookups'] as Map)['cardiologists'] as List).cast<Map>()) {
      if (c['id'] == id) c['name'] = item['name'];
    }
    return _ok(null, message: 'Cardiologist updated successfully.');
  }

  DemoResponse _cardiologistDelete(Map<String, dynamic> role, int id) {
    final l = _list(role, 'cardiologists');
    final item = l?.where((c) => c['id'] == id).firstOrNull;
    if (l == null || item == null) return _notFound('Cardiologist');
    if ((_int(item['clients_count']) ?? 0) > 0) {
      return _fail(422, 'This cardiologist is linked to ${item['clients_count']} client(s). Re-assign them first.');
    }
    l.remove(item);
    _map(role, 'cardiologist_details').remove('$id');
    ((role['lookups'] as Map)['cardiologists'] as List).removeWhere((c) => (c as Map)['id'] == id);
    return _ok(null, message: 'Cardiologist deleted successfully.');
  }

  // ------------------------------------------------------------------ devices

  DemoResponse _devicesList(Map<String, dynamic> role, Map<String, dynamic> q) {
    final l = _list(role, 'devices');
    if (l == null) return _forbidden();
    final hid = _str(q['hospital_id']);
    final items = hid.isEmpty ? l : l.where((d) => '${d['hospital_id']}' == hid).toList();
    return _paged(
      items,
      q,
      searchIn: ['instrument_id', 'hospital_name'],
      sortMap: const {'hospital': 'hospital_name', 'device': 'instrument_id', 'date': 'updated_at'},
      defaultSort: 'device',
    );
  }

  DemoResponse _deviceSave(Map<String, dynamic> role, int? id, Map<String, dynamic> b) {
    final l = _list(role, 'devices');
    if (l == null) return _forbidden();
    final instrument = _str(b['intrument_id']);
    final hid = _int(b['hospital_id']);
    final lk = role['lookups'] as Map<String, dynamic>;
    final hospital = (lk['hospitals'] as List).cast<Map>().where((h) => h['id'] == hid).firstOrNull;
    final errors = <String, List<String>>{};
    if (hospital == null) errors['hospital_id'] = ['Please choose a hospital.'];
    final existing = id == null ? null : l.where((d) => d['id'] == id).firstOrNull;
    if (id != null && existing == null) return _notFound('Device');
    if (instrument.isEmpty) {
      errors['intrument_id'] = ['The instrument ID field is required.'];
    } else if (instrument.toLowerCase() != '${existing?['instrument_id']}'.toLowerCase() && _allInstrumentIds().contains(instrument.toLowerCase())) {
      errors['intrument_id'] = ['This device ID is already registered.'];
    }
    if (errors.isNotEmpty) return _invalid(errors);

    final row = existing ?? <String, dynamic>{'id': _s.nextId()};
    final oldHospital = row['hospital_id'];
    row.addAll({
      'instrument_id': instrument,
      'hospital_id': hid,
      'hospital_name': hospital!['name'],
      'client_user_id': hospital['user_id'],
      'updated_at': _now,
      'updated_at_display': _nowDisplay,
    });
    if (existing == null) l.insert(0, row);

    final devLk = lk['devices'] as Map;
    if (oldHospital != null) (devLk['$oldHospital'] as List?)?.removeWhere((d) => (d as Map)['id'] == row['id']);
    ((devLk['$hid'] ??= <Map<String, dynamic>>[]) as List).add({'id': row['id'], 'name': instrument});
    final details = _map(role, 'client_details');
    for (final d in details.values) {
      ((d as Map)['devices'] as List?)?.removeWhere((x) => (x as Map)['id'] == row['id']);
    }
    ((details['${hospital['user_id']}'] as Map?)?['devices'] as List?)?.insert(0, {'id': row['id'], 'instrument_id': instrument, 'updated_at': _now});
    return _ok(row, message: existing == null ? 'Device added successfully.' : 'Device updated successfully.');
  }

  DemoResponse _deviceDelete(Map<String, dynamic> role, int id) {
    final l = _list(role, 'devices');
    final row = l?.where((d) => d['id'] == id).firstOrNull;
    if (l == null || row == null) return _notFound('Device');
    l.remove(row);
    final lk = role['lookups'] as Map;
    ((lk['devices'] as Map)['${row['hospital_id']}'] as List?)?.removeWhere((d) => (d as Map)['id'] == id);
    for (final d in _map(role, 'client_details').values) {
      ((d as Map)['devices'] as List?)?.removeWhere((x) => (x as Map)['id'] == id);
    }
    return _ok(null, message: 'Device deleted successfully.');
  }

  // ------------------------------------------------------------------ OEM users

  DemoResponse _oemCreate(Map<String, dynamic> role, Map<String, dynamic> b) {
    final l = _list(role, 'oem_users');
    if (l == null) return _forbidden();
    final errors = _validateUser(b, creating: true, required: ['phone_number']);
    if (errors.isNotEmpty) return _invalid(errors);
    final id = _s.nextId();
    final item = {
      'id': id,
      'name': _str(b['name']),
      'email': _str(b['email']),
      'phone_number': _str(b['phone_number']),
      'clients_count': 0,
      'updated_at': _now,
      'updated_at_display': _nowDisplay,
    };
    l.insert(0, item);
    _map(role, 'oem_user_details')['$id'] = {...item, 'created_at': _now, 'cardiologists_count': 0};
    return _ok(null, message: 'OEM user saved successfully.');
  }

  DemoResponse _oemUpdate(Map<String, dynamic> role, int id, Map<String, dynamic> b) {
    final item = _list(role, 'oem_users')?.where((c) => c['id'] == id).firstOrNull;
    if (item == null) return _notFound('OEM user');
    final errors = _validateUser(b, creating: false, currentEmail: '${item['email']}', required: ['phone_number']);
    if (errors.isNotEmpty) return _invalid(errors);
    final changes = {
      for (final k in ['name', 'email', 'phone_number']) k: _str(b[k]),
      'updated_at': _now,
      'updated_at_display': _nowDisplay,
    };
    item.addAll(changes);
    (_map(role, 'oem_user_details')['$id'] as Map?)?.addAll(changes);
    return _ok(null, message: 'OEM user updated successfully.');
  }

  DemoResponse _oemDelete(Map<String, dynamic> role, int id) {
    final l = _list(role, 'oem_users');
    final item = l?.where((c) => c['id'] == id).firstOrNull;
    if (l == null || item == null) return _notFound('OEM user');
    l.remove(item);
    _map(role, 'oem_user_details').remove('$id');
    return _ok(null, message: 'OEM user deleted successfully.');
  }

  // ------------------------------------------------------------------ notifications

  DemoResponse _notifications(Map<String, dynamic> role, List<String> seg, String m) {
    final notes = role['notifications'] as Map;
    final items = (notes['items'] as List).cast<Map<String, dynamic>>();
    if (m == 'GET') {
      final fresh = [
        for (final n in items.take(10)) {...n, 'date': DemoStore.ago(DateTime.tryParse('${n['created_at']}')?.toLocal() ?? DateTime.now())},
      ];
      return _ok(fresh, extra: {'unread_total': items.length});
    }
    if (seg.length == 2 && seg[1] == 'read-all') {
      items.clear();
      notes['unread_total'] = 0;
      return _ok(null, message: 'All notifications marked as read.');
    }
    final id = seg.length > 1 ? int.tryParse(seg[1]) : null;
    items.removeWhere((n) => n['id'] == id);
    notes['unread_total'] = items.length;
    return _ok(null, message: 'Notification marked as read.');
  }

  // ------------------------------------------------------------------ profile

  DemoResponse _profile(String rk, Map<String, dynamic> role, List<String> seg, String m, RequestOptions o) {
    final profile = role['profile'] as Map<String, dynamic>;
    final user = role['user'] as Map<String, dynamic>;
    if (seg.length == 2 && m == 'DELETE') {
      final cardio = profile['cardiologist'] as Map?;
      if (seg[1] == 'logo') {
        cardio?['logo_url'] = null;
        profile['logo_url'] = null;
        return _ok(null, message: 'Logo removed.');
      }
      cardio?['signature_url'] = null;
      return _ok(null, message: 'Signature removed.');
    }
    if (m == 'GET') return _ok(profile);

    final b = _body(o);
    if (_str(b['password']).isNotEmpty) {
      final pw = _str(b['password']);
      if (pw.length < 6) {
        return _invalid({
          'password': ['The password field must be at least 6 characters.'],
        });
      }
      if (pw != _str(b['password_confirmation'])) {
        return _invalid({
          'password': ['The password field confirmation does not match.'],
        });
      }
      return _ok(profile, message: 'Password changed successfully.');
    }
    if (b.containsKey('name') && _str(b['name']).isEmpty) {
      return _invalid({
        'name': ['The name field is required.'],
      });
    }
    if (b.containsKey('name')) {
      profile['name'] = _str(b['name']);
      user['name'] = profile['name'];
    }
    final editable = (profile['editable'] as Map?) ?? {};
    for (final k in ['hospital_name', 'doctor_name', 'address', 'footer']) {
      if (b.containsKey(k)) editable[k] = _str(b[k]);
    }
    if (b.containsKey('theme_color')) {
      profile['theme_color'] = _str(b['theme_color']);
      user['theme_color'] = profile['theme_color'];
    }
    final cardio = profile['cardiologist'] as Map?;
    if (cardio != null) {
      if (b.containsKey('address')) cardio['address'] = _str(b['address']);
      if (b.containsKey('footer')) cardio['footer'] = _str(b['footer']);
      user['cardiologist'] = Map<String, dynamic>.from(cardio);
    }
    final client = profile['client'] as Map?;
    if (client != null) {
      for (final k in ['hospital_name', 'doctor_name', 'address']) {
        if (b.containsKey(k)) client[k] = _str(b[k]);
      }
      user['client'] = Map<String, dynamic>.from(client);
    }
    return _ok(profile, message: 'Profile updated successfully.');
  }

  // ------------------------------------------------------------------ exports

  DemoResponse _file(Uint8List bytes, String name, String type) => DemoResponse(
    200,
    bytes,
    headers: {
      'content-type': [type],
      'content-disposition': ['attachment; filename="$name"'],
    },
  );

  DemoResponse _exportEcg(String rk, Map<String, dynamic> role, Map<String, dynamic> b) {
    if (rk == 'cardio') return _forbidden();
    final recs = _filteredRecords(rk, role, b);
    if (recs.isEmpty) return _fail(422, 'No ECG records match these filters.');
    final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    if (b['type'] == 'csv') {
      return _file(DemoExports.csvZip(recs), 'ECG_CSV_$stamp.zip', 'application/zip');
    }
    return _file(DemoExports.pdfZip(recs.take(25).toList()), 'ECG_PDF_$stamp.zip', 'application/zip');
  }

  DemoResponse _exportCounts(String rk, Map<String, dynamic> role, Map<String, dynamic> b) {
    if (rk != 'cardio') return _forbidden();
    final month = _int(b['month']) ?? DateTime.now().month;
    final year = _int(b['year']) ?? DateTime.now().year;
    final recs = _roleRecords(role).where((r) {
      final d = DateTime.tryParse('${r['reported_at'] ?? r['created_at']}')?.toLocal();
      return d != null && d.month == month && d.year == year && r['status'] == 'reported';
    }).toList();
    final csv = DemoExports.countsCsv(recs);
    return _file(Uint8List.fromList(utf8.encode(csv)), 'ECG_Counts_${month.toString().padLeft(2, '0')}_$year.csv', 'text/csv');
  }
}
