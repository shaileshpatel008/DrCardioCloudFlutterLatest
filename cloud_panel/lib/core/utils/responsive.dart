import 'package:flutter/widgets.dart';

/// Layout breakpoints used across the panel.
///  - phone  (< 760):  drawer navigation, card lists, stacked forms
///  - tablet (760–1100): collapsed icon rail, tables scroll horizontally
///  - desktop (>= 1100): full sidebar + wide tables
class Responsive {
  Responsive._();

  static const double phone = 760;
  static const double desktop = 1100;

  static double width(BuildContext context) => MediaQuery.sizeOf(context).width;
  static bool isPhone(BuildContext context) => width(context) < phone;
  static bool isTablet(BuildContext context) => width(context) >= phone && width(context) < desktop;
  static bool isDesktop(BuildContext context) => width(context) >= desktop;

  static EdgeInsets pagePadding(BuildContext context) =>
      isPhone(context) ? const EdgeInsets.fromLTRB(16, 16, 16, 32) : const EdgeInsets.fromLTRB(32, 28, 32, 48);
}
