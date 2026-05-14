/// 4pt spacing scale. See ADR-0013 + master prompt §6.3.
///
/// Use these tokens instead of magic numbers for any [EdgeInsets], [SizedBox],
/// or gap. A widget that does `SizedBox(height: 16)` should use [AppSpacing.lg].
abstract final class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 48.0;
  static const double xxxxl = 64.0;
}
