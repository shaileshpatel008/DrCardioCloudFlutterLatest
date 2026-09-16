import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/ecg_record_model.dart';
import '../../models/patient_model.dart';

/// Local recordings store. Every recording is written here first
/// (`sync_status = pending`); [EcgRepository] uploads and flips it to
/// `synced`, or leaves it `pending`/`failed` for the offline-reports queue
/// to retry — the same "save locally, sync opportunistically" shape as the
/// original app's `PrefHelper.ECGDataList` + `sendOfflineECGDataToServer()`,
/// just backed by SQLite instead of a serialized SharedPreferences blob so
/// large histories ("Load Data") stay queryable.
class EcgLocalDataSource {
  static const _table = 'ecg_records';
  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'drcardio.db');
    _db = await openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id TEXT PRIMARY KEY,
            date_time TEXT,
            patient_json TEXT,
            device_name TEXT,
            filter TEXT,
            gain TEXT,
            lead_data_json TEXT,
            pdf_path TEXT,
            csv_path TEXT,
            dat_path TEXT,
            filtered_csv_path TEXT,
            device_id TEXT,
            latitude TEXT,
            longitude TEXT,
            address TEXT,
            hr TEXT, r TEXT, rr TEXT, pr TEXT, qrs TEXT, qt TEXT, qtc TEXT, qt_by_qtc TEXT,
            sync_status TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE $_table ADD COLUMN dat_path TEXT');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE $_table ADD COLUMN filtered_csv_path TEXT');
        }
      },
    );
    return _db!;
  }

  Future<void> save(EcgRecordModel record) async {
    final db = await _database;
    await db.insert(_table, _toRow(record), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSyncStatus(String id, SyncStatus status) async {
    final db = await _database;
    await db.update(_table, {'sync_status': status.name}, where: 'id = ?', whereArgs: [id]);
  }

  Future<List<EcgRecordModel>> all() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'date_time DESC');
    return rows.map(_fromRow).toList();
  }

  Future<List<EcgRecordModel>> pendingOrFailed() async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: 'sync_status = ? OR sync_status = ?',
      whereArgs: [SyncStatus.pending.name, SyncStatus.failed.name],
      orderBy: 'date_time ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<List<EcgRecordModel>> search(String query) async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: 'patient_json LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'date_time DESC',
    );
    return rows.map(_fromRow).toList();
  }

  Map<String, dynamic> _toRow(EcgRecordModel r) => {
        'id': r.id,
        'date_time': r.dateTime.toIso8601String(),
        'patient_json': jsonEncode(r.patient.toJson()),
        'device_name': r.deviceName,
        'filter': r.filter,
        'gain': r.gain,
        'lead_data_json': jsonEncode(r.leadData),
        'pdf_path': r.pdfPath,
        'csv_path': r.csvPath,
        'dat_path': r.datPath,
        'filtered_csv_path': r.filteredCsvPath,
        'device_id': r.deviceId,
        'latitude': r.latitude,
        'longitude': r.longitude,
        'address': r.address,
        'hr': r.hr,
        'r': r.r,
        'rr': r.rr,
        'pr': r.pr,
        'qrs': r.qrs,
        'qt': r.qt,
        'qtc': r.qtc,
        'qt_by_qtc': r.qtByQtc,
        'sync_status': r.syncStatus.name,
      };

  EcgRecordModel _fromRow(Map<String, dynamic> row) {
    final leadDataRaw = jsonDecode(row['lead_data_json'] as String) as List;
    return EcgRecordModel(
      id: row['id'] as String,
      dateTime: DateTime.parse(row['date_time'] as String),
      patient: PatientModel.fromJson(jsonDecode(row['patient_json'] as String)),
      deviceName: row['device_name'] as String? ?? '',
      filter: row['filter'] as String? ?? '',
      gain: row['gain'] as String? ?? '',
      leadData: leadDataRaw.map((lead) => (lead as List).map((v) => (v as num).toDouble()).toList()).toList(),
      pdfPath: row['pdf_path'] as String?,
      csvPath: row['csv_path'] as String?,
      datPath: row['dat_path'] as String?,
      filteredCsvPath: row['filtered_csv_path'] as String?,
      deviceId: row['device_id'] as String? ?? '',
      latitude: row['latitude'] as String? ?? '',
      longitude: row['longitude'] as String? ?? '',
      address: row['address'] as String? ?? '',
      hr: row['hr'] as String? ?? '',
      r: row['r'] as String? ?? '',
      rr: row['rr'] as String? ?? '',
      pr: row['pr'] as String? ?? '',
      qrs: row['qrs'] as String? ?? '',
      qt: row['qt'] as String? ?? '',
      qtc: row['qtc'] as String? ?? '',
      qtByQtc: row['qt_by_qtc'] as String? ?? '',
      syncStatus: SyncStatus.values.byName(row['sync_status'] as String? ?? 'pending'),
    );
  }
}
