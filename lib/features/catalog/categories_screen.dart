import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/domain/enums.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'category_providers.dart';

/// Owner-only CRUD untuk registry kategori produk (Tier 1).
class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(allCategoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori Produk'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_category',
        onPressed: () => _showForm(context, ref, existing: null),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: rowsAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(
              title: 'Belum ada kategori',
              icon: Icons.category_outlined,
              message:
                  'Tap "Tambah" untuk membuat kategori (mis. Kopi, Pastry). '
                  'Kategori akan muncul sebagai pilihan saat menambah/ubah '
                  'produk.',
            );
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxxl,
            ),
            itemCount: rows.length,
            onReorder: (oldIndex, newIndex) =>
                _reorder(ref, rows, oldIndex, newIndex),
            itemBuilder: (_, i) {
              final row = rows[i];
              return Padding(
                key: ValueKey(row.id),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _CategoryTile(
                  row: row,
                  onEdit: () => _showForm(context, ref, existing: row),
                  onDelete: () => _confirmDelete(context, ref, row),
                  onToggleActive: () => _toggleActive(ref, row),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    required CategoryRow? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _CategoryForm(existing: existing),
    );
  }

  Future<void> _toggleActive(WidgetRef ref, CategoryRow row) async {
    final now = DateTime.now();
    await ref.read(categoryDaoProvider).updateById(
          row.id,
          CategoriesCompanion(
            isActive: Value(!row.isActive),
            updatedAt: Value(now),
          ),
        );
    await _enqueueCategory(ref, row.id, now);
  }

  static Future<void> _enqueueCategory(
    WidgetRef ref,
    String id,
    DateTime now, {
    String? action,
  }) async {
    final payload = <String, dynamic>{'id': id};
    if (action != null) payload['action'] = action;
    await ref.read(outboxDaoProvider).enqueue(OutboxItemsCompanion.insert(
          id: const Uuid().v7(),
          entityType: OutboxEntityType.category,
          payload: jsonEncode(payload),
          createdAt: now,
        ));
  }

  static Future<void> _enqueueProducts(
    WidgetRef ref,
    List<String> productIds,
    DateTime now,
  ) async {
    if (productIds.isEmpty) return;
    final outboxDao = ref.read(outboxDaoProvider);
    const uuid = Uuid();
    for (final pid in productIds) {
      await outboxDao.enqueue(OutboxItemsCompanion.insert(
        id: uuid.v7(),
        entityType: OutboxEntityType.product,
        payload: jsonEncode({'id': pid}),
        createdAt: now,
      ));
    }
  }

  Future<void> _reorder(
    WidgetRef ref,
    List<CategoryRow> rows,
    int oldIndex,
    int newIndex,
  ) async {
    // ReorderableListView's contract: jika item dipindah ke bawah,
    // newIndex sudah +1 — kompensasi sebelum memetakan indeks baru.
    var ni = newIndex;
    if (oldIndex < ni) ni -= 1;
    final reordered = [...rows];
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(ni, moved);

    final dao = ref.read(categoryDaoProvider);
    final now = DateTime.now();
    for (var i = 0; i < reordered.length; i++) {
      final r = reordered[i];
      if (r.sortOrder == i) continue;
      await dao.updateById(
        r.id,
        CategoriesCompanion(
          sortOrder: Value(i),
          updatedAt: Value(now),
        ),
      );
      await _enqueueCategory(ref, r.id, now);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    CategoryRow row,
  ) async {
    final dao = ref.read(categoryDaoProvider);
    final usedCount = await dao.countProductsUsing(row.name);
    if (!context.mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_outlined,
            size: 36, color: AppColors.warning),
        title: const Text('Hapus kategori?'),
        content: Text(
          usedCount == 0
              ? '"${row.name}" akan dihapus permanen.'
              : '"${row.name}" sedang dipakai oleh $usedCount produk. '
                  'Setelah dihapus, produk-produk itu akan kehilangan '
                  'kategori (jadi kosong).',
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
    if (ok != true) return;
    final now = DateTime.now();
    final affected = await dao.deleteWithDetach(
      id: row.id,
      name: row.name,
      now: now,
    );
    await _enqueueCategory(ref, row.id, now, action: 'delete');
    await _enqueueProducts(ref, affected, now);
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.row,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  final CategoryRow row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final color = categoryColorFromStorage(row.color);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: AppRadius.radiusLg,
      ),
      child: Row(
        children: [
          Icon(Icons.drag_indicator, color: context.colors.textTertiary),
          const SizedBox(width: AppSpacing.sm),
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color ?? context.colors.surfaceAlt,
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.border),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(row.name, style: AppTypography.titleMd),
          ),
          if (!row.isActive)
            const AppBadge(
              label: 'Nonaktif',
              icon: Icons.pause_circle_outline,
              tone: AppBadgeTone.neutral,
            ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Ubah',
          ),
          IconButton(
            onPressed: onToggleActive,
            icon: Icon(row.isActive
                ? Icons.pause_circle_outline
                : Icons.play_circle_outline),
            tooltip: row.isActive ? 'Nonaktifkan' : 'Aktifkan',
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline),
            color: AppColors.danger,
            tooltip: 'Hapus',
          ),
        ],
      ),
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({required this.existing});
  final CategoryRow? existing;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  late TextEditingController _nameCtrl;
  int? _color;
  bool _saving = false;
  String? _errorName;

  static const _palette = <int>[
    0xEF4444, // red
    0xF97316, // orange
    0xF59E0B, // amber
    0x84CC16, // lime
    0x10B981, // emerald
    0x06B6D4, // cyan
    0x3B82F6, // blue
    0x8B5CF6, // violet
    0xEC4899, // pink
    0x6B7280, // gray
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _color = widget.existing?.color;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorName = null;
    });
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _saving = false;
        _errorName = 'Nama kategori wajib diisi';
      });
      return;
    }
    final dao = ref.read(categoryDaoProvider);
    final existingByName = await dao.getByName(name);
    if (existingByName != null && existingByName.id != widget.existing?.id) {
      setState(() {
        _saving = false;
        _errorName = 'Nama sudah dipakai kategori lain';
      });
      return;
    }
    final now = DateTime.now();
    final String savedId;
    if (widget.existing == null) {
      final all = await dao.getAll();
      final nextOrder = all.isEmpty
          ? 0
          : (all.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1);
      savedId = const Uuid().v7();
      await dao.upsert(CategoriesCompanion.insert(
        id: savedId,
        name: name,
        sortOrder: Value(nextOrder),
        color: Value(_color),
        isActive: const Value(true),
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      savedId = widget.existing!.id;
      final affected = await dao.renameWithCascade(
        id: savedId,
        oldName: widget.existing!.name,
        newName: name,
        now: now,
      );
      // Color/active update tidak ikut renameWithCascade — patch terpisah.
      await dao.updateById(
        savedId,
        CategoriesCompanion(
          color: Value(_color),
          updatedAt: Value(now),
        ),
      );
      await CategoriesScreen._enqueueProducts(ref, affected, now);
    }
    await CategoriesScreen._enqueueCategory(ref, savedId, now);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                widget.existing == null ? 'Tambah Kategori' : 'Ubah Kategori',
                style: AppTypography.headlineMd,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _nameCtrl,
                autofocus: widget.existing == null,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nama',
                  hintText: 'mis. Kopi, Pastry, Snack',
                  errorText: _errorName,
                  prefixIcon: const Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'WARNA',
                style: AppTypography.labelSm
                    .copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  _ColorSwatch(
                    color: null,
                    selected: _color == null,
                    onTap: () => setState(() => _color = null),
                  ),
                  for (final rgb in _palette)
                    _ColorSwatch(
                      color: categoryColorFromStorage(rgb),
                      selected: _color == rgb,
                      onTap: () => setState(() => _color = rgb),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              AppButton(
                label: _saving ? 'Menyimpan…' : 'Simpan',
                icon: Icons.save_outlined,
                onPressed: _saving ? null : _save,
                isLoading: _saving,
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color ?? context.colors.surfaceAlt,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppColors.primary : context.colors.border,
            width: selected ? 2.5 : 1,
          ),
        ),
        child: color == null
            ? Icon(Icons.block, size: 18, color: context.colors.textTertiary)
            : (selected
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null),
      ),
    );
  }
}
