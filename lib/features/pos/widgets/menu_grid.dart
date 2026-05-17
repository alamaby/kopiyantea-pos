import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/daos/catalog_dao.dart';
import '../../../core/pricing/pricing.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../cart_provider.dart';
import '../menu_provider.dart';

class MenuGrid extends ConsumerWidget {
  const MenuGrid({required this.branchId, super.key});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(menuProductsProvider(branchId));

    return productsAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => AppEmptyState(
        title: 'Gagal memuat menu',
        icon: Icons.error_outline,
        message: e.toString(),
      ),
      data: (products) {
        if (products.isEmpty) {
          return const AppEmptyState(
            title: 'Belum ada menu',
            icon: Icons.restaurant_menu_outlined,
            message: 'Tambahkan produk dari layar Menu.',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 0.82,
          ),
          itemCount: products.length,
          itemBuilder: (_, i) => _MenuTile(item: products[i]),
        );
      },
    );
  }
}

class _MenuTile extends ConsumerWidget {
  const _MenuTile({required this.item});

  final BranchProductWithProductRow item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = item.product;
    final bp = item.branchProduct;
    final now = DateTime.now();

    final discountActive = bp.discountPercentage > 0 &&
        (bp.discountValidUntil == null ||
            bp.discountValidUntil!.isAfter(now));

    final effectivePrice = effectiveUnitPrice(
      basePrice: product.basePrice,
      priceOverride: bp.priceOverride,
      discountPercentage: bp.discountPercentage,
      discountValidUntil: bp.discountValidUntil,
      now: now,
    );
    final originalPrice = bp.priceOverride ?? product.basePrice;
    final hasReducedPrice = effectivePrice < originalPrice;

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          ref.read(cartNotifierProvider.notifier).addItem(
                product: product,
                branchProduct: bp,
              );
        },
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (discountActive)
                AppBadge(
                  label: '-${bp.discountPercentage.toStringAsFixed(0)}%',
                  icon: Icons.local_offer_outlined,
                  tone: AppBadgeTone.accent,
                )
              else
                const SizedBox(height: 22),
              const Spacer(),
              Text(
                bp.customName ?? product.name,
                style: AppTypography.titleMd,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (product.category != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  product.category!,
                  style: AppTypography.labelXs.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatRupiah(effectivePrice),
                style: AppTypography.headlineMd
                    .copyWith(color: AppColors.primary),
              ),
              if (hasReducedPrice)
                Text(
                  formatRupiah(originalPrice),
                  style: AppTypography.labelSm.copyWith(
                    color: context.colors.textTertiary,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
