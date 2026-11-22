/// Panel API v2 endpoints (see laravel_api_v2/README.md for the full contract).
///
/// The base URL can be overridden at build time, e.g. for a staging server:
///   flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v2
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://cloudecg.drcardio.in/api/v2',
  );

  // Auth
  static const login = '/auth/login';
  static const forgotPassword = '/auth/forgot-password';
  static const me = '/auth/me';
  static const logout = '/auth/logout';

  // Home
  static const dashboard = '/dashboard';
  static const profile = '/profile';
  static const profileLogo = '/profile/logo';
  static const profileSignature = '/profile/signature';

  // Notifications
  static const notifications = '/notifications';
  static const notificationsReadAll = '/notifications/read-all';
  static String notificationRead(int id) => '/notifications/$id/read';

  // ECG records
  static const ecgRecords = '/ecg-records';
  static const ecgSummary = '/ecg-records/summary';
  static String ecgRecord(int id) => '/ecg-records/$id';
  static String ecgReassign(int id) => '/ecg-records/$id/reassign';
  static String ecgAssign(int id) => '/ecg-records/$id/assign';
  static String ecgDiagnose(int id) => '/ecg-records/$id/diagnose';

  // Network
  static const clients = '/clients';
  static String client(int id) => '/clients/$id';
  static String clientStaff(int id) => '/clients/$id/staff';
  static const devices = '/devices';
  static String device(int id) => '/devices/$id';
  static const cardiologists = '/cardiologists';
  static String cardiologist(int id) => '/cardiologists/$id';
  static const oemUsers = '/oem-users';
  static String oemUser(int id) => '/oem-users/$id';
  static const adminStaffs = '/admin-staffs';
  static const myStaffs = '/staffs';
  static const staff = '/staff';
  static String staffMember(int id) => '/staff/$id';

  // Lookups
  static const lookupHospitals = '/lookups/hospitals';
  static const lookupCardiologists = '/lookups/cardiologists';
  static const lookupStaffs = '/lookups/staffs';
  static const lookupDevices = '/lookups/devices';

  // Exports
  static const exportEcg = '/exports/ecg';
  static const exportEcgCount = '/exports/ecg/count';
  static const exportEcgCounts = '/exports/ecg-counts';

  // Public contact details shown on the sign-in screen and sidebar.
  static const supportPhone = '+91 96383 89333';
  static const supportEmail = 'support@drcardio.in';
}
