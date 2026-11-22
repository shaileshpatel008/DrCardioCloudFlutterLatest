import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../core/services/auth_service.dart';
import 'app_routes.dart';

/// Keeps signed-out users on the sign-in screen and stops a role from
/// opening a section the server did not grant it (`menu` keys). The API
/// enforces the same rules; this just avoids showing a screen that would
/// only return "no access".
class AuthGuard extends GetMiddleware {
  AuthGuard([this.menuKey]);

  final String? menuKey;

  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthService>();
    if (!auth.isLoggedIn) return const RouteSettings(name: AppRoutes.login);
    final key = menuKey;
    if (key != null && !(auth.current?.can(key) ?? false)) {
      return const RouteSettings(name: AppRoutes.dashboard);
    }
    return null;
  }
}

/// Signed-in users skip the sign-in screen.
class GuestGuard extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    final auth = Get.find<AuthService>();
    return auth.isLoggedIn ? const RouteSettings(name: AppRoutes.dashboard) : null;
  }
}
