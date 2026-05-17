import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
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
    if (_existing == null) {
      // Create master + propagate to all active branches.
      final id = const Uuid().v7();
      await catalogDao.upsertProduct(ProductsCompanion.insert(
        id: id,
        name: name,
        category: Value(category),
        basePrice: price,
        sku: Value(sku),
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
    } else {
      await catalogDao.updateProduct(
        _existing!.id,
        ProductsCompanion(
          name: Value(name),
          category: Value(category),
          basePrice: Value(price),
          sku: Value(sku),
          isActive: Value(_isActive),
          updatedAt: Value(now),
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pop();
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
