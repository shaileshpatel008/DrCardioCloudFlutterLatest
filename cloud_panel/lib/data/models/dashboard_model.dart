import '../../core/utils/json_utils.dart';
import 'ecg_record_model.dart';

class DashboardCounts {
  const DashboardCounts({
    this.clients = 0,
    this.devices = 0,
    this.ecgRecords = 0,
    this.cardiologists = 0,
    this.staffs = 0,
    this.normalEcg = 0,
    this.abnormalEcg = 0,
  });

  final int clients, devices, ecgRecords, cardiologists, staffs, normalEcg, abnormalEcg;

  factory DashboardCounts.fromJson(Map<String, dynamic> j) => DashboardCounts(
        clients: asIntOr(j['clients']),
        devices: asIntOr(j['devices']),
        ecgRecords: asIntOr(j['ecg_records']),
        cardiologists: asIntOr(j['cardiologists']),
        staffs: asIntOr(j['staffs']),
        normalEcg: asIntOr(j['normal_ecg']),
        abnormalEcg: asIntOr(j['abnormal_ecg']),
      );
}

class DailyCount {
  const DailyCount(this.date, this.total);
  final DateTime date;
  final int total;
}

class DashboardInsights {
  const DashboardInsights({
    this.daily = const [],
    this.monthPending = 0,
    this.monthRequested = 0,
    this.monthReported = 0,
    this.monthNoCredit = 0,
    this.monthNormal = 0,
    this.monthAbnormal = 0,
    this.avgTatMinutes,
  });

  final List<DailyCount> daily;
  final int monthPending, monthRequested, monthReported, monthNoCredit;
  final int monthNormal, monthAbnormal;
  final int? avgTatMinutes;

  int get monthTotal => monthPending + monthRequested + monthReported + monthNoCredit;
  int get dailyTotal => daily.fold(0, (a, b) => a + b.total);

  factory DashboardInsights.fromJson(Map<String, dynamic> j) {
    final s = asMap(j['month_status']);
    final e = asMap(j['month_ecg_status']);
    return DashboardInsights(
      daily: asMapList(j['daily'])
          .map((d) => DailyCount(DateTime.tryParse(asStringOr(d['date'])) ?? DateTime.now(), asIntOr(d['total'])))
          .toList(),
      monthPending: asIntOr(s['pending']),
      monthRequested: asIntOr(s['requested']),
      monthReported: asIntOr(s['reported']),
      monthNoCredit: asIntOr(s['no_credit']),
      monthNormal: asIntOr(e['normal']),
      monthAbnormal: asIntOr(e['abnormal']),
      avgTatMinutes: asInt(j['avg_tat_minutes']),
    );
  }
}

class DashboardData {
  const DashboardData({required this.tiles, required this.counts, required this.insights, required this.recent});

  /// Tile keys the web dashboard shows for this role, in order.
  final List<String> tiles;
  final DashboardCounts counts;
  final DashboardInsights insights;
  final List<EcgRecord> recent;

  factory DashboardData.fromJson(Map<String, dynamic> j) => DashboardData(
        tiles: (j['tiles'] is List) ? (j['tiles'] as List).map((e) => e.toString()).toList() : const ['ecg_records'],
        counts: DashboardCounts.fromJson(asMap(j['counts'])),
        insights: DashboardInsights.fromJson(asMap(j['insights'])),
        recent: asMapList(j['recent']).map(EcgRecord.fromJson).toList(),
      );
}
