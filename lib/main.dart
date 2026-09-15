import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/services/app_logger.dart';
import 'core/services/bluetooth/bluetooth_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/storage_service.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppLogger.init();

      // Framework errors (widget build/layout/paint exceptions) — without
      // this override they only print to the console, not the log file.
      FlutterError.onError = (details) {
        AppLogger.e('Flutter framework error', details.exception, details.stack);
        FlutterError.presentError(details);
      };
      // Anything outside Flutter's own error zone (platform channel
      // callbacks, timers) surfaces here instead of FlutterError.onError.
      PlatformDispatcher.instance.onError = (error, stack) {
        AppLogger.e('Platform dispatcher error', error, stack);
        return true;
      };

      await StorageService.instance.init();
      await Get.putAsync(() => ConnectivityService().init(), permanent: true);
      Get.put(BluetoothService(), permanent: true);

      runApp(const DrCardioApp());
    },
    // Uncaught errors from async code (a Future that rejects with no
    // .catchError, a Stream with no onError) land here — this is almost
    // certainly where an unlogged "Bad state" exception was going before.
    (error, stack) => AppLogger.e('Uncaught zone error', error, stack),
  );
}

class DrCardioApp extends StatelessWidget {
  const DrCardioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Dr. Cardio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.login,
      getPages: AppPages.pages,
    );
  }
}
