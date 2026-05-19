import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/database_provider.dart';
import '../../core/domain/enums.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../settings/branch_selection_provider.dart';

/// FEAT-005 — create or edit an inventory item (master).
///
/// Initial stock for a *new* item is recorded as a separate `purchase`
/// movement via `StockMovementScreen` after creation; this form only owns
/// the item's metadata (name, unit, min, cost).
class InventoryItemFormScreen extends ConsumerStatefulWidget {
  const InventoryItemFormScreen({this.itemId, super.key});
  final String? itemId;

  @override
  ConsumerState<InventoryItemFormScreen> createState() =>
      _InventoryItemFormScreenState();
}

class _InventoryItemFormScreenState
    extends ConsumerState<InventoryItemFormScreen> {
  final _nameCtrl = TextEditingController();
  final _minStockCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  StockUnit _unit = StockUnit.gram;

  InventoryItemRow? _existing;
  bool _loading = false;
  bool _saving = false;
  String? _errorName;

  bool get _isEditing => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minStockCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final row = await (ref.read(databaseProvider).select(
              ref.read(databaseProvider).inventoryItems,
            )
              ..where((i) => i.id.equals(widget.itemId!)))
        .getSingleOrNull();
    if (!mounted) return;
    setState(() {
      _loading = false;
      _existing = row;
      if (row != null) {
        _nameCtrl.text = row.name;
        _unit = row.unit;
        _minStockCtrl.text = row.minStock.toString();
        _costCtrl.text = row.costPerUnit.toString();
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorName = null;
    });
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _saving = false;
        _errorName = 'Nama wajib diisi';
      });
      return;
    }
    final minStock =
        double.tryParse(_minStockCtrl.text.replaceAll(',', '.')) ?? 0;
    final cost = double.tryParse(_costCtrl.text.replaceAll(',', '.')) ?? 0;
    final now = DateTime.now();
    final dao = ref.read(inventoryDaoProvider);

    String idToSync;
    if (_existing == null) {
      final branch = await ref.read(selectedBranchProvider.future);
      if (branch == null) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _errorName = 'Pilih cabang dulu di Pengaturan';
        });
        return;
      }
      final id = const Uuid().v7();
      await dao.upsertItem(InventoryItemsCompanion.insert(
        id: id,
        branchId: branch.id,
        name: name,
        unit: _unit,
        minStock: Value(minStock),
        costPerUnit: Value(cost),
        createdAt: now,
        updatedAt: now,
      ));
      idToSync = id;
    } else {
      await dao.upsertItem(InventoryItemsCompanion(
        id: Value(_existing!.id),
        branchId: Value(_existing!.branchId),
        name: Value(name),
        unit: Value(_unit),
        cachedStock: Value(_existing!.cachedStock),
        minStock: Value(minStock),
        costPerUnit: Value(cost),
        createdAt: Value(_existing!.createdAt),
        updatedAt: Value(now),
      ));
      idToSync = _existing!.id;
    }

    await ref.read(outboxDaoProvider).enqueue(
          OutboxItemsCompanion.insert(
            id: const Uuid().v7(),
            entityType: OutboxEntityType.inventoryItem,
            payload: jsonEncode({'id': idToSync}),
            createdAt: now,
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Memuat…')),
        body: const Center(child: AppLoadingIndicator()),
      );
    }
    if (_isEditing && _existing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Item Stok')),
        body: const AppEmptyState(
          title: 'Item tidak ditemukan',
          icon: Icons.search_off_outlined,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Ubah Item Stok' : 'Tambah Item Stok'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Field(
            label: 'Nama bahan',
            controller: _nameCtrl,
            hint: 'mis. Gula Aren, Susu Fresh',
            errorText: _errorName,
            autofocus: !_isEditing,
            required: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Satuan',
            style: AppTypography.labelSm
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final u in StockUnit.values)
                ChoiceChip(
                  label: Text(stockUnitLabel(u)),
                  selected: _unit == u,
                  onSelected: (_) => setState(() => _unit = u),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'Stok minimum',
            controller: _minStockCtrl,
            hint: '0',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            suffixText: stockUnitLabel(_unit),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'Harga modal per ${stockUnitLabel(_unit)}',
            controller: _costCtrl,
            hint: '0',
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            suffixText: 'Rp',
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: _isEditing ? 'Simpan Perubahan' : 'Tambah Item',
            icon: Icons.save_outlined,
            onPressed: _saving ? null : _save,
            isLoading: _saving,
            fullWidth: true,
          ),
          if (!_isEditing) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Setelah item dibuat, masukkan stok awal dari halaman detail item.',
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
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
    this.autofocus = false,
    this.required = false,
    this.suffixText,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool autofocus;
  final bool required;
  final String? suffixText;

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
          autofocus: autofocus,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
            suffixText: suffixText,
          ),
        ),
      ],
    );
  }
}
