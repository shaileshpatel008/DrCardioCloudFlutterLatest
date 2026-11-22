import 'package:get/get.dart';

import '../modules/cardiologists/bindings/cardiologists_binding.dart';
import '../modules/cardiologists/views/cardiologists_view.dart';
import '../modules/client_detail/bindings/client_detail_binding.dart';
import '../modules/client_detail/views/client_detail_view.dart';
import '../modules/client_form/bindings/client_form_binding.dart';
import '../modules/client_form/views/client_form_view.dart';
import '../modules/clients/bindings/clients_binding.dart';
import '../modules/clients/views/clients_view.dart';
import '../modules/dashboard/bindings/dashboard_binding.dart';
import '../modules/dashboard/views/dashboard_view.dart';
import '../modules/devices/bindings/devices_binding.dart';
import '../modules/devices/views/devices_view.dart';
import '../modules/diagnose/bindings/diagnose_binding.dart';
import '../modules/diagnose/views/diagnose_view.dart';
import '../modules/download_ecg/bindings/download_ecg_binding.dart';
import '../modules/download_ecg/views/download_ecg_view.dart';
import '../modules/ecg_detail/bindings/ecg_detail_binding.dart';
import '../modules/ecg_detail/views/ecg_detail_view.dart';
import '../modules/ecg_records/bindings/ecg_records_binding.dart';
import '../modules/ecg_records/views/ecg_records_view.dart';
import '../modules/export_counts/bindings/export_counts_binding.dart';
import '../modules/export_counts/views/export_counts_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/notifications/views/notifications_view.dart';
import '../modules/oem_users/bindings/oem_users_binding.dart';
import '../modules/oem_users/views/oem_users_view.dart';
import '../modules/profile/bindings/profile_binding.dart';
import '../modules/profile/views/profile_view.dart';
import '../modules/staff/bindings/staff_binding.dart';
import '../modules/staff/views/staff_view.dart';
import 'app_routes.dart';
import 'route_guards.dart';

/// Every route is guarded: signed-out users go to sign-in, and a role can
/// only open the sections its menu (from the API) contains.
class AppPages {
  AppPages._();

  static final unknown = GetPage(
    name: '/not-found',
    page: () => const DashboardView(),
    binding: DashboardBinding(),
    middlewares: [AuthGuard()],
  );

  static final pages = <GetPage>[
    GetPage(name: AppRoutes.splash, page: () => const LoginView(), binding: LoginBinding(), middlewares: [GuestGuard()]),
    GetPage(name: AppRoutes.login, page: () => const LoginView(), binding: LoginBinding(), middlewares: [GuestGuard()]),
    GetPage(name: AppRoutes.dashboard, page: () => const DashboardView(), binding: DashboardBinding(), middlewares: [AuthGuard('dashboard')]),

    // Clinical
    GetPage(name: AppRoutes.ecgRecords, page: () => const EcgRecordsView(), binding: EcgRecordsBinding(), middlewares: [AuthGuard('ecg_records')]),
    GetPage(name: AppRoutes.diagnose, page: () => const DiagnoseView(), binding: DiagnoseBinding(), middlewares: [AuthGuard('export_ecg_counts')]),
    GetPage(name: AppRoutes.ecgDetail, page: () => const EcgDetailView(), binding: EcgDetailBinding(), middlewares: [AuthGuard('ecg_records')]),
    GetPage(name: AppRoutes.downloadEcg, page: () => const DownloadEcgView(), binding: DownloadEcgBinding(), middlewares: [AuthGuard('download_ecg')]),
    GetPage(name: AppRoutes.exportCounts, page: () => const ExportCountsView(), binding: ExportCountsBinding(), middlewares: [AuthGuard('export_ecg_counts')]),
    GetPage(name: AppRoutes.notifications, page: () => const NotificationsView(), middlewares: [AuthGuard()]),

    // Network
    GetPage(name: AppRoutes.clients, page: () => const ClientsView(), binding: ClientsBinding(), middlewares: [AuthGuard('clients')]),
    GetPage(name: AppRoutes.clientNew, page: () => const ClientFormView(), binding: ClientFormBinding(), middlewares: [AuthGuard('clients')]),
    GetPage(name: AppRoutes.clientEdit, page: () => const ClientFormView(), binding: ClientFormBinding(), middlewares: [AuthGuard('clients')]),
    GetPage(name: AppRoutes.clientDetail, page: () => const ClientDetailView(), binding: ClientDetailBinding(), middlewares: [AuthGuard('clients')]),
    GetPage(name: AppRoutes.adminStaffs, page: () => const StaffView(), binding: AdminStaffBinding(), middlewares: [AuthGuard('admin_staffs')]),
    GetPage(name: AppRoutes.myStaff, page: () => const StaffView(), binding: MyStaffBinding(), middlewares: [AuthGuard('client_staffs')]),
    GetPage(name: AppRoutes.cardiologists, page: () => const CardiologistsView(), binding: CardiologistsBinding(), middlewares: [AuthGuard('cardiologists')]),
    GetPage(name: AppRoutes.devices, page: () => const DevicesView(), binding: DevicesBinding(), middlewares: [AuthGuard('devices')]),
    GetPage(name: AppRoutes.oemUsers, page: () => const OemUsersView(), binding: OemUsersBinding(), middlewares: [AuthGuard('oem_users')]),

    // Account
    GetPage(name: AppRoutes.profile, page: () => const ProfileView(), binding: ProfileBinding(), middlewares: [AuthGuard('profile')]),
  ];
}
