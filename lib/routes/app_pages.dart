import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../modules/device_scan/bindings/device_scan_binding.dart';
import '../modules/device_scan/views/device_scan_view.dart';
import '../modules/help/bindings/help_binding.dart';
import '../modules/help/views/help_view.dart';
import '../modules/home/bindings/home_binding.dart';
import '../modules/home/views/home_view.dart';
import '../modules/live_ecg/bindings/live_ecg_binding.dart';
import '../modules/live_ecg/views/live_ecg_view.dart';
import '../modules/load_data/bindings/load_data_binding.dart';
import '../modules/load_data/views/load_data_view.dart';
import '../modules/login/bindings/login_binding.dart';
import '../modules/login/views/login_view.dart';
import '../modules/my_account/bindings/my_account_binding.dart';
import '../modules/my_account/views/my_account_view.dart';
import '../modules/my_profile/bindings/my_profile_binding.dart';
import '../modules/my_profile/views/my_profile_view.dart';
import '../modules/offline_reports/bindings/offline_reports_binding.dart';
import '../modules/offline_reports/views/offline_reports_view.dart';
import '../modules/onboarding/bindings/onboarding_binding.dart';
import '../modules/onboarding/views/onboarding_view.dart';
import '../modules/patient_info/bindings/patient_info_binding.dart';
import '../modules/patient_info/views/patient_info_view.dart';
import '../modules/pdf_viewer/bindings/pdf_viewer_binding.dart';
import '../modules/pdf_viewer/views/pdf_viewer_view.dart';
import '../modules/settings/bindings/settings_binding.dart';
import '../modules/settings/views/settings_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import 'app_routes.dart';

class AppPages {
  AppPages._();

  static final pages = [
    GetPage(name: AppRoutes.splash, page: () => const SplashView(), binding: SplashBinding()),
    GetPage(name: AppRoutes.onboarding, page: () => const OnboardingView(), binding: OnboardingBinding()),
    GetPage(name: AppRoutes.login, page: () => const LoginView(), binding: LoginBinding()),
    GetPage(name: AppRoutes.home, page: () => const HomeView(), binding: HomeBinding()),
    GetPage(name: AppRoutes.deviceScan, page: () => const DeviceScanView(), binding: DeviceScanBinding()),
    GetPage(name: AppRoutes.patientInfo, page: () => const PatientInfoView(), binding: PatientInfoBinding()),
    GetPage(name: AppRoutes.liveEcg, page: () => const LiveEcgView(), binding: LiveEcgBinding()),
    GetPage(name: AppRoutes.pdfViewer, page: () => const PdfViewerView(), binding: PdfViewerBinding()),
    GetPage(name: AppRoutes.loadData, page: () => const LoadDataView(), binding: LoadDataBinding()),
    GetPage(name: AppRoutes.offlineReports, page: () => const OfflineReportsView(), binding: OfflineReportsBinding()),
    GetPage(name: AppRoutes.myAccount, page: () => const MyAccountView(), binding: MyAccountBinding()),
    GetPage(name: AppRoutes.myProfile, page: () => const MyProfileView(), binding: MyProfileBinding()),
    // Settings/Help/Reports are primarily Home's bottom-nav tabs; these
    // routes exist too (reached from My Account) with a bare app bar since
    // each view already carries its own inline title for the tab context.
    GetPage(
      name: AppRoutes.settings,
      page: () => Scaffold(appBar: AppBar(), body: const SettingsView()),
      binding: SettingsBinding(),
    ),
    GetPage(
      name: AppRoutes.help,
      page: () => Scaffold(appBar: AppBar(), body: const HelpView()),
      binding: HelpBinding(),
    ),
  ];
}
