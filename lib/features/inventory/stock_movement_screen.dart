import 'dart:convert';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../auth/auth_provider.dart';
import 'inventory_providers.dart';

/// FEAT-005 — record a manual stock movement (purchase / adjustment / waste).
///
/// Inserts a new `inventory_movements` row + reconciles local `cached_stock`
/// + enqueues an outbox `inventoryMovement` push (Supabase server-side
/// trigger reconciles cached_stock there too, ADR-0003).
class StockMovementScreen extends ConsumerStatefulWidget {
  const StockMovementScreen({required this.itemId, super.key});
  final String itemId;

  @override
  ConsumerState<StockMovementScreen> createState() =>
      _StockMovementScreenState();
}

class _StockMovementScreenState extends ConsumerState<StockMovementScreen> {
  final _qtyCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  MovementType _type = MovementType.purchase;
  bool _saving = false;
  String? _errorQty;

  static const _allowedTypes = [
    MovementType.purchase,
    MovementType.adjustment,
    MovementType.waste,
  ];

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Signed multiplier: positive for purchase + (positive) adjustment;
  /// negative for waste + (negative) adjustment is handled separately via
  /// the user typing a negative number.
  double _appliedDelta(double qty) {
    return switch (_type) {
      MovementType.purchase => qty.abs(),
      MovementType.waste => -qty.abs(),
      MovementType.adjustment => qty, // allow sign from user input
      _ => qty,
    };
  }

  Future<void> _save(InventoryItemRow item) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorQty = null;
    });
    final qty = double.tryParse(_qtyCtrl.text.replaceAll(',', '.'));
    if (qty == null || qty == 0) {
      setState(() {
        _saving = false;
        _errorQty = 'Jumlah tidak valid';
      });
      return;
    }
    final delta = _appliedDelta(qty);
    final now = DateTime.now();
    final cashierId = ref.read(currentUserProvider)?.id;
    final movementId = const Uuid().v7();
    final db = ref.read(databaseProvider);

    await db.transaction(() async {
      await db.into(db.inventoryMovements).insert(
            InventoryMovementsCompanion.insert(
              id: movementId,
              inventoryItemId: item.id,
              branchId: item.branchId,
              movementType: _type,
              deltaSigned: delta,
              notes: Value(_notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim()),
              createdBy: Value(cashierId),
              createdAt: now,
            ),
          );
      // Local cached_stock reconciliation (same pattern as checkout).
      await db.customUpdate(
        'UPDATE inventory_items SET cached_stock = cached_stock + ? '
        'WHERE id = ?',
        variables: [
          Variable<double>(delta),
          Variable<String>(item.id),
        ],
        updates: {db.inventoryItems},
      );
      await ref.read(outboxDaoProvider).enqueue(
            OutboxItemsCompanion.insert(
              id: const Uuid().v7(),
              entityType: OutboxEntityType.inventoryMovement,
              payload: jsonEncode({'id': movementId}),
              createdAt: now,
            ),
          );
    });
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final itemAsync = ref.watch(inventoryItemProvider(widget.itemId));
    return Scaffold(
      appBar: AppBar(title: const Text('Catat Pergerakan Stok')),
      body: itemAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat item',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (item) {
          if (item == null) {
            return const AppEmptyState(
              title: 'Item tidak ditemukan',
              icon: Icons.search_off_outlined,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: AppTypography.headlineMd),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Stok saat ini: ${formatStock(item.cachedStock, item.unit)}',
                      style: AppTypography.bodySm
                          .copyWith(color: context.colors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Jenis pergerakan',
                style: AppTypography.labelSm
                    .copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              SegmentedButton<MovementType>(
                segments: [
                  for (final t in _allowedTypes)
                    ButtonSegment(
                      value: t,
                      label: Text(movementTypeLabel(t)),
                      icon: Icon(_iconFor(t)),
                    ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                _type == MovementType.adjustment
                    ? 'Jumlah penyesuaian (gunakan tanda - untuk pengurangan)'
                    : 'Jumlah',
                style: AppTypography.labelSm
                    .copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '0',
                  suffixText: stockUnitLabel(item.unit),
                  errorText: _errorQty,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Catatan (opsional)',
                style: AppTypography.labelSm
                    .copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'mis. Beli dari supplier A, susut karena tumpah',
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: _saving ? 'Menyimpan…' : 'Catat',
                icon: Icons.save_outlined,
                onPressed: _saving ? null : () => _save(item),
                isLoading: _saving,
                fullWidth: true,
              ),
            ],
          );
        },
      ),
    );
  }

  IconData _iconFor(MovementType t) => switch (t) {
        MovementType.purchase => Icons.add_shopping_cart_outlined,
        MovementType.adjustment => Icons.tune_outlined,
        MovementType.waste => Icons.delete_outline,
        _ => Icons.swap_horiz_outlined,
      };
}
