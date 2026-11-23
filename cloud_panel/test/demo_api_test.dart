import 'package:dio/dio.dart';
import 'package:drcardio_cloud_panel/core/demo/demo_api.dart';
import 'package:drcardio_cloud_panel/core/demo/demo_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// The demo build answers every API call on the device; these tests drive the
/// same endpoints the screens use, including writes.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final api = DemoApi.instance;

  setUpAll(() => DemoStore.instance.load());

  Future<DemoResponse> call(String role, String method, String path, {Object? data, Map<String, dynamic>? query}) => api.handle(
        RequestOptions(
          path: path,
          method: method,
          data: data,
          queryParameters: query ?? {},
          headers: {'Authorization': 'Bearer demo-$role'},
        ),
      );

  Map<String, dynamic> body(DemoResponse r) => r.data as Map<String, dynamic>;

  test('sign in with a demo account, refuse unknown and staff accounts', () async {
    final ok = await api.handle(RequestOptions(path: '/auth/login', method: 'POST', data: {'email': 'admin@example.com', 'password': 'x'}));
    expect(ok.status, 200);
    expect(body(ok)['data']['token'], 'demo-admin');
    final bad = await api.handle(RequestOptions(path: '/auth/login', method: 'POST', data: {'email': 'nobody@example.com', 'password': 'x'}));
    expect(bad.status, 422);
    final staff = await api.handle(RequestOptions(path: '/auth/login', method: 'POST', data: {'email': 'rahul.verma@example.com', 'password': 'x'}));
    expect(staff.status, 403);
  });

  test('ECG list pages, filters and summary', () async {
    final all = body(await call('admin', 'GET', '/ecg-records', query: {'per_page': 10}));
    expect(all['meta']['total'], 130);
    expect((all['data'] as List).length, 10);
    final reported = body(await call('admin', 'GET', '/ecg-records', query: {'status': 'reported'}));
    expect((reported['data'] as List).every((r) => r['status'] == 'reported'), isTrue);
    final summary = body(await call('admin', 'GET', '/ecg-records/summary'))['data'];
    final by = summary['by_status'] as Map;
    expect(by.values.fold<int>(0, (a, b) => a + (b as int)), summary['all']);
  });

  test('cardiologist publishes a report; admin sees it', () async {
    final list = body(await call('cardio', 'GET', '/ecg-records', query: {'status': 'requested'}));
    final id = (list['data'] as List).first['id'] as int;
    expect((list['data'] as List).first['actions']['diagnose'], isTrue);
    final missing = await call('cardio', 'POST', '/ecg-records/$id/diagnose', data: {'action': 'publish'});
    expect(missing.status, 422);
    final pub = await call('cardio', 'POST', '/ecg-records/$id/diagnose', data: {
      'action': 'publish',
      'ecg_status': 'abnormal',
      'cardiologist_report': '<p>Sinus tachycardia.</p>',
      'hr': '108',
      'qt': '370',
      'qtc': '430',
      'qt_by_qtc': '0.86',
    });
    expect(pub.status, 200);
    final seen = body(await call('admin', 'GET', '/ecg-records/$id'))['data'];
    expect(seen['status'], 'reported');
    expect(seen['measurements']['hr'], '108');
    expect(seen['report_pdf_url'], 'demo://report/$id');
  });

  test('admin adds a client with a device, then a second device', () async {
    final before = body(await call('admin', 'GET', '/devices'))['meta']['total'] as int;
    final created = await call('admin', 'POST', '/clients', data: {
      'name': 'Harmony Heart Centre',
      'email': 'harmony@example.com',
      'password': 'Harmony@123',
      'password_confirmation': 'Harmony@123',
      'hospital_name': 'Harmony Heart Centre',
      'doctor_name': 'Dr. Leela Nair',
      'phone_number': '9822011122',
      'address': 'Kochi',
      'multi_hospital_access': false,
      'devices': ['Dr.Cardio/9999-0001'],
    });
    expect(created.status, 200, reason: '${created.data}');
    final dup = await call('admin', 'POST', '/clients', data: {
      'name': 'X',
      'email': 'harmony@example.com',
      'password': 'Harmony@123',
      'password_confirmation': 'Harmony@123',
      'hospital_name': 'X',
      'doctor_name': 'X',
      'phone_number': '1',
      'address': 'X',
    });
    expect(dup.status, 422);
    expect((body(dup)['errors'] as Map).containsKey('email'), isTrue);

    final hospitals = body(await call('admin', 'GET', '/lookups/hospitals'))['data'] as List;
    final harmony = hospitals.firstWhere((h) => h['name'] == 'Harmony Heart Centre');
    final dev = await call('admin', 'POST', '/devices', data: {'hospital_id': harmony['id'], 'intrument_id': 'Dr.Cardio/9999-0002'});
    expect(dev.status, 200, reason: '${dev.data}');
    final after = body(await call('admin', 'GET', '/devices'))['meta']['total'] as int;
    expect(after, before + 2);
    final again = await call('admin', 'POST', '/devices', data: {'hospital_id': harmony['id'], 'intrument_id': 'Dr.Cardio/9999-0002'});
    expect(again.status, 422);
  });

  test('client adds a staff member; exports return files', () async {
    final add = await call('client', 'POST', '/staff', data: {
      'name': 'Ravi Teja',
      'email': 'ravi.teja@example.com',
      'phone_number': '9000011111',
      'password': 'Ravi@1234',
      'password_confirmation': 'Ravi@1234',
    });
    expect(add.status, 200, reason: '${add.data}');
    final staff = body(await call('client', 'GET', '/staffs', query: {'search': 'Ravi'}));
    expect(staff['meta']['total'], 1);

    final zip = await call('client', 'POST', '/exports/ecg', data: {'type': 'pdf'});
    expect(zip.status, 200);
    final bytes = zip.data as List<int>;
    expect(bytes.sublist(0, 2), [0x50, 0x4B]); // "PK"
    final counts = await call('cardio', 'POST', '/exports/ecg-counts', data: {'month': '${DateTime.now().month}', 'year': '${DateTime.now().year}'});
    expect(counts.status, 200);
  });

  test('roles cannot reach other roles\' sections', () async {
    expect((await call('client', 'GET', '/clients')).status, 403);
    expect((await call('cardio', 'GET', '/devices')).status, 403);
    expect((await call('oem', 'GET', '/oem-users')).status, 403);
    expect((await call('nobody', 'GET', '/dashboard')).status, 401);
  });
}
