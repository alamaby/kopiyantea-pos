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
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'modifier_providers.dart';

/// FEAT-001 — create or edit a modifier group + its options.
///
/// Each save enqueues outbox pushes for the group + each created/updated
/// option. Deleting the group cascades options server-side (FK).
class OptionGroupFormScreen extends ConsumerStatefulWidget {
  const OptionGroupFormScreen({this.groupId, super.key});
  final String? groupId;

  @override
  ConsumerState<OptionGroupFormScreen> createState() =>
      _OptionGroupFormScreenState();
}

class _OptionGroupFormScreenState
    extends ConsumerState<OptionGroupFormScreen> {
  final _nameCtrl = TextEditingController();
  bool _isRequired = false;
  bool _isMultiSelect = false;
  OptionGroupRow? _existing;
  bool _loading = false;
  bool _saving = false;
  String? _errorName;

  bool get _isEditing => widget.groupId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dao = ref.read(optionDaoProvider);
    final g = await dao.getGroupById(widget.groupId!);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _existing = g;
      if (g != null) {
        _nameCtrl.text = g.name;
        _isRequired = g.isRequired;
        _isMultiSelect = g.isMultiSelect;
      }
    });
  }

  Future<void> _saveGroup() async {
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
    final now = DateTime.now();
    final dao = ref.read(optionDaoProvider);
    final id = _existing?.id ?? const Uuid().v7();
    await dao.upsertGroup(OptionGroupsCompanion.insert(
      id: id,
      name: name,
      isRequired: Value(_isRequired),
      isMultiSelect: Value(_isMultiSelect),
      sortOrder: Value(_existing?.sortOrder ?? 0),
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
    ));
    await ref.read(outboxDaoProvider).enqueue(OutboxItemsCompanion.insert(
          id: const Uuid().v7(),
          entityType: OutboxEntityType.optionGroup,
          payload: jsonEncode({'id': id}),
          createdAt: now,
        ));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _existing = OptionGroupRow(
        id: id,
        name: name,
        isRequired: _isRequired,
        isMultiSelect: _isMultiSelect,
        sortOrder: _existing?.sortOrder ?? 0,
        createdAt: _existing?.createdAt ?? now,
        updatedAt: now,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Grup tersimpan')),
    );
  }

  Future<void> _deleteGroup() async {
    final id = _existing?.id;
    if (id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus grup?'),
        content: Text(
          'Grup "${_nameCtrl.text}" beserta semua pilihannya akan dihapus. '
          'Snapshot di transaksi lama tetap aman.',
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
    if (confirmed != true) return;
    final dao = ref.read(optionDaoProvider);
    await dao.deleteGroup(id);
    await ref.read(outboxDaoProvider).enqueue(OutboxItemsCompanion.insert(
          id: const Uuid().v7(),
          entityType: OutboxEntityType.optionGroup,
          payload: jsonEncode({'id': id}),
          createdAt: DateTime.now(),
        ));
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Ubah Grup Modifier' : 'Grup Modifier Baru'),
        actions: [
          if (_existing != null)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _deleteGroup,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text('Nama grup',
              style: AppTypography.labelSm.copyWith(
                color: context.colors.textSecondary,
              )),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              hintText: 'mis. Tingkat Gula, Ukuran Cup',
              errorText: _errorName,
            ),
            autofocus: !_isEditing,
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            value: _isRequired,
            onChanged: (v) => setState(() => _isRequired = v),
            title:
                Text('Wajib dipilih', style: AppTypography.titleMd),
            subtitle: Text(
              _isRequired
                  ? 'Pelanggan harus memilih satu opsi'
                  : 'Opsional — bisa dilewati',
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          SwitchListTile(
            value: _isMultiSelect,
            onChanged: (v) => setState(() => _isMultiSelect = v),
            title: Text('Bisa pilih lebih dari satu',
                style: AppTypography.titleMd),
            subtitle: Text(
              _isMultiSelect
                  ? 'Pelanggan bisa pilih beberapa (mis. topping)'
                  : 'Hanya satu pilihan (mis. ukuran cup)',
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _saving ? 'Menyimpan…' : 'Simpan Grup',
            icon: Icons.save_outlined,
            onPressed: _saving ? null : _saveGroup,
            isLoading: _saving,
            fullWidth: true,
          ),
          if (_existing != null) ...[
            const SizedBox(height: AppSpacing.xl),
            _OptionsSection(group: _existing!),
          ],
        ],
      ),
    );
  }
}

class _OptionsSection extends ConsumerWidget {
  const _OptionsSection({required this.group});
  final OptionGroupRow group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optsAsync = ref.watch(optionsForGroupProvider(group.id));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'PILIHAN',
                  style: AppTypography.labelSm.copyWith(
                    color: context.colors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Tambah'),
                onPressed: () => _openSheet(context, ref, null),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          optsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppLoadingIndicator(),
            ),
            error: (e, _) => Text('Gagal: $e'),
            data: (opts) {
              if (opts.isEmpty) {
                return Text(
                  'Belum ada pilihan dalam grup ini.',
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.textSecondary,
                  ),
                );
              }
              return Column(
                children: [
                  for (final o in opts) ...[
                    _OptionTile(option: o, group: group),
                    if (o != opts.last)
                      const Divider(height: 1),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _openSheet(BuildContext ctx, WidgetRef ref, OptionRow? existing) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      builder: (_) => _OptionEditorSheet(group: group, existing: existing),
    );
  }
}

class _OptionTile extends ConsumerWidget {
  const _OptionTile({required this.option, required this.group});
  final OptionRow option;
  final OptionGroupRow group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(option.name, style: AppTypography.titleMd),
      subtitle: option.priceDelta == 0
          ? null
          : Text(
              '+${formatRupiah(option.priceDelta)}',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.accent),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (option.isDefault)
            const _DefaultBadge(),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) =>
                  _OptionEditorSheet(group: group, existing: option),
            ),
          ),
        ],
      ),
    );
  }
}

class _DefaultBadge extends StatelessWidget {
  const _DefaultBadge();
  @override
  Widget build(BuildContext context) {
    return const AppBadge(
      label: 'Default',
      icon: Icons.star_outlined,
      tone: AppBadgeTone.info,
    );
  }
}

class _OptionEditorSheet extends ConsumerStatefulWidget {
  const _OptionEditorSheet({required this.group, this.existing});
  final OptionGroupRow group;
  final OptionRow? existing;

  @override
  ConsumerState<_OptionEditorSheet> createState() =>
      _OptionEditorSheetState();
}

class _OptionEditorSheetState extends ConsumerState<_OptionEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _deltaCtrl;
  bool _isDefault = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _deltaCtrl = TextEditingController(
      text: widget.existing?.priceDelta.toStringAsFixed(0) ?? '0',
    );
    _isDefault = widget.existing?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _deltaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final delta = double.tryParse(_deltaCtrl.text.replaceAll(',', '.')) ?? 0;
    final now = DateTime.now();
    final id = widget.existing?.id ?? const Uuid().v7();
    final dao = ref.read(optionDaoProvider);
    await dao.upsertOption(MenuOptionsCompanion.insert(
      id: id,
      groupId: widget.group.id,
      name: name,
      priceDelta: Value(delta),
      sortOrder: Value(widget.existing?.sortOrder ?? 0),
      isDefault: Value(_isDefault),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    ));
    await ref.read(outboxDaoProvider).enqueue(OutboxItemsCompanion.insert(
          id: const Uuid().v7(),
          entityType: OutboxEntityType.optionItem,
          payload: jsonEncode({'id': id}),
          createdAt: now,
        ));
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final dao = ref.read(optionDaoProvider);
    await dao.deleteOption(existing.id);
    await ref.read(outboxDaoProvider).enqueue(OutboxItemsCompanion.insert(
          id: const Uuid().v7(),
          entityType: OutboxEntityType.optionItem,
          payload: jsonEncode({'id': existing.id}),
          createdAt: DateTime.now(),
        ));
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 40,
                height: 4,
                margin:
                    const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: context.colors.border,
                  borderRadius: AppRadius.radiusSm,
                ),
              ),
              Text(
                widget.existing == null ? 'Pilihan Baru' : 'Ubah Pilihan',
                style: AppTypography.headlineMd,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Nama pilihan',
                  hintText: 'mis. Normal, Less, Extra',
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _deltaCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Tambahan harga (Rupiah)',
                  hintText: '0',
                ),
              ),
              SwitchListTile(
                value: _isDefault,
                onChanged: (v) => setState(() => _isDefault = v),
                title: const Text('Pilihan default'),
                subtitle: Text(
                  'Akan langsung tercentang saat pelanggan membuka picker',
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (widget.existing != null)
                    TextButton(
                      onPressed: _saving ? null : _delete,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      child: const Text('Hapus'),
                    ),
                  const Spacer(),
                  AppButton(
                    label: 'Simpan',
                    icon: Icons.check,
                    onPressed: _saving ? null : _save,
                    isLoading: _saving,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
