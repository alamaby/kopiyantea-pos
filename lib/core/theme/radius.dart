import 'package:flutter/widgets.dart';

/// Border radius tokens. See ADR-0013 + master prompt §6.4.
abstract final class AppRadius {
  AppRadius._();

  static const double sm = 4.0; // chips, badges
  static const double md = 8.0; // buttons, inputs
  static const double lg = 12.0; // cards (default)
  static const double xl = 16.0; // bottom sheets, modals
  static const double full = 999.0; // pills, avatars

  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius radiusFull = BorderRadius.all(Radius.circular(full));
}

/// Minimum touch-target dimensions. See master prompt §6.5.
abstract final class AppTouchTarget {
  AppTouchTarget._();

  static const double minimum = 44.0;
  static const double standard = 48.0;
  static const double primaryTablet = 56.0;
  static const double numericKeypad = 64.0;
}
