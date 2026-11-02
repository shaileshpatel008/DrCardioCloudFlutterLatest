/// The 4 selectable PDF report layouts (Settings' "Report Format" row) —
/// each a different visual treatment of the same underlying recording
/// data, picked once as a global default via [StorageService.reportFormat]
/// and used for every report generated after that.
enum ReportFormat {
  /// The pink ECG-paper grid layout hospitals already know, with a
  /// refreshed letterhead/patient-info/comments/params/signature header.
  classic,

  /// Plain white background, light-bordered cells — this app's own
  /// from-scratch redesign.
  modernClean,

  /// Dark sidebar carrying patient info and stat figures; a denser,
  /// less-paper-like 12-lead grid alongside it.
  modernCompact,

  /// Big stat tiles up top, soft light-grey lead cells, a dedicated
  /// interpretation box for the reviewing cardiologist.
  modernDashboard;

  static ReportFormat fromStorageKey(String key) => ReportFormat.values.firstWhere(
        (f) => f.name == key,
        orElse: () => ReportFormat.classic,
      );

  String get label => switch (this) {
        ReportFormat.classic => 'Classic',
        ReportFormat.modernClean => 'Modern Clean',
        ReportFormat.modernCompact => 'Modern Compact',
        ReportFormat.modernDashboard => 'Modern Dashboard',
      };

  String get description => switch (this) {
        ReportFormat.classic => 'Pink ECG grid, blue labels — the familiar look, refreshed header.',
        ReportFormat.modernClean => 'Plain white, light grid — close to today’s report.',
        ReportFormat.modernCompact => 'Dark sidebar with stats, dense trace area.',
        ReportFormat.modernDashboard => 'Big stat tiles up top, light-grid leads below.',
      };
}
