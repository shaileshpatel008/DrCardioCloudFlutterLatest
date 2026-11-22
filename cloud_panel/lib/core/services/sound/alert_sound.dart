import 'alert_sound_io.dart' if (dart.library.js_interop) 'alert_sound_web.dart' as impl;

/// Plays the "new ECG for review" chime (the web panel's notification sound).
/// Browsers only allow audio after the user has interacted with the page,
/// so a blocked play attempt is ignored silently.
class AlertSound {
  AlertSound._();

  static Future<void> play() async {
    try {
      await impl.playAlert();
    } catch (_) {}
  }
}
