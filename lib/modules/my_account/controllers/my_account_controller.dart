import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/storage_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../routes/app_routes.dart';

/// Port of `MyAccountsActivity` — Help / Feedback / Rate / Share / Sign
/// out, same items as `activity_my_accounts.xml`'s `llHelp`, `llFeedback`,
/// `llReview`, `llShareApp`, `llSignout`. Profile / Load Data / Manage
/// Offline Reports / Settings are deliberately not repeated here — they
/// already live one level up, in Settings' own ACCOUNT section (which
/// also links back to this screen).
class MyAccountController extends GetxController {
  MyAccountController({AuthRepository? authRepository}) : _authRepository = authRepository ?? AuthRepository();

  final AuthRepository _authRepository;
  final storage = StorageService.instance;

  final RxString appVersion = ''.obs;

  @override
  void onInit() {
    super.onInit();
    PackageInfo.fromPlatform().then((info) => appVersion.value = 'v${info.version} (${info.buildNumber})');
  }

  void openHelp() => Get.toNamed(AppRoutes.help);

  Future<void> sendFeedback() async {
    await launchUrl(Uri.parse('mailto:support@drcardio.in?subject=Dr.%20Cardio%20Feedback'));
  }

  Future<void> rateApp() async {
    await launchUrl(Uri.parse('https://play.google.com/store/apps/details?id=com.kavitul.drcardio_flutter'));
  }

  Future<void> shareApp() async {
    await Share.share(
      'Check out Dr. Cardio — a portable ECG in your pocket: '
      'https://play.google.com/store/apps/details?id=com.kavitul.drcardio_flutter',
    );
  }

  Future<void> signOut() async {
    await _authRepository.logout();
    Get.offAllNamed(AppRoutes.login);
  }
}
