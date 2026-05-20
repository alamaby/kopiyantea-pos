import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/daos/inventory_dao.dart';
import '../../core/domain/enums.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../inventory/inventory_providers.dart';

/// Bottom sheet for add/edit/delete of one recipe row.
///
/// Two modes:
/// - **Add**: pass `existing: null`. Shows a list of inventory items not yet
///   in the recipe + a qty field after pick.
/// - **Edit**: pass `existing`. Shows ingredient read-only + qty field + delete.
class RecipeEditorSheet extends ConsumerStatefulWidget {
  const RecipeEditorSheet({
    required this.productId,
    required this.branchId,
    required this.existingIngredientIds,
    this.existing,
    super.key,
  });

  final String productId;
  final String branchId;
  final RecipeWithItem? existing;

  /// Ids already used by this product's recipe — to exclude from the picker
  /// when adding (UNIQUE constraint on `(productId, branchId, inventoryItemId)`).
  final Set<String> existingIngredientIds;

  static Future<bool?> show({
    required BuildContext context,
    required String productId,
    required String branchId,
    required Set<String> existingIngredientIds,
    RecipeWithItem? existing,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => RecipeEditorSheet(
        productId: productId,
        branchId: branchId,
        existingIngredientIds: existingIngredientIds,
        existing: existing,
      ),
    );
  }

  @override
  ConsumerState<RecipeEditorSheet> createState() => _RecipeEditorSheetState();
}

class _RecipeEditorSheetState extends ConsumerState<RecipeEditorSheet> {
  final _qtyCtrl = TextEditingController();
  InventoryItemRow? _selectedItem;
  bool _isSaving = false;
  String? _errorQty;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _selectedItem = widget.existing!.item;
      _qtyCtrl.text = _formatQty(widget.existing!.recipe.quantityRequired);
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  String _formatQty(double q) {
    return q == q.roundToDouble()
        ? q.toStringAsFixed(0)
        : q.toString();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorQty = null;
    });

    final item = _selectedItem;
    if (item == null) {
      setState(() => _isSaving = false);
      return;
    }

    final qty = double.tryParse(_qtyCtrl.text.trim());
    if (qty == null || qty <= 0) {
      setState(() {
        _isSaving = false;
        _errorQty = 'Jumlah harus lebih dari 0';
      });
      return;
    }

    final dao = ref.read(inventoryDaoProvider);
    if (_isEditing) {
      await dao.updateRecipeQuantity(
        recipeId: widget.existing!.recipe.id,
        quantityRequired: qty,
      );
    } else {
      await dao.insertRecipe(ProductRecipesCompanion.insert(
        id: const Uuid().v7(),
        productId: widget.productId,
        branchId: widget.branchId,
        inventoryItemId: item.id,
        quantityRequired: qty,
      ));
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus bahan?'),
        content: Text(
          '"${widget.existing!.item.name}" akan dihapus dari komposisi produk ini.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(inventoryDaoProvider)
        .deleteRecipe(widget.existing!.recipe.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.xl,
          right: AppSpacing.xl,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _isEditing ? 'Ubah Bahan' : 'Tambah Bahan',
                style: AppTypography.headlineLg,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_isEditing)
                _SelectedItemDisplay(item: _selectedItem!)
              else
                _ItemPicker(
                  branchId: widget.branchId,
                  excludeIds: widget.existingIngredientIds,
                  selected: _selectedItem,
                  onSelect: (it) => setState(() => _selectedItem = it),
                ),
              if (_selectedItem != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _QuantityField(
                  controller: _qtyCtrl,
                  unit: _selectedItem!.unit,
                  errorText: _errorQty,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    if (_isEditing) ...[
                      Expanded(
                        child: AppButton(
                          label: 'Hapus',
                          variant: AppButtonVariant.danger,
                          icon: Icons.delete_outline,
                          onPressed: _isSaving ? null : _delete,
                          fullWidth: true,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: AppButton(
                        label: _isEditing ? 'Simpan' : 'Tambah',
                        icon: Icons.save_outlined,
                        onPressed: _isSaving ? null : _save,
                        isLoading: _isSaving,
                        fullWidth: true,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Item picker (add mode) ───────────────────────────────────────────────────

class _ItemPicker extends ConsumerWidget {
  const _ItemPicker({
    required this.branchId,
    required this.excludeIds,
    required this.selected,
    required this.onSelect,
  });

  final String branchId;
  final Set<String> excludeIds;
  final InventoryItemRow? selected;
  final ValueChanged<InventoryItemRow> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(branchInventoryProvider(branchId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PILIH BAHAN',
          style: AppTypography.labelSm.copyWith(
            color: context.colors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        itemsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: AppLoadingIndicator(),
          ),
          error: (e, _) => Text(
            'Gagal memuat: $e',
            style: AppTypography.bodySm.copyWith(color: AppColors.danger),
          ),
          data: (all) {
            final available = all.where((i) => !excludeIds.contains(i.id)).toList();
            if (available.isEmpty) {
              return const AppEmptyState(
                title: 'Tidak ada bahan tersedia',
                icon: Icons.inventory_2_outlined,
                message:
                    'Semua bahan sudah dipakai atau belum ada item stok di cabang ini.',
              );
            }
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: available.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) {
                  final it = available[i];
                  final isSelected = selected?.id == it.id;
                  return InkWell(
                    onTap: () => onSelect(it),
                    borderRadius: AppRadius.radiusMd,
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primarySurface
                            : context.colors.surface,
                        borderRadius: AppRadius.radiusMd,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : context.colors.border,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isSelected
                                ? AppColors.primary
                                : context.colors.textTertiary,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.name, style: AppTypography.titleMd),
                                Text(
                                  'Stok: ${formatStock(it.cachedStock, it.unit)}',
                                  style: AppTypography.labelSm.copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

class _SelectedItemDisplay extends StatelessWidget {
  const _SelectedItemDisplay({required this.item});

  final InventoryItemRow item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: AppRadius.radiusMd,
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTypography.titleMd),
                Text(
                  'Stok saat ini: ${formatStock(item.cachedStock, item.unit)}',
                  style: AppTypography.labelSm.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quantity field ───────────────────────────────────────────────────────────

class _QuantityField extends StatelessWidget {
  const _QuantityField({
    required this.controller,
    required this.unit,
    this.errorText,
  });

  final TextEditingController controller;
  final StockUnit unit;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JUMLAH PER PRODUK',
          style: AppTypography.labelSm.copyWith(
            color: context.colors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            hintText: '0',
            errorText: errorText,
            suffixText: stockUnitLabel(unit),
            helperText:
                'Jumlah yang dikurangi dari stok setiap kali produk ini terjual',
          ),
        ),
      ],
    );
  }
}
