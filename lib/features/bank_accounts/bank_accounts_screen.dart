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
import 'bank_account_providers.dart';

/// FEAT-015 — owner-only CRUD for global bank transfer accounts.
class BankAccountsScreen extends ConsumerWidget {
  const BankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(allBankAccountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Rekening Bank')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_bank',
        onPressed: () => _showForm(context, ref, existing: null),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(
              title: 'Belum ada rekening',
              icon: Icons.account_balance_outlined,
              message:
                  'Tap "Tambah" untuk menambahkan rekening bank. Kasir '
                  'akan diminta memilih rekening saat metode pembayaran '
                  'Transfer.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxxl,
            ),
            itemCount: rows.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _BankAccountTile(
              row: rows[i],
              onEdit: () => _showForm(context, ref, existing: rows[i]),
              onToggleActive: () => _toggleActive(ref, rows[i]),
              onDelete: () => _confirmDelete(context, ref, rows[i]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showForm(
    BuildContext context,
    WidgetRef ref, {
    required BankAccountRow? existing,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => _BankAccountForm(existing: existing),
    );
  }

  Future<void> _toggleActive(WidgetRef ref, BankAccountRow row) async {
    final dao = ref.read(bankAccountDaoProvider);
    final outboxDao = ref.read(outboxDaoProvider);
    final now = DateTime.now();
    await dao.updateById(
      row.id,
      BankAccountsCompanion(
        isActive: Value(!row.isActive),
        updatedAt: Value(now),
      ),
    );
    await outboxDao.enqueue(OutboxItemsCompanion.insert(
      id: const Uuid().v7(),
      entityType: OutboxEntityType.bankAccount,
      payload: jsonEncode({'id': row.id}),
      createdAt: now,
    ));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    BankAccountRow row,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_amber_outlined,
            size: 36, color: AppColors.warning),
        title: const Text('Hapus rekening?'),
        content: Text(
          '${row.bankName} ${row.accountNumber} akan dihapus permanen. '
          'Transaksi lama tetap menampilkan rekening ini (snapshot), '
          'tapi tidak bisa dipilih lagi untuk transaksi baru.',
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
    final dao = ref.read(bankAccountDaoProvider);
    final outboxDao = ref.read(outboxDaoProvider);
    await dao.deleteById(row.id);
    await outboxDao.enqueue(OutboxItemsCompanion.insert(
      id: const Uuid().v7(),
      entityType: OutboxEntityType.bankAccount,
      payload: jsonEncode({'id': row.id, 'action': 'delete'}),
      createdAt: DateTime.now(),
    ));
  }
}

class _BankAccountTile extends StatelessWidget {
  const _BankAccountTile({
    required this.row,
    required this.onEdit,
    required this.onToggleActive,
    required this.onDelete,
  });

  final BankAccountRow row;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: AppRadius.radiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_outlined,
                  color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(row.bankName, style: AppTypography.titleMd),
              ),
              if (!row.isActive)
                const AppBadge(
                  label: 'Nonaktif',
                  icon: Icons.pause_circle_outline,
                  tone: AppBadgeTone.neutral,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            row.accountNumber,
            style: AppTypography.headlineMd.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'a.n. ${row.accountHolder}',
            style: AppTypography.bodySm
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Ubah',
                  icon: Icons.edit_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: row.isActive ? 'Nonaktifkan' : 'Aktifkan',
                  icon: row.isActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  variant: AppButtonVariant.secondary,
                  onPressed: onToggleActive,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: AppColors.danger,
                tooltip: 'Hapus',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BankAccountForm extends ConsumerStatefulWidget {
  const _BankAccountForm({required this.existing});
  final BankAccountRow? existing;

  @override
  ConsumerState<_BankAccountForm> createState() => _BankAccountFormState();
}

class _BankAccountFormState extends ConsumerState<_BankAccountForm> {
  late TextEditingController _bankCtrl;
  late TextEditingController _numberCtrl;
  late TextEditingController _holderCtrl;
  late int _displayOrder;
  bool _saving = false;
  String? _errorBank;
  String? _errorNumber;
  String? _errorHolder;

  @override
  void initState() {
    super.initState();
    _bankCtrl = TextEditingController(text: widget.existing?.bankName ?? '');
    _numberCtrl =
        TextEditingController(text: widget.existing?.accountNumber ?? '');
    _holderCtrl =
        TextEditingController(text: widget.existing?.accountHolder ?? '');
    _displayOrder = widget.existing?.displayOrder ?? 0;
  }

  @override
  void dispose() {
    _bankCtrl.dispose();
    _numberCtrl.dispose();
    _holderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorBank = null;
      _errorNumber = null;
      _errorHolder = null;
    });
    final bank = _bankCtrl.text.trim();
    final number = _numberCtrl.text.trim();
    final holder = _holderCtrl.text.trim();

    if (bank.isEmpty) {
      setState(() {
        _saving = false;
        _errorBank = 'Nama bank wajib';
      });
      return;
    }
    if (number.isEmpty) {
      setState(() {
        _saving = false;
        _errorNumber = 'Nomor rekening wajib';
      });
      return;
    }
    if (holder.isEmpty) {
      setState(() {
        _saving = false;
        _errorHolder = 'Nama pemilik wajib';
      });
      return;
    }

    final now = DateTime.now();
    final id = widget.existing?.id ?? const Uuid().v7();
    final dao = ref.read(bankAccountDaoProvider);
    final outboxDao = ref.read(outboxDaoProvider);
    await dao.upsert(BankAccountsCompanion.insert(
      id: id,
      bankName: bank,
      accountNumber: number,
      accountHolder: holder,
      displayOrder: Value(_displayOrder),
      isActive: Value(widget.existing?.isActive ?? true),
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    ));
    await outboxDao.enqueue(OutboxItemsCompanion.insert(
      id: const Uuid().v7(),
      entityType: OutboxEntityType.bankAccount,
      payload: jsonEncode({'id': id}),
      createdAt: now,
    ));
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
                widget.existing == null ? 'Tambah Rekening' : 'Ubah Rekening',
                style: AppTypography.headlineMd,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _bankCtrl,
                autofocus: widget.existing == null,
                decoration: InputDecoration(
                  labelText: 'Nama Bank',
                  hintText: 'mis. BCA, Mandiri, BNI',
                  errorText: _errorBank,
                  prefixIcon: const Icon(Icons.account_balance_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _numberCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Nomor Rekening',
                  hintText: '1234567890',
                  errorText: _errorNumber,
                  prefixIcon: const Icon(Icons.numbers),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _holderCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Atas Nama',
                  hintText: 'Sesuai buku tabungan',
                  errorText: _errorHolder,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
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
