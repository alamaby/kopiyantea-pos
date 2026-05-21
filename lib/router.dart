import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/widgets/adaptive_shell.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/bank_accounts/bank_accounts_screen.dart';
import 'features/catalog/catalog_screen.dart';
import 'features/catalog/product_detail_screen.dart';
import 'features/catalog/product_form_screen.dart';
import 'features/customers/customer_form_screen.dart';
import 'features/customers/customer_list_screen.dart';
import 'features/inventory/inventory_detail_screen.dart';
import 'features/inventory/inventory_list_screen.dart';
import 'features/more/more_screen.dart';
import 'features/placeholders/placeholder_screen.dart';
import 'features/pos/pos_screen.dart';
import 'features/reports/reports_screen.dart';
import 'features/inventory/inventory_item_form_screen.dart';
import 'features/inventory/stock_movement_screen.dart';
import 'features/modifiers/option_group_form_screen.dart';
import 'features/modifiers/option_groups_screen.dart';
import 'features/modifiers/product_options_screen.dart';
import 'features/settings/outbox_queue_screen.dart';
import 'features/shift/shift_closing_screen.dart';
import 'features/settings/printer_settings_screen.dart';
import 'features/settings/qris_settings_screen.dart';
import 'features/settings/receipt_settings_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/settings/tax_settings_screen.dart';
import 'features/users/user_form_screen.dart';
import 'features/users/user_list_screen.dart';
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
  // Re-evaluate redirect when auth state flips (sign in / sign out).
  final refresh = _AuthRefreshNotifier(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/pos',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final isAuthed = auth is Authenticated;
      final isLoading = auth is AuthLoading;
      final isLogin = state.matchedLocation == '/login';

      // During initial session restore, don't redirect — keeps screen stable.
      if (isLoading) return null;
      if (!isAuthed && !isLogin) return '/login';
      if (isAuthed && isLogin) return '/pos';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
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
                builder: (_, __) => const CatalogScreen(),
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
        path: '/products/new',
        name: 'productNew',
        builder: (_, __) => const ProductFormScreen(),
      ),
      GoRoute(
        path: '/products/:id/master',
        name: 'productMasterEdit',
        builder: (_, state) => ProductFormScreen(
          productId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/products/:id',
        name: 'productDetail',
        builder: (_, state) => ProductDetailScreen(
          productId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/transactions/:id',
        name: 'transactionDetail',
        builder: (_, state) => TransactionDetailScreen(
          transactionId: state.pathParameters['id']!,
        ),
      ),
      // FEAT-005 — more-specific routes MUST come before `/inventory/:id` so
      // GoRouter doesn't match "new"/"edit"/"movement" as an id.
      GoRoute(
        path: '/inventory/new',
        name: 'inventoryItemNew',
        builder: (_, __) => const InventoryItemFormScreen(),
      ),
      GoRoute(
        path: '/inventory/:id/edit',
        name: 'inventoryItemEdit',
        builder: (_, state) => InventoryItemFormScreen(
          itemId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: '/inventory/:id/movement',
        name: 'inventoryItemMovement',
        builder: (_, state) => StockMovementScreen(
          itemId: state.pathParameters['id']!,
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
        builder: (_, __) => const ReportsScreen(),
      ),
      // ENH-001 — daily cash reconciliation.
      GoRoute(
        path: '/more/reports/closing',
        name: 'shiftClosing',
        builder: (_, __) => const ShiftClosingScreen(),
      ),
      GoRoute(
        path: '/more/settings',
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/more/settings/printer',
        name: 'printerSettings',
        builder: (_, __) => const PrinterSettingsScreen(),
      ),
      // FEAT-003 — outbox queue inspector.
      GoRoute(
        path: '/more/settings/sync',
        name: 'outboxQueue',
        builder: (_, __) => const OutboxQueueScreen(),
      ),
      // FEAT-004 — per-branch tax settings (owner-gated in Settings UI).
      GoRoute(
        path: '/more/settings/tax',
        name: 'taxSettings',
        builder: (_, __) => const TaxSettingsScreen(),
      ),
      // FEAT-013 — per-branch static QRIS upload (owner-gated).
      GoRoute(
        path: '/more/settings/qris',
        name: 'qrisSettings',
        builder: (_, __) => const QrisSettingsScreen(),
      ),
      // FEAT-014 — receipt template (header/footer/logo) per branch.
      GoRoute(
        path: '/more/settings/receipt',
        name: 'receiptSettings',
        builder: (_, __) => const ReceiptSettingsScreen(),
      ),
      // FEAT-015 — global bank accounts for transfer payment.
      GoRoute(
        path: '/more/settings/bank-accounts',
        name: 'bankAccounts',
        builder: (_, __) => const BankAccountsScreen(),
      ),
      // FEAT-006 — user management.
      GoRoute(
        path: '/more/settings/users',
        name: 'users',
        builder: (_, __) => const UserListScreen(),
      ),
      GoRoute(
        path: '/more/settings/users/new',
        name: 'userNew',
        builder: (_, __) => const UserFormScreen(),
      ),
      GoRoute(
        path: '/more/settings/users/:id',
        name: 'userEdit',
        builder: (_, state) => UserFormScreen(
          userId: state.pathParameters['id'],
        ),
      ),
      // FEAT-001 — modifier system management.
      GoRoute(
        path: '/more/settings/modifiers',
        name: 'optionGroups',
        builder: (_, __) => const OptionGroupsScreen(),
      ),
      GoRoute(
        path: '/more/settings/modifiers/new',
        name: 'optionGroupNew',
        builder: (_, __) => const OptionGroupFormScreen(),
      ),
      GoRoute(
        path: '/more/settings/modifiers/:id',
        name: 'optionGroupEdit',
        builder: (_, state) => OptionGroupFormScreen(
          groupId: state.pathParameters['id'],
        ),
      ),
      // FEAT-001 — link option groups to a product.
      GoRoute(
        path: '/products/:id/options',
        name: 'productOptions',
        builder: (_, state) => ProductOptionsScreen(
          productId: state.pathParameters['id']!,
        ),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('Route tidak ditemukan: ${state.uri}')),
    ),
  );
});

/// Bridges Riverpod's `authProvider` to GoRouter's `refreshListenable`.
/// Each auth state change fires `notifyListeners()` so the redirect callback
/// re-runs.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    _sub = ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
