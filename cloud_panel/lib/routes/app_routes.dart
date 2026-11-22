abstract class AppRoutes {
  AppRoutes._();

  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';

  static const ecgRecords = '/ecg-records';
  static const ecgDetail = '/ecg/:id';
  static const diagnose = '/ecg/:id/diagnose';
  static const downloadEcg = '/download-ecg';
  static const exportCounts = '/export-ecg-counts';

  static const clients = '/clients';
  static const clientNew = '/new-client';
  static const clientDetail = '/client/:id';
  static const clientEdit = '/client/:id/edit';
  static const adminStaffs = '/staff';
  static const myStaff = '/my-staff';
  static const cardiologists = '/cardiologists';
  static const devices = '/devices';
  static const oemUsers = '/oem-users';

  static const profile = '/profile';
  static const notifications = '/notifications';

  static String ecgDetailPath(int id) => '/ecg/$id';
  static String diagnosePath(int id) => '/ecg/$id/diagnose';
  static String clientPath(int id) => '/client/$id';
  static String clientEditPath(int id) => '/client/$id/edit';
}
