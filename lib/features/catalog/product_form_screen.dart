import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/domain/enums.dart';
import '../../core/storage/image_upload_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../l10n/generated/app_localizations.dart';
import 'category_providers.dart';

/// Add/edit screen for a master `Product` row.
///
/// When creating, the new product is also inserted into `branch_products` for
/// every active branch (default availability = true, no overrides) so it
/// shows up in the menu immediately. Owner can then tweak per-branch from
/// each branch's detail screen.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({this.productId, super.key});

  final String? productId;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _nameCtrl = TextEditingController();
  final _basePriceCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();

  /// Tier 1 — kategori sekarang dipilih dari registry, bukan free text.
  /// Nilai = nama kategori (mirrored ke `Products.category`); null = tanpa
  /// kategori.
  String? _selectedCategoryName;

  ProductRow? _existing;
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isActive = true;
  // FEAT-012 — uploaded photo URL. Null means no image. Replaced wholesale
  // by the photo picker; old image (if any) is cleaned from Supabase
  // Storage best-effort on _save.
  String? _imageUrl;
  bool _uploadingPhoto = false;

  String? _errorName;
  String? _errorPrice;
  String? _errorSku;

  bool get _isEditing => widget.productId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _basePriceCtrl.dispose();
    _skuCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final p =
        await ref.read(catalogDaoProvider).getProductById(widget.productId!);
    if (!mounted) return;
    setState(() {
      _existing = p;
      _isLoading = false;
      if (p != null) {
        _nameCtrl.text = p.name;
        _selectedCategoryName = p.category;
        _basePriceCtrl.text = p.basePrice.toStringAsFixed(0);
        _skuCtrl.text = p.sku ?? '';
        _isActive = p.isActive;
        _imageUrl = p.imageUrl;
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final l10n = AppL10n.of(context);
    setState(() {
      _isSaving = true;
      _errorName = null;
      _errorPrice = null;
      _errorSku = null;
    });

    final name = _nameCtrl.text.trim();
    final category = _selectedCategoryName;
    final priceText = _basePriceCtrl.text.trim();
    final sku = _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim();

    // ── Validation ──
    if (name.isEmpty) {
      setState(() {
        _isSaving = false;
        _errorName = l10n.catalogProductNameRequired;
      });
      return;
    }
    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      setState(() {
        _isSaving = false;
        _errorPrice = l10n.catalogProductInvalidBasePrice;
      });
      return;
    }
    if (sku != null) {
      final dao = ref.read(catalogDaoProvider);
      final dup = await dao.getBySku(sku);
      if (!mounted) return;
      if (dup != null && dup.id != _existing?.id) {
        setState(() {
          _isSaving = false;
          _errorSku = l10n.catalogProductSkuDuplicate;
        });
        return;
      }
    }

    final now = DateTime.now();
    final catalogDao = ref.read(catalogDaoProvider);
    final outboxDao = ref.read(outboxDaoProvider);
    String savedProductId;
    if (_existing == null) {
      // Create master + propagate to all active branches.
      final id = const Uuid().v7();
      await catalogDao.upsertProduct(ProductsCompanion.insert(
        id: id,
        name: name,
        category: Value(category),
        basePrice: price,
        sku: Value(sku),
        imageUrl: Value(_imageUrl),
        isActive: Value(_isActive),
        createdAt: now,
        updatedAt: now,
      ));
      final branchDao = ref.read(branchDaoProvider);
      final branches = await branchDao.getActiveBranches();
      for (final b in branches) {
        await catalogDao.upsertBranchProduct(
          BranchProductsCompanion.insert(
            productId: id,
            branchId: b.id,
          ),
        );
      }
      savedProductId = id;
    } else {
      await catalogDao.updateProduct(
        _existing!.id,
        ProductsCompanion(
          name: Value(name),
          category: Value(category),
          basePrice: Value(price),
          sku: Value(sku),
          imageUrl: Value(_imageUrl),
          isActive: Value(_isActive),
          updatedAt: Value(now),
        ),
      );
      savedProductId = _existing!.id;
    }

    // FEAT-012 — enqueue product push so the new imageUrl + master edits
    // propagate to Supabase. Existing edit flow didn't push (pre-existing
    // gap), but image changes specifically need to sync so other devices
    // can render the photo via cached_network_image.
    await outboxDao.enqueue(OutboxItemsCompanion.insert(
      id: const Uuid().v7(),
      entityType: OutboxEntityType.product,
      payload: jsonEncode({'id': savedProductId}),
      createdAt: now,
    ));

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  /// FEAT-012 — pick + compress + upload + replace local URL.
  Future<void> _pickPhoto() async {
    final l10n = AppL10n.of(context);
    final source = await showModalBottomSheet<ImageSource_>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(l10n.catalogProductChooseFromGallery),
              onTap: () => Navigator.pop(ctx, ImageSource_.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(l10n.catalogProductTakeFromCamera),
              onTap: () => Navigator.pop(ctx, ImageSource_.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final svc = ref.read(imageUploadServiceProvider);
    setState(() => _uploadingPhoto = true);
    final result = await svc.pickAndUpload(
      source: source,
      bucket: ImageBuckets.products,
      pathPrefix: 'products/',
      // FEAT-012b — force 1:1 crop so MenuGrid square thumbnails frame the
      // food/drink subject without auto-cropping random parts.
      crop: CropAspect.square,
    );
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    switch (result) {
      case Ok(:final value):
        final old = _imageUrl;
        setState(() => _imageUrl = value);
        if (old != null && old.isNotEmpty) {
          await svc.deleteByUrl(old, bucket: ImageBuckets.products);
        }
      case Err(:final error):
        if (error == ImageUploadError.cancelled ||
            error == ImageUploadError.cropCancelled) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.catalogProductUploadFailed(error.name))),
        );
    }
  }

  Future<void> _removePhoto() async {
    final svc = ref.read(imageUploadServiceProvider);
    final old = _imageUrl;
    setState(() => _imageUrl = null);
    if (old != null && old.isNotEmpty) {
      await svc.deleteByUrl(old, bucket: ImageBuckets.products);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.statusLoading)),
        body: const Center(child: AppLoadingIndicator()),
      );
    }
    if (_isEditing && _existing == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navProducts)),
        body: AppEmptyState(
          title: l10n.catalogProductNotFound,
          icon: Icons.search_off_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? l10n.catalogProductsEdit : l10n.catalogProductsAdd,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _PhotoSection(
            imageUrl: _imageUrl,
            uploading: _uploadingPhoto,
            onPick: _pickPhoto,
            onRemove: _imageUrl == null ? null : _removePhoto,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: l10n.catalogProductName,
            controller: _nameCtrl,
            hint: l10n.catalogProductNameHint,
            errorText: _errorName,
            autofocus: !_isEditing,
            required: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          _CategoryPickerField(
            selectedName: _selectedCategoryName,
            onChanged: (name) => setState(() => _selectedCategoryName = name),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: l10n.catalogProductBasePrice,
            controller: _basePriceCtrl,
            hint: '0',
            errorText: _errorPrice,
            keyboardType: TextInputType.number,
            prefix: 'Rp ',
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            required: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: l10n.catalogProductSku,
            controller: _skuCtrl,
            hint: l10n.catalogProductSkuHint,
            errorText: _errorSku,
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            title:
                Text(l10n.catalogProductActive, style: AppTypography.titleMd),
            subtitle: Text(
              _isActive
                  ? l10n.catalogProductActiveSubtitle
                  : l10n.catalogProductInactiveSubtitle,
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          if (!_isEditing) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 18, color: context.colors.textSecondary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.catalogProductCreateInfo,
                      style: AppTypography.bodySm
                          .copyWith(color: context.colors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: _isEditing
                ? l10n.catalogProductsSaveChanges
                : l10n.catalogProductsAdd,
            icon: Icons.save_outlined,
            onPressed: _isSaving ? null : _save,
            isLoading: _isSaving,
            size: AppButtonSize.primary,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

/// FEAT-012 — product photo preview + actions.
class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.imageUrl,
    required this.uploading,
    required this.onPick,
    this.onRemove,
  });

  final String? imageUrl;
  final bool uploading;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.catalogProductPhotoSection,
          style: AppTypography.labelSm
              .copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            onTap: uploading ? null : onPick,
            child: Container(
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: AppRadius.radiusMd,
                border: Border.all(
                  color: context.colors.border,
                ),
              ),
              child: uploading
                  ? const Center(child: AppLoadingIndicator())
                  : hasImage
                      ? ClipRRect(
                          borderRadius: AppRadius.radiusMd,
                          child: CachedNetworkImage(
                            imageUrl: imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) =>
                                const Center(child: AppLoadingIndicator()),
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: AppColors.danger, size: 32),
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                size: 36, color: context.colors.textTertiary),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              l10n.catalogProductPhotoTapToAdd,
                              style: AppTypography.bodySm.copyWith(
                                color: context.colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: AppButton(
                label: hasImage
                    ? l10n.catalogProductChangePhoto
                    : l10n.catalogProductChoosePhoto,
                icon: Icons.image_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: uploading ? null : onPick,
              ),
            ),
            if (hasImage) ...[
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: uploading ? null : onRemove,
                icon: const Icon(Icons.delete_outline),
                tooltip: l10n.catalogProductDeletePhoto,
                color: AppColors.danger,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Tier 1 — kategori picker yang membaca dari registry kategori. Memuat
/// kategori aktif dari [activeCategoriesProvider] dan menampilkan sebagai
/// dropdown + tombol quick-add inline. Nilai (`selectedName`) tetap berupa
/// string supaya `Products.category` text bisa langsung di-mirror.
class _CategoryPickerField extends ConsumerWidget {
  const _CategoryPickerField({
    required this.selectedName,
    required this.onChanged,
  });

  final String? selectedName;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final async = ref.watch(activeCategoriesProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            l10n.catalogProductCategory,
            style: AppTypography.labelSm
                .copyWith(color: context.colors.textSecondary),
          ),
        ),
        async.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: AppLoadingIndicator(),
          ),
          error: (e, _) => Text(
            l10n.catalogProductCategoryLoadFailed('$e'),
            style: AppTypography.bodySm.copyWith(color: AppColors.danger),
          ),
          data: (rows) {
            // Selected name tidak harus ada di list (mis. produk lama dari
            // sync yang belum di-seed). Tambahkan opsi virtual supaya
            // DropdownButton tidak crash karena value mismatch.
            final names = rows.map((c) => c.name).toList();
            final hasSelected = selectedName == null ||
                names
                    .any((n) => n.toLowerCase() == selectedName!.toLowerCase());
            return Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: hasSelected ? selectedName : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.category_outlined),
                      hintText: l10n.catalogProductCategoryHint,
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(l10n.catalogProductNoCategory),
                      ),
                      for (final c in rows)
                        DropdownMenuItem<String?>(
                          value: c.name,
                          child: Row(
                            children: [
                              if (c.color != null) ...[
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: categoryColorFromStorage(c.color),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                              ],
                              Flexible(
                                child: Text(
                                  c.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Opsi virtual kalau selectedName legacy/tidak match.
                      if (!hasSelected)
                        DropdownMenuItem<String?>(
                          value: selectedName,
                          child: Text(
                            l10n.catalogProductLegacyCategory(selectedName!),
                            style: AppTypography.bodyMd
                                .copyWith(color: AppColors.warning),
                          ),
                        ),
                    ],
                    onChanged: onChanged,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                IconButton.outlined(
                  tooltip: l10n.catalogProductAddCategoryTooltip,
                  onPressed: () => _quickAdd(context, ref),
                  icon: const Icon(Icons.add),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _quickAdd(BuildContext context, WidgetRef ref) async {
    final l10n = AppL10n.of(context);
    final ctrl = TextEditingController();
    final created = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.catalogCategoryAddTitle),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: l10n.catalogCategoryNameHint,
            prefixIcon: const Icon(Icons.category_outlined),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: Text(l10n.actionSave),
          ),
        ],
      ),
    );
    if (created == null || created.isEmpty) return;
    final dao = ref.read(categoryDaoProvider);
    final dup = await dao.getByName(created);
    if (dup != null) {
      onChanged(dup.name);
      return;
    }
    final all = await dao.getAll();
    final nextOrder = all.isEmpty
        ? 0
        : (all.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1);
    final now = DateTime.now();
    final newId = const Uuid().v7();
    await dao.upsert(CategoriesCompanion.insert(
      id: newId,
      name: created,
      sortOrder: Value(nextOrder),
      isActive: const Value(true),
      createdAt: now,
      updatedAt: now,
    ));
    await ref.read(outboxDaoProvider).enqueue(OutboxItemsCompanion.insert(
          id: const Uuid().v7(),
          entityType: OutboxEntityType.category,
          payload: jsonEncode({'id': newId}),
          createdAt: now,
        ));
    onChanged(created);
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
    this.autofocus = false,
    this.required = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefix;
  final bool autofocus;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: RichText(
            text: TextSpan(
              text: label,
              style: AppTypography.labelSm
                  .copyWith(color: context.colors.textSecondary),
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.danger),
                  ),
              ],
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          autofocus: autofocus,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            // Always-visible prefix — `prefixText` reserves space even when
            // hidden, indenting the hint inconsistently across fields.
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
          ),
        ),
      ],
    );
  }
}
