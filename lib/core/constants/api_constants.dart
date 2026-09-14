/// Real production API contract, read directly out of the Android app's
/// `PathUtil`, `SignInActivity` and `MainActivity` (Volley requests) so the
/// Flutter client speaks to the same backend without any server changes.
///
/// NOTE: there is no server-side "list my reports" endpoint in the current
/// app — `api/ecg-list` only appears as a commented-out, never-wired-up URL
/// in the Java source. Reports/Load Data are read from local device
/// storage there, and sync is upload-only (PDF+CSV). This port keeps that
/// behavior rather than inventing a listing endpoint that doesn't exist.
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
}
