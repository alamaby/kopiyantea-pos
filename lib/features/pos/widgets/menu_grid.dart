import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
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
import '../../catalog/category_providers.dart';
import '../../modifiers/modifier_providers.dart';
import '../cart_provider.dart';
import '../menu_provider.dart';
import 'option_picker_sheet.dart';

class MenuGrid extends ConsumerStatefulWidget {
  const MenuGrid({required this.branchId, super.key});

  final String branchId;

  @override
  ConsumerState<MenuGrid> createState() => _MenuGridState();
}

class _MenuGridState extends ConsumerState<MenuGrid> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedCategory;
  _MenuViewMode _viewMode = _MenuViewMode.grid;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(menuProductsProvider(widget.branchId));
    final activeCategories = ref.watch(activeCategoriesProvider).valueOrNull;
    final categoryByName = ref.watch(categoryByNameProvider).valueOrNull;

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

        final categories = _categoriesFor(products, activeCategories);
        if (_selectedCategory != null &&
            !categories.contains(_selectedCategory)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _selectedCategory = null);
          });
        }

        final filtered = products
            .where(
              (item) =>
                  _matchesCategory(item, _selectedCategory) &&
                  _matchesQuery(item, _query),
            )
            .toList(growable: false);

        return Column(
          children: [
            _MenuFilters(
              controller: _searchCtrl,
              query: _query,
              viewMode: _viewMode,
              selectedCategory: _selectedCategory,
              categories: categories,
              categoryByName: categoryByName,
              onQueryChanged: (value) {
                setState(() => _query = value.trim());
              },
              onClearQuery: () {
                _searchCtrl.clear();
                setState(() => _query = '');
              },
              onCategoryChanged: (category) {
                setState(() => _selectedCategory = category);
              },
              onViewModeChanged: (mode) {
                setState(() => _viewMode = mode);
              },
            ),
            Expanded(
              child: filtered.isEmpty
                  ? _FilteredEmptyState(
                      query: _query,
                      selectedCategory: _selectedCategory,
                    )
                  : switch (_viewMode) {
                      _MenuViewMode.grid => GridView.builder(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            mainAxisSpacing: AppSpacing.sm,
                            crossAxisSpacing: AppSpacing.sm,
                            childAspectRatio: 0.7,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) => _MenuTile(item: filtered[i]),
                        ),
                      _MenuViewMode.detail => ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (_, i) =>
                              _MenuDetailRow(item: filtered[i]),
                        ),
                    },
            ),
          ],
        );
      },
    );
  }

  List<String> _categoriesFor(
    List<BranchProductWithProductRow> products,
    List<CategoryRow>? activeCategories,
  ) {
    final used = products
        .map((item) => item.product.category?.trim())
        .whereType<String>()
        .where((category) => category.isNotEmpty)
        .toSet();

    final ordered = <String>[];
    for (final category in activeCategories ?? const <CategoryRow>[]) {
      if (used.remove(category.name)) ordered.add(category.name);
    }
    ordered.addAll(used.toList()..sort());
    return ordered;
  }

  bool _matchesCategory(
    BranchProductWithProductRow item,
    String? selectedCategory,
  ) {
    if (selectedCategory == null) return true;
    return item.product.category?.toLowerCase() ==
        selectedCategory.toLowerCase();
  }

  bool _matchesQuery(BranchProductWithProductRow item, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final product = item.product;
    final bp = item.branchProduct;
    return product.name.toLowerCase().contains(q) ||
        (bp.customName?.toLowerCase().contains(q) ?? false) ||
        (product.category?.toLowerCase().contains(q) ?? false) ||
        (product.sku?.toLowerCase().contains(q) ?? false);
  }
}

enum _MenuViewMode { grid, detail }

class _MenuFilters extends StatelessWidget {
  const _MenuFilters({
    required this.controller,
    required this.query,
    required this.viewMode,
    required this.selectedCategory,
    required this.categories,
    required this.categoryByName,
    required this.onQueryChanged,
    required this.onClearQuery,
    required this.onCategoryChanged,
    required this.onViewModeChanged,
  });

  final TextEditingController controller;
  final String query;
  final _MenuViewMode viewMode;
  final String? selectedCategory;
  final List<String> categories;
  final Map<String, CategoryRow>? categoryByName;
  final ValueChanged<String> onQueryChanged;
  final VoidCallback onClearQuery;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<_MenuViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(
          bottom: BorderSide(color: context.colors.border),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onQueryChanged,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cari menu...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close),
                              tooltip: 'Hapus pencarian',
                              onPressed: onClearQuery,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SegmentedButton<_MenuViewMode>(
                  segments: const [
                    ButtonSegment(
                      value: _MenuViewMode.grid,
                      icon: Icon(Icons.grid_view_outlined),
                      tooltip: 'Tampilan grid',
                    ),
                    ButtonSegment(
                      value: _MenuViewMode.detail,
                      icon: Icon(Icons.view_list_outlined),
                      tooltip: 'Tampilan detail',
                    ),
                  ],
                  selected: {viewMode},
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    ),
                  ),
                  onSelectionChanged: (selection) {
                    onViewModeChanged(selection.first);
                  },
                ),
              ],
            ),
            if (categories.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length + 1,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _CategoryChip(
                        label: 'Semua',
                        selected: selectedCategory == null,
                        color: null,
                        onSelected: () => onCategoryChanged(null),
                      );
                    }
                    final category = categories[index - 1];
                    final row = categoryByName?[category.toLowerCase()];
                    return _CategoryChip(
                      label: category,
                      selected: selectedCategory == category,
                      color: categoryColorFromStorage(row?.color),
                      onSelected: () => onCategoryChanged(category),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onSelected(),
      avatar: color == null
          ? null
          : Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
      label: Text(
        label,
        overflow: TextOverflow.ellipsis,
      ),
      labelStyle: AppTypography.labelSm.copyWith(
        color: selected ? AppColors.primaryDark : context.colors.textPrimary,
      ),
      selectedColor: AppColors.primarySurface,
      side: BorderSide(
        color: selected ? AppColors.primary : context.colors.border,
      ),
      shape: const StadiumBorder(),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  const _FilteredEmptyState({
    required this.query,
    required this.selectedCategory,
  });

  final String query;
  final String? selectedCategory;

  @override
  Widget build(BuildContext context) {
    final hasQuery = query.isNotEmpty;
    final hasCategory = selectedCategory != null;
    final message = switch ((hasQuery, hasCategory)) {
      (true, true) => 'Tidak ada menu $selectedCategory untuk "$query".',
      (true, false) => 'Tidak ada menu untuk "$query".',
      (false, true) => 'Tidak ada menu di kategori $selectedCategory.',
      (false, false) => 'Tidak ada menu yang cocok.',
    };

    return AppEmptyState(
      title: 'Menu tidak ditemukan',
      icon: Icons.search_off_outlined,
      message: message,
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
    final pricing = _MenuPricing.from(item);

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: () => _addMenuItemToCart(context, ref, item),
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
              // FEAT-012 — product photo thumbnail. Flex-fills the space
              // above name/category/price so total tile height matches the
              // grid's childAspectRatio without overflowing.
              Expanded(
                child: _ProductPhoto(
                  product: product,
                  discountPercentage:
                      pricing.discountActive ? bp.discountPercentage : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                bp.customName ?? product.name,
                style: AppTypography.titleMd,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (product.category != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Builder(builder: (context) {
                  final byName = ref.watch(categoryByNameProvider).valueOrNull;
                  final color = byName == null
                      ? null
                      : resolveCategoryColor(byName, product.category);
                  return Row(
                    children: [
                      if (color != null) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Flexible(
                        child: Text(
                          product.category!,
                          style: AppTypography.labelXs.copyWith(
                            color: context.colors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                formatRupiah(pricing.effectivePrice),
                style:
                    AppTypography.headlineMd.copyWith(color: AppColors.primary),
              ),
              if (pricing.hasReducedPrice)
                Text(
                  formatRupiah(pricing.originalPrice),
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

class _MenuDetailRow extends ConsumerWidget {
  const _MenuDetailRow({required this.item});

  final BranchProductWithProductRow item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = item.product;
    final bp = item.branchProduct;
    final pricing = _MenuPricing.from(item);
    final displayName = bp.customName ?? product.name;

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.radiusMd,
      child: InkWell(
        onTap: () => _addMenuItemToCart(context, ref, item),
        borderRadius: AppRadius.radiusMd,
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: AppRadius.radiusMd,
          ),
          child: Row(
            children: [
              SizedBox.square(
                dimension: 64,
                child: _ProductPhoto(product: product),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: AppTypography.titleMd,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            formatRupiah(pricing.effectivePrice),
                            style: AppTypography.titleMd.copyWith(
                              color: AppColors.primary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (pricing.hasReducedPrice) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Flexible(
                            child: Text(
                              formatRupiah(pricing.originalPrice),
                              style: AppTypography.labelSm.copyWith(
                                color: context.colors.textTertiary,
                                decoration: TextDecoration.lineThrough,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                        if (pricing.discountActive) ...[
                          const SizedBox(width: AppSpacing.xs),
                          AppBadge(
                            label:
                                '-${bp.discountPercentage.toStringAsFixed(0)}%',
                            icon: Icons.local_offer_outlined,
                            tone: AppBadgeTone.accent,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filledTonal(
                tooltip: 'Tambah',
                onPressed: () => _addMenuItemToCart(context, ref, item),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductPhoto extends StatelessWidget {
  const _ProductPhoto({
    required this.product,
    this.discountPercentage,
  });

  final ProductRow product;
  final double? discountPercentage;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRRect(
            borderRadius: AppRadius.radiusMd,
            child: product.imageUrl == null || product.imageUrl!.isEmpty
                ? Container(
                    color: context.colors.surfaceAlt,
                    child: Icon(
                      Icons.coffee_outlined,
                      color: context.colors.textTertiary,
                      size: 32,
                    ),
                  )
                : CachedNetworkImage(
                    imageUrl: product.imageUrl!,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: context.colors.surfaceAlt,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: context.colors.surfaceAlt,
                      child: Icon(
                        Icons.coffee_outlined,
                        color: context.colors.textTertiary,
                        size: 32,
                      ),
                    ),
                  ),
          ),
        ),
        if (discountPercentage != null)
          Positioned(
            top: 4,
            left: 4,
            child: AppBadge(
              label: '-${discountPercentage!.toStringAsFixed(0)}%',
              icon: Icons.local_offer_outlined,
              tone: AppBadgeTone.accent,
            ),
          ),
      ],
    );
  }
}

class _MenuPricing {
  const _MenuPricing({
    required this.effectivePrice,
    required this.originalPrice,
    required this.discountActive,
  });

  final double effectivePrice;
  final double originalPrice;
  final bool discountActive;

  bool get hasReducedPrice => effectivePrice < originalPrice;

  factory _MenuPricing.from(BranchProductWithProductRow item) {
    final product = item.product;
    final bp = item.branchProduct;
    final now = DateTime.now();
    final discountActive = bp.discountPercentage > 0 &&
        (bp.discountValidUntil == null || bp.discountValidUntil!.isAfter(now));
    final effectivePrice = effectiveUnitPrice(
      basePrice: product.basePrice,
      priceOverride: bp.priceOverride,
      discountPercentage: bp.discountPercentage,
      discountValidUntil: bp.discountValidUntil,
      now: now,
    );

    return _MenuPricing(
      effectivePrice: effectivePrice,
      originalPrice: bp.priceOverride ?? product.basePrice,
      discountActive: discountActive,
    );
  }
}

Future<void> _addMenuItemToCart(
  BuildContext context,
  WidgetRef ref,
  BranchProductWithProductRow item,
) async {
  HapticFeedback.selectionClick();
  final product = item.product;
  final bp = item.branchProduct;

  // FEAT-001 — if product has option groups, open picker first.
  // We do a quick read; the picker itself watches reactively too.
  final groups = await ref.read(productOptionGroupsProvider(product.id).future);
  if (!context.mounted) return;
  if (groups.isEmpty) {
    ref.read(cartNotifierProvider.notifier).addItem(
          product: product,
          branchProduct: bp,
        );
    return;
  }

  final picked = await OptionPickerSheet.show(
    context,
    productId: product.id,
    productName: bp.customName ?? product.name,
  );
  if (picked == null) return;
  ref.read(cartNotifierProvider.notifier).addItem(
        product: product,
        branchProduct: bp,
        selectedOptions: picked,
      );
}
