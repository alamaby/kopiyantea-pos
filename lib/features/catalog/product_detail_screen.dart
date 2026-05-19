import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/daos/inventory_dao.dart';
import '../../core/pricing/pricing.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../settings/branch_selection_provider.dart';
import 'catalog_providers.dart';
import 'recipe_editor_sheet.dart';

/// Single-screen view + edit for a product within the active branch.
///
/// Two sections:
/// - **Master Produk** (read-only summary; tap "Ubah" → push to form)
/// - **Pengaturan Cabang** (inline editable form — availability, price
///   override, discount, valid-until, custom name)
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({required this.productId, super.key});

  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final _customNameCtrl = TextEditingController();
  final _priceOverrideCtrl = TextEditingController();
  final _discountCtrl = TextEditingController();

  ProductRow? _product;
  BranchProductRow? _bp;
  BranchRow? _branch;
  DateTime? _discountValidUntil;
  bool _isAvailable = true;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorPrice;
  String? _errorDiscount;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _customNameCtrl.dispose();
    _priceOverrideCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final branch = await ref.read(selectedBranchProvider.future);
    if (branch == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }
    final dao = ref.read(catalogDaoProvider);
    final product = await dao.getProductById(widget.productId);
    final bp = await dao.getBranchProduct(widget.productId, branch.id);
    if (!mounted) return;
    setState(() {
      _branch = branch;
      _product = product;
      _bp = bp;
      _isLoading = false;
      if (bp != null) {
        _customNameCtrl.text = bp.customName ?? '';
        _priceOverrideCtrl.text =
            bp.priceOverride == null ? '' : bp.priceOverride!.toStringAsFixed(0);
        _discountCtrl.text = bp.discountPercentage.toStringAsFixed(0);
        _discountValidUntil = bp.discountValidUntil;
        _isAvailable = bp.isAvailable;
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorPrice = null;
      _errorDiscount = null;
    });

    final customName = _customNameCtrl.text.trim().isEmpty
        ? null
        : _customNameCtrl.text.trim();
    final priceOverrideText = _priceOverrideCtrl.text.trim();
    final discountText = _discountCtrl.text.trim();

    double? priceOverride;
    if (priceOverrideText.isNotEmpty) {
      final parsed = double.tryParse(priceOverrideText);
      if (parsed == null || parsed <= 0) {
        setState(() {
          _isSaving = false;
          _errorPrice = 'Harga override harus lebih dari 0';
        });
        return;
      }
      priceOverride = parsed;
    }

    final discount = double.tryParse(discountText) ?? 0;
    if (discount < 0 || discount > 100) {
      setState(() {
        _isSaving = false;
        _errorDiscount = 'Diskon harus antara 0-100';
      });
      return;
    }

    await ref.read(catalogDaoProvider).updateBranchProduct(
          productId: widget.productId,
          branchId: _branch!.id,
          patch: BranchProductsCompanion(
            isAvailable: Value(_isAvailable),
            customName: Value(customName),
            priceOverride: Value(priceOverride),
            discountPercentage: Value(discount),
            discountValidUntil: Value(_discountValidUntil),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengaturan cabang tersimpan')),
    );
    setState(() => _isSaving = false);
  }

  Future<void> _pickDiscountExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _discountValidUntil ?? now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _discountValidUntil =
          DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Memuat…')),
        body: const Center(child: AppLoadingIndicator()),
      );
    }
    final product = _product;
    final bp = _bp;
    final branch = _branch;
    if (product == null || bp == null || branch == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Produk')),
        body: const AppEmptyState(
          title: 'Produk tidak ditemukan',
          icon: Icons.search_off_outlined,
        ),
      );
    }

    final now = DateTime.now();
    final effective = effectiveUnitPrice(
      basePrice: product.basePrice,
      priceOverride: bp.priceOverride,
      discountPercentage: bp.discountPercentage,
      discountValidUntil: bp.discountValidUntil,
      now: now,
    );

    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _MasterCard(product: product, onEdit: () async {
            await context.push('/products/${product.id}/master');
            if (mounted) _load();
          }),
          const SizedBox(height: AppSpacing.lg),
          _PreviewCard(
            effective: effective,
            original: bp.priceOverride ?? product.basePrice,
            branchName: branch.name,
          ),
          const SizedBox(height: AppSpacing.lg),
          _BranchEditCard(
            isAvailable: _isAvailable,
            customNameCtrl: _customNameCtrl,
            priceOverrideCtrl: _priceOverrideCtrl,
            discountCtrl: _discountCtrl,
            discountValidUntil: _discountValidUntil,
            errorPrice: _errorPrice,
            errorDiscount: _errorDiscount,
            isSaving: _isSaving,
            branchName: branch.name,
            productCategoryHint: product.category,
            onAvailableChanged: (v) => setState(() => _isAvailable = v),
            onClearDiscountExpiry: () =>
                setState(() => _discountValidUntil = null),
            onPickDiscountExpiry: _pickDiscountExpiry,
            onSave: _save,
          ),
          const SizedBox(height: AppSpacing.lg),
          _RecipeCard(
            productId: product.id,
            branchId: branch.id,
            branchName: branch.name,
          ),
          const SizedBox(height: AppSpacing.lg),
          // FEAT-001 — modifier link card.
          _ModifierLinkCard(productId: product.id),
        ],
      ),
    );
  }
}

class _ModifierLinkCard extends ConsumerWidget {
  const _ModifierLinkCard({required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.tune_outlined),
        title: const Text('Modifier'),
        subtitle: const Text(
            'Atur grup pilihan (gula, ukuran, dll.) untuk produk ini'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => GoRouter.of(context).push('/products/$productId/options'),
      ),
    );
  }
}

// ── Recipe section ────────────────────────────────────────────────────────────

class _RecipeCard extends ConsumerWidget {
  const _RecipeCard({
    required this.productId,
    required this.branchId,
    required this.branchName,
  });

  final String productId;
  final String branchId;
  final String branchName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipesAsync =
        ref.watch(productRecipesProvider(productId, branchId));

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'KOMPOSISI · ${branchName.toUpperCase()}',
                style: AppTypography.labelSm.copyWith(
                  color: context.colors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Bahan yang dikurangi dari stok saat produk terjual.',
            style: AppTypography.bodySm
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          recipesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppLoadingIndicator(),
            ),
            error: (e, _) => Text(
              'Gagal memuat komposisi: $e',
              style: AppTypography.bodySm.copyWith(color: AppColors.danger),
            ),
            data: (recipes) => Column(
              children: [
                if (recipes.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceAlt,
                      borderRadius: AppRadius.radiusMd,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: context.colors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Belum ada bahan. Produk akan tetap bisa dijual, '
                            'tapi stok tidak akan dikurangi otomatis.',
                            style: AppTypography.bodySm.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...recipes.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _RecipeRow(
                        recipe: r,
                        onTap: () => RecipeEditorSheet.show(
                          context: context,
                          productId: productId,
                          branchId: branchId,
                          existingIngredientIds: recipes
                              .map((x) => x.item.id)
                              .toSet(),
                          existing: r,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                AppButton(
                  label: 'Tambah Bahan',
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => RecipeEditorSheet.show(
                    context: context,
                    productId: productId,
                    branchId: branchId,
                    existingIngredientIds:
                        recipes.map((x) => x.item.id).toSet(),
                  ),
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeRow extends StatelessWidget {
  const _RecipeRow({required this.recipe, required this.onTap});

  final RecipeWithItem recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: AppRadius.radiusMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusMd,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: AppRadius.radiusMd,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: context.colors.surfaceAlt,
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 16,
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(recipe.item.name, style: AppTypography.titleMd),
              ),
              Text(
                formatStock(recipe.recipe.quantityRequired, recipe.item.unit),
                style: AppTypography.titleMd
                    .copyWith(color: AppColors.primary),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Master summary ────────────────────────────────────────────────────────────

class _MasterCard extends StatelessWidget {
  const _MasterCard({required this.product, required this.onEdit});

  final ProductRow product;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'MASTER PRODUK',
                style: AppTypography.labelSm.copyWith(
                  color: context.colors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (!product.isActive)
                const AppBadge(
                  label: 'Nonaktif',
                  icon: Icons.block,
                  tone: AppBadgeTone.neutral,
                ),
              const SizedBox(width: AppSpacing.sm),
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Ubah'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(product.name, style: AppTypography.headlineMd),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              if (product.category != null)
                Text(
                  product.category!,
                  style: AppTypography.bodySm
                      .copyWith(color: context.colors.textSecondary),
                ),
              if (product.category != null)
                Text(' · ',
                    style: AppTypography.bodySm
                        .copyWith(color: context.colors.textTertiary)),
              Text(
                formatRupiah(product.basePrice),
                style: AppTypography.titleMd.copyWith(color: AppColors.primary),
              ),
            ],
          ),
          if (product.sku != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'SKU: ${product.sku}',
              style: AppTypography.labelSm
                  .copyWith(color: context.colors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Preview ───────────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.effective,
    required this.original,
    required this.branchName,
  });

  final double effective;
  final double original;
  final String branchName;

  @override
  Widget build(BuildContext context) {
    final hasReducedPrice = effective < original;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: AppRadius.radiusLg,
      ),
      child: Row(
        children: [
          const Icon(Icons.point_of_sale_outlined, color: AppColors.primaryDark),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HARGA DI KASIR',
                  style: AppTypography.labelXs.copyWith(
                    color: AppColors.primaryDark,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Text(
                      formatRupiah(effective),
                      style: AppTypography.headlineLg
                          .copyWith(color: AppColors.primaryDark),
                    ),
                    if (hasReducedPrice) ...[
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        formatRupiah(original),
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primaryDark.withValues(alpha: 0.6),
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Branch edit form ──────────────────────────────────────────────────────────

class _BranchEditCard extends StatelessWidget {
  const _BranchEditCard({
    required this.isAvailable,
    required this.customNameCtrl,
    required this.priceOverrideCtrl,
    required this.discountCtrl,
    required this.discountValidUntil,
    required this.errorPrice,
    required this.errorDiscount,
    required this.isSaving,
    required this.branchName,
    required this.productCategoryHint,
    required this.onAvailableChanged,
    required this.onClearDiscountExpiry,
    required this.onPickDiscountExpiry,
    required this.onSave,
  });

  final bool isAvailable;
  final TextEditingController customNameCtrl;
  final TextEditingController priceOverrideCtrl;
  final TextEditingController discountCtrl;
  final DateTime? discountValidUntil;
  final String? errorPrice;
  final String? errorDiscount;
  final bool isSaving;
  final String branchName;
  final String? productCategoryHint;
  final ValueChanged<bool> onAvailableChanged;
  final VoidCallback onClearDiscountExpiry;
  final VoidCallback onPickDiscountExpiry;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PENGATURAN CABANG · ${branchName.toUpperCase()}',
            style: AppTypography.labelSm.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            value: isAvailable,
            onChanged: onAvailableChanged,
            title: Text('Tersedia di kasir', style: AppTypography.titleMd),
            subtitle: Text(
              isAvailable
                  ? 'Pelanggan dapat memesan produk ini'
                  : 'Sembunyi dari layar Kasir',
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          _Field(
            label: 'Nama Kustom',
            controller: customNameCtrl,
            hint: 'Opsional · override nama master di cabang ini',
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'Harga Override',
            controller: priceOverrideCtrl,
            hint: 'Opsional · biarkan kosong untuk pakai harga master',
            errorText: errorPrice,
            keyboardType: TextInputType.number,
            prefix: 'Rp ',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'Diskon (%)',
            controller: discountCtrl,
            hint: '0',
            errorText: errorDiscount,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            suffix: '%',
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Diskon Berlaku Sampai',
            style: AppTypography.labelSm
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          InkWell(
            onTap: onPickDiscountExpiry,
            borderRadius: AppRadius.radiusMd,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                border: Border.all(color: context.colors.border),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      discountValidUntil == null
                          ? 'Tanpa batas waktu'
                          : formatDate(discountValidUntil!),
                      style: AppTypography.bodyMd,
                    ),
                  ),
                  if (discountValidUntil != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: onClearDiscountExpiry,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: 'Simpan Pengaturan Cabang',
            icon: Icons.save_outlined,
            onPressed: isSaving ? null : onSave,
            isLoading: isSaving,
            size: AppButtonSize.primary,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.inputFormatters,
    this.prefix,
    this.suffix,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefix;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            label,
            style: AppTypography.labelSm
                .copyWith(color: context.colors.textSecondary),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            // Always-visible prefix via prefixIcon — `prefixText` only shows
            // when field is focused/has-value, but its space is reserved
            // either way, indenting the hint inconsistently.
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Align(
                      widthFactor: 1,
                      child: Text(
                        prefix!,
                        style: AppTypography.bodyLg.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 0, minHeight: 0),
            suffixText: suffix,
          ),
        ),
      ],
    );
  }
}
