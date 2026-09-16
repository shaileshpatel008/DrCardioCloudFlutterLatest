import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'core/services/app_logger.dart';
import 'core/services/bluetooth/bluetooth_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/storage_service.dart';
import 'data/repositories/ecg_repository.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await AppLogger.init();

      // App-wide default: transparent status bar with dark icons, matching
      // the light background every screen has except the red AppBar ones
      // (which override this via AppBarTheme.systemOverlayStyle) and the
      // dark Live ECG/PDF viewer screens (which set their own). Without
      // this, a screen with no AppBar and no explicit override — e.g. the
      // Settings tab — just showed whatever Android's un-styled default
      // is: an opaque black bar that clashed with the light content below
      // it instead of blending into it.
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ));

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
      final connectivity = await Get.putAsync(() => ConnectivityService().init(), permanent: true);
      final bluetoothService = Get.put(BluetoothService(), permanent: true);
      // Port of `MainActivity`'s `NetworkLiveData` observer: drain the
      // pending-upload queue as soon as connectivity returns, instead of
      // only syncing at the moment a new recording is saved or when the
      // user manually retries from the Offline Reports screen.
      connectivity.onReconnect(() => EcgRepository().syncPendingQueue());
      // A device connected for the first time while offline is used
      // unvalidated for that session (see
      // DeviceScanController._validateWithServer) — this retries
      // validation with the server as soon as connectivity is back.
      connectivity.onReconnect(() => EcgRepository().revalidateConnectedDevice(bluetoothService));

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
      // Do NOT hardcode this to a specific screen (login/home/etc.) — the
      // splash route runs SplashController's session/onboarding check and
      // sends the user to the right place. Hardcoding here skips that
      // check entirely, e.g. showing login even when already logged in.
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
    );
  }
}
