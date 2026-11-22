/// Date presets offered by the panel (PdfsController::$dateFilter).
enum DatePreset { today, yesterday, last7, last14, last30, thisWeek, lastWeek, thisMonth, lastMonth, custom }

extension DatePresetX on DatePreset {
  String get apiValue => switch (this) {
        DatePreset.today => 'today',
        DatePreset.yesterday => 'yesterday',
        DatePreset.last7 => '7',
        DatePreset.last14 => '14',
        DatePreset.last30 => '30',
        DatePreset.thisWeek => 'this_week',
        DatePreset.lastWeek => 'last_week',
        DatePreset.thisMonth => 'this_month',
        DatePreset.lastMonth => 'last_month',
        DatePreset.custom => 'custom',
      };

  String get label => switch (this) {
        DatePreset.today => 'Today',
        DatePreset.yesterday => 'Yesterday',
        DatePreset.last7 => 'Last 7 days',
        DatePreset.last14 => 'Last 14 days',
        DatePreset.last30 => 'Last 30 days',
        DatePreset.thisWeek => 'This week',
        DatePreset.lastWeek => 'Last week',
        DatePreset.thisMonth => 'This month',
        DatePreset.lastMonth => 'Last month',
        DatePreset.custom => 'Custom range',
      };
}

class AppConstants {
  AppConstants._();

  static const appName = 'Dr. Cardio ECG Cloud';
  static const pageSizes = [10, 25, 50, 100];

  /// How often the cardiologist bell refreshes (the web panel uses 60 s).
  static const notificationPoll = Duration(seconds: 60);

  /// The web ECG list auto-refreshes every 2 minutes.
  static const ecgListAutoRefresh = Duration(minutes: 2);

  static const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
}
