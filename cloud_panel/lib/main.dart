import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:get/get.dart';

import 'core/constants/app_constants.dart';
import 'core/services/auth_service.dart';
import 'core/services/storage_service.dart';
import 'modules/shell/shell_controller.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs on web (/clients instead of /#/clients).
  if (kIsWeb) usePathUrlStrategy();

  await StorageService.instance.init();
  final auth = Get.put(AuthService().init(), permanent: true);
  Get.put(ShellController(), permanent: true);

  runApp(DrCardioPanelApp(signedIn: auth.isLoggedIn));
}

class DrCardioPanelApp extends StatelessWidget {
  const DrCardioPanelApp({super.key, required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: signedIn ? AppRoutes.dashboard : AppRoutes.login,
      getPages: AppPages.pages,
      unknownRoute: AppPages.unknown,
      defaultTransition: Transition.fadeIn,
      transitionDuration: const Duration(milliseconds: 220),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en', 'IN'), Locale('en', 'US')],
      locale: const Locale('en', 'IN'),
    );
  }
}
