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
  final _categoryCtrl = TextEditingController();
  final _basePriceCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();

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
    _categoryCtrl.dispose();
    _basePriceCtrl.dispose();
    _skuCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final p = await ref.read(catalogDaoProvider).getProductById(widget.productId!);
    if (!mounted) return;
    setState(() {
      _existing = p;
      _isLoading = false;
      if (p != null) {
        _nameCtrl.text = p.name;
        _categoryCtrl.text = p.category ?? '';
        _basePriceCtrl.text = p.basePrice.toStringAsFixed(0);
        _skuCtrl.text = p.sku ?? '';
        _isActive = p.isActive;
        _imageUrl = p.imageUrl;
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorName = null;
      _errorPrice = null;
      _errorSku = null;
    });

    final name = _nameCtrl.text.trim();
    final category =
        _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim();
    final priceText = _basePriceCtrl.text.trim();
    final sku = _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim();

    // ── Validation ──
    if (name.isEmpty) {
      setState(() {
        _isSaving = false;
        _errorName = 'Nama wajib diisi';
      });
      return;
    }
    final price = double.tryParse(priceText);
    if (price == null || price <= 0) {
      setState(() {
        _isSaving = false;
        _errorPrice = 'Harga harus lebih dari 0';
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
          _errorSku = 'SKU sudah dipakai produk lain';
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
    final source = await showModalBottomSheet<ImageSource_>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource_.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil dari Kamera'),
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
        if (error == ImageUploadError.cancelled) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal upload: ${error.name}')),
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Memuat…')),
        body: const Center(child: AppLoadingIndicator()),
      );
    }
    if (_isEditing && _existing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Produk')),
        body: const AppEmptyState(
          title: 'Produk tidak ditemukan',
          icon: Icons.search_off_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Ubah Produk' : 'Tambah Produk'),
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
            label: 'Nama',
            controller: _nameCtrl,
            hint: 'mis. Latte, Cappuccino',
            errorText: _errorName,
            autofocus: !_isEditing,
            required: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'Kategori',
            controller: _categoryCtrl,
            hint: 'mis. Kopi, Pastry',
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'Harga Dasar',
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
            label: 'SKU',
            controller: _skuCtrl,
            hint: 'Opsional · kode unik',
            errorText: _errorSku,
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            value: _isActive,
            onChanged: (v) => setState(() => _isActive = v),
            title: Text('Aktif', style: AppTypography.titleMd),
            subtitle: Text(
              _isActive
                  ? 'Produk muncul di POS semua cabang yang mengaktifkannya'
                  : 'Disembunyikan dari POS · data tetap tersimpan',
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
                      'Produk akan ditambahkan ke menu semua cabang aktif. '
                      'Atur ketersediaan & diskon per-cabang dari layar produk.',
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
            label: _isEditing ? 'Simpan Perubahan' : 'Tambah Produk',
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
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FOTO PRODUK',
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
                                size: 36,
                                color: context.colors.textTertiary),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Tap untuk tambah foto',
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
                label: hasImage ? 'Ganti Foto' : 'Pilih Foto',
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
                tooltip: 'Hapus foto',
                color: AppColors.danger,
              ),
            ],
          ],
        ),
      ],
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
