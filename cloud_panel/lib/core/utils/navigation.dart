import 'package:get/get.dart';

/// Closes the top route (page, dialog, side panel or sheet) and hands
/// [result] back to whoever opened it.
///
/// Use this instead of `closeRoute()`: while a toast (GetX snackbar) is on
/// screen, `closeRoute()` only dismisses the toast and leaves the page or
/// dialog open — so "Saved" would show but the form would stay up.
///
/// [orGoTo] is where a full page goes when there is nothing to pop — e.g.
/// the page was opened straight from a link or after a browser refresh.
void closeRoute<T>([T? result, String? orGoTo]) {
  final navigator = Get.key.currentState;
  if (navigator != null && navigator.canPop()) {
    navigator.pop<T>(result);
  } else if (orGoTo != null) {
    Get.offAllNamed(orGoTo);
  }
}
