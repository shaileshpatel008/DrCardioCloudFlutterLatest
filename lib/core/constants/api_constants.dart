/// Real production API contract, read directly out of the Android app's
/// `PathUtil`, `SignInActivity`, `MainActivity` and `ReportActivity`
/// (Volley requests) so the Flutter client speaks to the same backend
/// without any server changes.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://cloudecg.drcardio.in/';

  static const String login = 'api/login';
  static const String uploadPdf = 'api/upload-pdf';

  /// Re-validates the device (by device_id) against the account.
  static const String authDevice = 'api/auth-device';

  /// Refreshes the bearer token and returns the account's report-limit
  /// quota (`report_limit_enabled`, `report_limit`) used to gate new
  /// recordings when a plan cap is hit.
  static const String getToken = 'api/get-token';

  /// GET, account-wide server-side report history — `ReportActivity`'s
  /// primary data source (the Reports tab there never reads local files;
  /// that's `LoadDataActivity`/"Load Data" instead). Returns
  /// `{status, success_data: [{document_name, ecg_record_id, status,
  /// has_assigned_to_cardiologist, document_path}], error_data}`.
  static const String ecgList = 'api/ecg-list';

  /// POST `{ecg_record_id, assign_to_cardiologist: "true"}` — requests
  /// cardiologist review for a previously-uploaded report.
  static const String assignCardiologist = 'api/assign-cardiologist';
}
