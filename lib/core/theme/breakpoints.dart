/// Responsive layout breakpoints. Aligned with Material 3 window-size classes.
///
/// - **Compact** (< 600dp)  → phone, BottomNavigationBar
/// - **Medium** (600–839dp) → small tablet / foldable, NavigationRail
/// - **Expanded** (≥ 840dp) → large tablet / desktop, NavigationRail extended
abstract final class AppBreakpoint {
  AppBreakpoint._();

  static const double tablet = 600.0;
  static const double railExtended = 840.0;
}
