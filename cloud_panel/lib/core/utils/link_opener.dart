import 'package:url_launcher/url_launcher.dart';

import '../widgets/app_toast.dart';

/// Opens report PDFs and contact links: a new browser tab on web, the
/// system PDF viewer / browser on Android and iOS.
class LinkOpener {
  LinkOpener._();

  static Future<void> open(String? url) async {
    if (url == null || url.isEmpty) {
      AppToast.error('This file is not available yet.');
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      AppToast.error('This link is not valid.');
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    if (!ok) AppToast.error('Couldn\'t open the file on this device.');
  }

  static Future<void> call(String phone) => launchUrl(Uri(scheme: 'tel', path: phone.replaceAll(' ', '')));
  static Future<void> mail(String email) => launchUrl(Uri(scheme: 'mailto', path: email));

  static Future<void> map(String lat, String lng) =>
      launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'), mode: LaunchMode.externalApplication);
}
