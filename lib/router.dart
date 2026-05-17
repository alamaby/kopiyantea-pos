import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/widgets/adaptive_shell.dart';
import 'features/customers/customer_form_screen.dart';
import 'features/customers/customer_list_screen.dart';
import 'features/inventory/inventory_detail_screen.dart';
import 'features/inventory/inventory_list_screen.dart';
import 'features/more/more_screen.dart';
import 'features/placeholders/placeholder_screen.dart';
import 'features/pos/pos_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/transactions/transaction_detail_screen.dart';
import 'features/transactions/transaction_list_screen.dart';

/// Typed shell routing via [StatefulShellRoute.indexedStack].
///
/// Each branch keeps its own navigator stack and scroll position — important
/// for POS, where switching tabs must NOT lose cart state or scroll offset.
///
/// Routes outside the shell (e.g. `/more/customers`) push as full-screen
/// detail pages without the bottom nav / rail.
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/pos',
    routes: [
      // Legacy `/` redirect — bookmarks survive.
      GoRoute(path: '/', redirect: (_, __) => '/pos'),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AdaptiveShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pos',
                name: 'pos',
                builder: (_, __) => const PosScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/products',
                name: 'products',
                builder: (_, __) => const PlaceholderScreen(title: 'Menu'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inventory',
                name: 'inventory',
                builder: (_, __) => const InventoryListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                name: 'transactions',
                builder: (_, __) => const TransactionListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                name: 'more',
                builder: (_, __) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),

      // Full-screen detail pages (no shell)
      GoRoute(
        path: '/transactions/:id',
        name: 'transactionDetail',
        builder: (_, state) => TransactionDetailScreen(
          transactionId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/inventory/:id',
        name: 'inventoryDetail',
        builder: (_, state) => InventoryDetailScreen(
          itemId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/more/customers',
        name: 'customers',
        builder: (_, __) => const CustomerListScreen(),
      ),
      GoRoute(
        path: '/more/customers/new',
        name: 'customerNew',
        builder: (_, __) => const CustomerFormScreen(),
      ),
      GoRoute(
        path: '/more/customers/:id',
        name: 'customerEdit',
        builder: (_, state) =>
            CustomerFormScreen(customerId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/more/reports',
        name: 'reports',
        builder: (_, __) => const PlaceholderScreen(title: 'Laporan'),
      ),
      GoRoute(
        path: '/more/settings',
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route tidak ditemukan: ${state.uri}')),
    ),
  );
});
