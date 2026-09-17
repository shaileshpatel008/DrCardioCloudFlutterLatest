import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../routes/app_routes.dart';

/// Port of `MainActivity`/`MyAccountsActivity`'s `helpDialog()` — the old
/// app's bottom-nav Help tab was just this Call/WhatsApp contact prompt
/// (its FAQ list screen, `HelpActivity`, was already dead code — its own
/// navigation was commented out in favor of this dialog). This rebuild
/// keeps the FAQ content since it's genuinely useful, and adds the same
/// direct-contact actions alongside it rather than replacing the screen.
class HelpController extends GetxController {
  static const _supportPhone = '+919638389333';

  void replayWalkthrough() => Get.toNamed(AppRoutes.onboarding);

  /// `tel:` opens the dialer pre-filled (same as the original's
  /// `Intent.ACTION_DIAL`) rather than placing the call directly — the
  /// user still has to tap Call themselves.
  Future<void> callSupport() => launchUrl(Uri.parse('tel:$_supportPhone'), mode: LaunchMode.externalApplication);

  /// Same `api.whatsapp.com/send` deep link and canned "Hi!" opener the
  /// original used.
  Future<void> chatOnWhatsApp() => launchUrl(
        Uri.https('api.whatsapp.com', '/send', {'phone': _supportPhone, 'text': 'Hi!'}),
        mode: LaunchMode.externalApplication,
      );
}
