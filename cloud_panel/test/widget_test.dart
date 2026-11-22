import 'package:drcardio_cloud_panel/core/utils/validators.dart';
import 'package:drcardio_cloud_panel/data/models/ecg_record_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('password rules match the Laravel validation (min:6, confirmed)', () {
    expect(Validators.password('12345'), isNotNull);
    expect(Validators.password('123456'), isNull);
    expect(Validators.password('', optional: true), isNull);
    expect(Validators.confirm('abc123', 'abc124'), isNotNull);
    expect(Validators.confirm('abc123', 'abc123'), isNull);
  });

  test('ECG record parses the API shape', () {
    final r = EcgRecord.fromJson({
      'id': 7,
      'file_name': 'Ramesh_K_2026-11-22_14-11-20.pdf',
      'status': 'reported',
      'status_label': 'Reported',
      'ecg_status': 'abnormal',
      'tat_minutes': 8,
      'actions': {'view_report': true, 'delete': true},
      'measurements': {'hr': '88'},
    });
    expect(r.status, ReportStatus.reported);
    expect(r.displayName, 'Ramesh K');
    expect(r.isAbnormal, isTrue);
    expect(r.actions.viewReport, isTrue);
    expect(r.measurements.hr, '88');
  });
}
