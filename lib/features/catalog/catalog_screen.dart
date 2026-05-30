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
import '../auth/auth_provider.dart';
import '../settings/branch_selection_provider.dart';
import 'catalog_csv.dart';
import 'catalog_providers.dart';
import 'category_providers.dart';

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
        actions: [
          if (ref.watch(currentUserProvider)?.globalRole == GlobalRole.owner)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'Lainnya',
              onSelected: (v) {
                if (v == 'export') _exportCsv(context, ref);
                if (v == 'import') _importCsv(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    leading: Icon(Icons.upload_outlined),
                    title: Text('Ekspor CSV'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: ListTile(
                    leading: Icon(Icons.download_outlined),
                    title: Text('Impor CSV'),
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

  // ── ENH-010 CSV import/export ───────────────────────────────────────────────

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(catalogDaoProvider);
    final rows = await dao.getAllProducts();
    final csv = exportProductsToCsv(rows);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('${rows.length} produk disalin ke clipboard sebagai CSV'),
      ),
    );
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text;
    if (raw == null || raw.trim().isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Clipboard kosong')),
      );
      return;
    }
    final result = parseProductsCsv(raw);

    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Impor'),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${result.ok.length} baris akan dibuat/diperbarui.'),
              if (result.errors.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('${result.errors.length} kesalahan (dilewati):',
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
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed:
                result.ok.isEmpty ? null : () => Navigator.pop(ctx, true),
            child: const Text('Impor'),
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
        content: Text(
            '${result.ok.length} produk diimpor & diantrekan untuk sinkron'),
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
