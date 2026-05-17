import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/catalog_dao.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/pricing/pricing.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../settings/branch_selection_provider.dart';
import 'catalog_providers.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branchAsync = ref.watch(selectedBranchProvider);

    return Scaffold(
      appBar: AppBar(
        title: branchAsync.maybeWhen(
          data: (b) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Menu'),
              if (b != null)
                Text(
                  b.name,
                  style: AppTypography.labelSm
                      .copyWith(color: context.colors.textSecondary),
                ),
            ],
          ),
          orElse: () => const Text('Menu'),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/products/new'),
        icon: const Icon(Icons.add),
        label: const Text('Tambah Produk'),
      ),
      body: branchAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat cabang',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (branch) {
          if (branch == null) {
            return const AppEmptyState(
              title: 'Belum memilih cabang',
              icon: Icons.store_outlined,
              message: 'Pilih cabang aktif di Pengaturan.',
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari nama produk atau kategori…',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              Expanded(child: _List(branchId: branch.id, query: _query)),
            ],
          );
        },
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.branchId, required this.query});

  final String branchId;
  final String query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(branchMenuFullProvider(branchId));

    return menuAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => AppEmptyState(
        title: 'Gagal memuat menu',
        icon: Icons.error_outline,
        message: e.toString(),
      ),
      data: (items) {
        final filtered = _filter(items, query);
        if (filtered.isEmpty) {
          return AppEmptyState(
            title: query.isEmpty ? 'Belum ada produk' : 'Tidak ditemukan',
            icon: query.isEmpty
                ? Icons.restaurant_menu_outlined
                : Icons.search_off_outlined,
            message: query.isEmpty
                ? 'Tap "Tambah Produk" untuk membuat menu baru.'
                : null,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.xxxxl,
          ),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (_, i) => _Tile(item: filtered[i], branchId: branchId),
        );
      },
    );
  }

  List<BranchProductWithProductRow> _filter(
    List<BranchProductWithProductRow> list,
    String query,
  ) {
    if (query.isEmpty) return list;
    return list.where((bp) {
      final name = (bp.branchProduct.customName ?? bp.product.name).toLowerCase();
      final category = (bp.product.category ?? '').toLowerCase();
      return name.contains(query) || category.contains(query);
    }).toList();
  }
}

class _Tile extends ConsumerWidget {
  const _Tile({required this.item, required this.branchId});

  final BranchProductWithProductRow item;
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = item.product;
    final bp = item.branchProduct;
    final now = DateTime.now();

    final effective = effectiveUnitPrice(
      basePrice: product.basePrice,
      priceOverride: bp.priceOverride,
      discountPercentage: bp.discountPercentage,
      discountValidUntil: bp.discountValidUntil,
      now: now,
    );
    final original = bp.priceOverride ?? product.basePrice;
    final hasReducedPrice = effective < original;

    final discountActive = bp.discountPercentage > 0 &&
        (bp.discountValidUntil == null ||
            bp.discountValidUntil!.isAfter(now));

    final inactive = !product.isActive;

    return Opacity(
      opacity: bp.isAvailable && !inactive ? 1.0 : 0.6,
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadius.radiusLg,
        child: InkWell(
          onTap: () => context.push('/products/${product.id}'),
          borderRadius: AppRadius.radiusLg,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(color: context.colors.border),
              borderRadius: AppRadius.radiusLg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bp.customName ?? product.name,
                              style: AppTypography.titleMd,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (discountActive) ...[
                            const SizedBox(width: AppSpacing.sm),
                            AppBadge(
                              label:
                                  '-${bp.discountPercentage.toStringAsFixed(0)}%',
                              icon: Icons.local_offer_outlined,
                              tone: AppBadgeTone.accent,
                            ),
                          ],
                          if (inactive) ...[
                            const SizedBox(width: AppSpacing.sm),
                            const AppBadge(
                              label: 'Nonaktif',
                              icon: Icons.block,
                              tone: AppBadgeTone.neutral,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          if (product.category != null) ...[
                            Text(
                              product.category!,
                              style: AppTypography.bodySm.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                            Text(
                              ' · ',
                              style: AppTypography.bodySm.copyWith(
                                color: context.colors.textTertiary,
                              ),
                            ),
                          ],
                          Text(
                            formatRupiah(effective),
                            style: AppTypography.bodyMd.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (hasReducedPrice) ...[
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              formatRupiah(original),
                              style: AppTypography.labelSm.copyWith(
                                color: context.colors.textTertiary,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Switch(
                  value: bp.isAvailable,
                  onChanged: inactive
                      ? null
                      : (v) async {
                          await ref
                              .read(catalogDaoProvider)
                              .setBranchProductAvailability(
                                productId: product.id,
                                branchId: branchId,
                                isAvailable: v,
                              );
                        },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
