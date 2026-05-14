import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/breakpoints.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

/// Adaptive navigation scaffold.
///
/// - `< 600dp` (phone): [BottomNavigationBar] anchored at bottom.
/// - `600–839dp` (tablet portrait): [NavigationRail] collapsed (icon + label).
/// - `≥ 840dp` (tablet landscape / desktop): [NavigationRail] extended.
///
/// Navigation between branches preserves each branch's stack and scroll state
/// via [StatefulNavigationShell]. Re-tapping the active destination pops to
/// the branch root.
class AdaptiveShell extends StatelessWidget {
  const AdaptiveShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const List<_NavDestination> _destinations = [
    _NavDestination(
      label: 'Kasir',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
    ),
    _NavDestination(
      label: 'Menu',
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu,
    ),
    _NavDestination(
      label: 'Stok',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    _NavDestination(
      label: 'Transaksi',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    _NavDestination(
      label: 'Lainnya',
      icon: Icons.menu_outlined,
      selectedIcon: Icons.menu,
    ),
  ];

  void _onTap(int index) {
    // Re-tapping the current destination pops to the branch root.
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width >= AppBreakpoint.tablet) {
          return _RailScaffold(
            shell: navigationShell,
            destinations: _destinations,
            onTap: _onTap,
            extended: width >= AppBreakpoint.railExtended,
          );
        }
        return _BottomNavScaffold(
          shell: navigationShell,
          destinations: _destinations,
          onTap: _onTap,
        );
      },
    );
  }
}

// ─── Layouts ─────────────────────────────────────────────────────────────────

class _BottomNavScaffold extends StatelessWidget {
  const _BottomNavScaffold({
    required this.shell,
    required this.destinations,
    required this.onTap,
  });

  final StatefulNavigationShell shell;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: onTap,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final d in destinations)
            NavigationDestination(
              icon: Icon(d.icon),
              selectedIcon: Icon(d.selectedIcon),
              label: d.label,
            ),
        ],
      ),
    );
  }
}

class _RailScaffold extends StatelessWidget {
  const _RailScaffold({
    required this.shell,
    required this.destinations,
    required this.onTap,
    required this.extended,
  });

  final StatefulNavigationShell shell;
  final List<_NavDestination> destinations;
  final ValueChanged<int> onTap;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: onTap,
            extended: extended,
            labelType: extended
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            leading: extended
                ? const Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xl,
                    ),
                    child: Text(
                      'KopiyanteaPOS',
                      style: AppTypography.headlineMd,
                    ),
                  )
                : null,
            destinations: [
              for (final d in destinations)
                NavigationRailDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: Text(d.label),
                ),
            ],
          ),
          const VerticalDivider(width: 1, color: AppColors.border),
          Expanded(child: shell),
        ],
      ),
    );
  }
}

// ─── Model ───────────────────────────────────────────────────────────────────

class _NavDestination {
  const _NavDestination({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
