import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/breakpoints.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../settings/branch_selection_provider.dart';
import 'cart_provider.dart';
import 'widgets/cart_panel.dart';
import 'widgets/held_orders_sheet.dart';
import 'widgets/menu_grid.dart';

/// Returns true if the cart's cached branch row matches the active one on
/// every field that affects checkout totals — so we know whether to re-sync.
bool _branchSyncedForTotals(BranchRow? cached, BranchRow active) {
  if (cached == null) return false;
  return cached.id == active.id &&
      cached.taxPercentage == active.taxPercentage &&
      cached.taxLabel == active.taxLabel &&
      cached.taxInclusive == active.taxInclusive;
}

class PosScreen extends ConsumerWidget {
  const PosScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBranch = ref.watch(selectedBranchProvider);

    // Keep the cart's branch reference in sync with the active selection.
    // `ref.listen` (Riverpod 2.x) does NOT fire for the initial value — so
    // we drive the sync from `ref.watch` results, scheduled post-frame to
    // avoid mutating provider state during build.
    //
    // Re-sync when ANY tax-relevant field differs, not just id — otherwise
    // a tax % change on the same branch would leave the cart with a stale
    // snapshot and totals would not reflect the new rate.
    final cartBranch =
        ref.watch(cartNotifierProvider.select((c) => c.branch));
    final activeBranch = selectedBranch.valueOrNull;
    if (activeBranch != null && !_branchSyncedForTotals(cartBranch, activeBranch)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(cartNotifierProvider.notifier).setBranch(activeBranch);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: selectedBranch.maybeWhen(
          data: (b) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Kasir'),
              if (b != null)
                Text(
                  b.name,
                  style: AppTypography.labelSm
                      .copyWith(color: context.colors.textSecondary),
                ),
            ],
          ),
          orElse: () => const Text('Kasir'),
        ),
        actions: [
          if (activeBranch != null)
            HeldOrdersAction(branchId: activeBranch.id),
        ],
      ),
      body: selectedBranch.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat cabang',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (branch) {
          if (branch == null) return const _NoBranchSelected();
          return LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= AppBreakpoint.tablet;
              return isTablet
                  ? _TabletLayout(branchId: branch.id)
                  : _MobileLayout(branchId: branch.id);
            },
          );
        },
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _NoBranchSelected extends StatelessWidget {
  const _NoBranchSelected();

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      title: 'Belum memilih cabang',
      icon: Icons.store_outlined,
      message: 'Buka Pengaturan untuk memilih cabang yang aktif.',
      action: AppButton(
        label: 'Buka Pengaturan',
        icon: Icons.settings_outlined,
        variant: AppButtonVariant.secondary,
        onPressed: () => context.push('/more/settings'),
      ),
    );
  }
}

// ── Tablet: side-by-side ──────────────────────────────────────────────────────

class _TabletLayout extends StatelessWidget {
  const _TabletLayout({required this.branchId});
  final String branchId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(flex: 3, child: MenuGrid(branchId: branchId)),
        VerticalDivider(width: 1, color: context.colors.border),
        const Expanded(flex: 2, child: CartPanel()),
      ],
    );
  }
}

// ── Mobile: menu + floating cart pill ─────────────────────────────────────────

class _MobileLayout extends ConsumerWidget {
  const _MobileLayout({required this.branchId});
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartState = ref.watch(cartNotifierProvider);
    final notifier = ref.read(cartNotifierProvider.notifier);
    final hasItems = cartState.items.isNotEmpty;

    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(bottom: hasItems ? 84 : 0),
          child: MenuGrid(branchId: branchId),
        ),
        if (hasItems)
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: AppSpacing.lg,
            child: _CartPill(
              itemCount: notifier.itemCount,
              total: notifier.totals?.total ?? 0,
              onTap: () => _showCart(context),
            ),
          ),
      ],
    );
  }

  void _showCart(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.88,
        child: const CartPanel(),
      ),
    );
  }
}

class _CartPill extends StatelessWidget {
  const _CartPill({
    required this.itemCount,
    required this.total,
    required this.onTap,
  });

  final int itemCount;
  final double total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: AppRadius.radiusFull,
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusFull,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, color: Colors.white),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Lihat Keranjang ($itemCount)',
                style: AppTypography.titleMd.copyWith(color: Colors.white),
              ),
              const Spacer(),
              Text(
                formatRupiah(total),
                style: AppTypography.titleMd.copyWith(color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.xs),
              const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
