import 'package:flutter/material.dart';

class Responsive {
  static double width(BuildContext context) =>
      MediaQuery.of(context).size.width;

  static double height(BuildContext context) =>
      MediaQuery.of(context).size.height;

  static bool isMobile(BuildContext context) => width(context) < 600;

  static bool isTablet(BuildContext context) =>
      width(context) >= 600 && width(context) < 1024;

  static bool isDesktop(BuildContext context) => width(context) >= 1024;

  static double horizontalPadding(BuildContext context) {
    if (isDesktop(context)) return 40;
    if (isTablet(context)) return 28;
    return 18;
  }

  static double cardWidth(BuildContext context) {
    if (isDesktop(context)) return 420;
    if (isTablet(context)) return 500;
    return width(context) * 0.92;
  }

  static double avatarRadius(BuildContext context) {
    return isMobile(context) ? 24 : 32;
  }

  static double titleSize(BuildContext context) {
    return isMobile(context) ? 24 : 30;
  }

  static double bodySize(BuildContext context) {
    return isMobile(context) ? 14 : 16;
  }

  static double buttonHeight(BuildContext context) {
    return isMobile(context) ? 52 : 58;
  }
}
