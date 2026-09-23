import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../theme/app_colors.dart';
import '../services/connectivity_service.dart';

/// Full-width red "no internet" strip shown right above the bottom
/// navigation bar whenever [ConnectivityService.isOnline] is false — the
/// original app never had an equivalent persistent banner (only a one-off
/// Toast on a manual retry), but silently gating network calls with no
/// visible status left users guessing why an upload wasn't happening; this
/// makes the offline state obvious at a glance without leaving the screen.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    return Obx(() {
      if (connectivity.isOnline.value) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        color: AppColors.toastError,
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 12),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'No internet connection',
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    });
  }
}
