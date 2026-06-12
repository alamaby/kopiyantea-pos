import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/catalog_dao.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/domain/enums.dart';
import '../../core/pricing/pricing.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_provider.dart';
import '../settings/branch_selection_provider.dart';
import 'catalog_csv.dart';
import 'catalog_providers.dart';
import 'category_providers.dart';
import 'share_menu_image_use_case.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _isSharingMenuImage = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final branchAsync = ref.watch(selectedBranchProvider);

    return Scaffold(
      appBar: AppBar(
        title: branchAsync.maybeWhen(
          data: (b) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.navProducts),
              if (b != null)
                Text(
                  b.name,
                  style: AppTypography.labelSm
                      .copyWith(color: context.colors.textSecondary),
                ),
            ],
          ),
          orElse: () => Text(l10n.navProducts),
        ),
        actions: [
          if (branchAsync.valueOrNull != null)
            IconButton(
              icon: _isSharingMenuImage
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.ios_share_outlined),
              tooltip: l10n.catalogProductsShareMenuPng,
              onPressed: _isSharingMenuImage
                  ? null
                  : () => _shareMenuImage(context, branchAsync.valueOrNull!),
            ),
          if (ref.watch(currentUserProvider)?.globalRole == GlobalRole.owner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: l10n.catalogProductsMore,
              onSelected: (v) {
                if (v == 'export') _exportCsv(context, ref);
                if (v == 'import') _importCsv(context, ref);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: const Icon(Icons.upload_outlined),
                    title: Text(l10n.catalogProductsExportCsv),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: const Icon(Icons.download_outlined),
                    title: Text(l10n.catalogProductsImportCsv),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_catalog',
        onPressed: () => context.push('/products/new'),
        icon: const Icon(Icons.add),
        label: Text(l10n.catalogProductsAdd),
      ),
      body: branchAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: l10n.catalogProductsLoadBranchFailed,
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (branch) {
          if (branch == null) {
            return AppEmptyState(
              title: l10n.catalogProductsNoBranchTitle,
              icon: Icons.store_outlined,
              message: l10n.catalogProductsNoBranchMessage,
            );
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.catalogProductsSearchHint,
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

  // ── ENH-010 CSV import/export ───────────────────────────────────────────────

  Future<void> _shareMenuImage(BuildContext context, BranchRow branch) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    setState(() => _isSharingMenuImage = true);
    try {
      final shared = await ref.read(shareMenuImageUseCaseProvider).share(
            branch: branch,
          );
      if (!context.mounted) return;
      if (!shared) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.catalogProductsShareEmpty)),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.catalogProductsShareImageFailed(
            _shareMenuImageErrorLabel(l10n, e),
          )),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSharingMenuImage = false);
    }
  }

  String _shareMenuImageErrorLabel(AppL10n l10n, Object error) {
    if (error is StateError &&
        error.message == shareMenuImageEncodeFailedCode) {
      return l10n.catalogProductsCreateImageFailed;
    }
    return error.toString();
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    final dao = ref.read(catalogDaoProvider);
    final rows = await dao.getAllProducts();
    final csv = exportProductsToCsv(rows);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.catalogProductsExportedCsv(rows.length)),
      ),
    );
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text;
    if (raw == null || raw.trim().isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.catalogProductsClipboardEmpty)),
      );
      return;
    }
    final result = parseProductsCsv(raw);

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.catalogProductsImportConfirmTitle),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.catalogProductsImportRowsReady(result.ok.length)),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                    l10n.catalogProductsImportErrorsSkipped(
                        result.errors.length),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: AppSpacing.xs),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      result.errors.join('\n'),
                      style: AppTypography.labelSm,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed:
                result.ok.isEmpty ? null : () => Navigator.pop(ctx, true),
            child: Text(l10n.actionImport),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final dao = ref.read(catalogDaoProvider);
    final categoryDao = ref.read(categoryDaoProvider);
    final outboxDao = ref.read(outboxDaoProvider);
    const uuid = Uuid();
    final now = DateTime.now();

    // Tier 1 — auto-register kategori baru yang muncul di CSV supaya
    // produk impor langsung mendarat di registry (bukan tertinggal sebagai
    // free-text yang tidak punya color/sortOrder).
    final csvCategories = <String>{
      for (final c in result.ok)
        if (c.category.present && c.category.value != null)
          c.category.value!.trim(),
    }..removeWhere((s) => s.isEmpty);
    if (csvCategories.isNotEmpty) {
      final existing = await categoryDao.getAll();
      final existingLower = existing.map((c) => c.name.toLowerCase()).toSet();
      var nextOrder = existing.isEmpty
          ? 0
          : (existing.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) +
              1);
      for (final name in csvCategories) {
        if (existingLower.contains(name.toLowerCase())) continue;
        final newId = uuid.v7();
        await categoryDao.upsert(CategoriesCompanion.insert(
          id: newId,
          name: name,
          sortOrder: Value(nextOrder),
          isActive: const Value(true),
          createdAt: now,
          updatedAt: now,
        ));
        await outboxDao.enqueue(OutboxItemsCompanion.insert(
          id: uuid.v7(),
          entityType: OutboxEntityType.category,
          payload: jsonEncode({'id': newId}),
          createdAt: now,
        ));
        nextOrder++;
      }
    }

    for (final c in result.ok) {
      await dao.upsertProduct(c);
      await outboxDao.enqueue(OutboxItemsCompanion.insert(
        id: uuid.v7(),
        entityType: OutboxEntityType.product,
        payload: jsonEncode({'id': c.id.value}),
        createdAt: now,
      ));
    }
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.catalogProductsImportedQueued(result.ok.length)),
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
    final l10n = AppL10n.of(context);
    final menuAsync = ref.watch(branchMenuFullProvider(branchId));

    return menuAsync.when(
      loading: () => const Center(child: AppLoadingIndicator()),
      error: (e, _) => AppEmptyState(
        title: l10n.catalogProductsLoadFailed,
        icon: Icons.error_outline,
        message: e.toString(),
      ),
      data: (items) {
        final filtered = _filter(items, query);
        if (filtered.isEmpty) {
          return AppEmptyState(
            title: query.isEmpty
                ? l10n.catalogProductsEmptyTitle
                : l10n.catalogProductsNotFound,
            icon: query.isEmpty
                ? Icons.restaurant_menu_outlined
                : Icons.search_off_outlined,
            message: query.isEmpty ? l10n.catalogProductsEmptyMessage : null,
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
      final name =
          (bp.branchProduct.customName ?? bp.product.name).toLowerCase();
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
    final l10n = AppL10n.of(context);
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
        (bp.discountValidUntil == null || bp.discountValidUntil!.isAfter(now));

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
                            AppBadge(
                              label: l10n.statusInactive,
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
                            Consumer(
                              builder: (_, ref, __) {
                                final map = ref
                                    .watch(categoryByNameProvider)
                                    .valueOrNull;
                                final color = map == null
                                    ? null
                                    : resolveCategoryColor(
                                        map, product.category);
                                if (color == null) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(
                                      right: AppSpacing.xs),
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                );
                              },
                            ),
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
                          await ref.read(outboxDaoProvider).enqueue(
                                OutboxItemsCompanion.insert(
                                  id: const Uuid().v7(),
                                  entityType: OutboxEntityType.branchProduct,
                                  payload: jsonEncode({
                                    'product_id': product.id,
                                    'branch_id': branchId,
                                  }),
                                  createdAt: DateTime.now(),
                                ),
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
