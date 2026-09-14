import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/services/bluetooth/bluetooth_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/storage_service.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await StorageService.instance.init();
  await Get.putAsync(() => ConnectivityService().init(), permanent: true);
  Get.put(BluetoothService(), permanent: true);

  runApp(const DrCardioApp());
}

class DrCardioApp extends StatelessWidget {
  const DrCardioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Dr. Cardio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.splash,
      getPages: AppPages.pages,
    );
  }
}
