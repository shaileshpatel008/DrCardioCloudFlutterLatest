import 'package:flutter/services.dart';

Future<void> playAlert() async {
  await SystemSound.play(SystemSoundType.alert);
  await HapticFeedback.mediumImpact();
}
