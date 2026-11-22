import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<void> playAlert() async {
  final audio = web.HTMLAudioElement()
    ..src = 'assets/assets/sounds/notify.wav'
    ..volume = 0.8;
  await audio.play().toDart;
}
