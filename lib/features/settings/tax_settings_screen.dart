import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/domain/enums.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'branch_selection_provider.dart';

/// FEAT-004 — per-branch tax settings.
///
/// Lists active branches; tapping one opens an inline editor for tax_percentage
/// + tax_label + tax_inclusive. Saving writes a partial update to the local
/// `branches` row and enqueues an outbox `branch` push.
class TaxSettingsScreen extends ConsumerWidget {
  const TaxSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(allBranchesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan Pajak')),
      body: branchesAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat cabang',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (branches) {
          if (branches.isEmpty) {
            return const AppEmptyState(
              title: 'Belum ada cabang',
              icon: Icons.store_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: branches.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.lg),
            itemBuilder: (_, i) => _BranchTaxCard(branch: branches[i]),
          );
        },
      ),
    );
  }
}

class _BranchTaxCard extends ConsumerStatefulWidget {
  const _BranchTaxCard({required this.branch});
  final BranchRow branch;

  @override
  ConsumerState<_BranchTaxCard> createState() => _BranchTaxCardState();
}

class _BranchTaxCardState extends ConsumerState<_BranchTaxCard> {
  late TextEditingController _percentCtrl;
  late TextEditingController _labelCtrl;
  late bool _inclusive;
  bool _saving = false;
  String? _errorPercent;
  String? _errorLabel;

  @override
  void initState() {
    super.initState();
    _percentCtrl = TextEditingController(
      text: widget.branch.taxPercentage.toStringAsFixed(2),
    );
    _labelCtrl = TextEditingController(text: widget.branch.taxLabel);
    _inclusive = widget.branch.taxInclusive;
  }

  @override
  void didUpdateWidget(covariant _BranchTaxCard old) {
    super.didUpdateWidget(old);
    if (old.branch.id != widget.branch.id) {
      _percentCtrl.text = widget.branch.taxPercentage.toStringAsFixed(2);
      _labelCtrl.text = widget.branch.taxLabel;
      _inclusive = widget.branch.taxInclusive;
    }
  }

  @override
  void dispose() {
    _percentCtrl.dispose();
    _labelCtrl.dispose();
    super.dispose();
  }

  // (_dirty removed — see Simpan button comment)

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorPercent = null;
      _errorLabel = null;
    });

    final rate = double.tryParse(_percentCtrl.text.replaceAll(',', '.'));
    if (rate == null || rate < 0 || rate > 100) {
      setState(() {
        _saving = false;
        _errorPercent = 'Masukkan angka 0–100';
      });
      return;
    }
    final label = _labelCtrl.text.trim();
    if (label.isEmpty) {
      setState(() {
        _saving = false;
        _errorLabel = 'Label wajib diisi';
      });
      return;
    }

    final now = DateTime.now();
    final dao = ref.read(branchDaoProvider);
    await dao.updateById(
      widget.branch.id,
      BranchesCompanion(
        taxPercentage: Value(rate),
        taxLabel: Value(label),
        taxInclusive: Value(_inclusive),
        updatedAt: Value(now),
      ),
    );
    await ref.read(outboxDaoProvider).enqueue(
          OutboxItemsCompanion.insert(
            id: const Uuid().v7(),
            entityType: OutboxEntityType.branch,
            payload: jsonEncode({'id': widget.branch.id}),
            createdAt: now,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pengaturan pajak tersimpan')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _previewExample(
      double.tryParse(_percentCtrl.text.replaceAll(',', '.')) ?? 0,
      _inclusive,
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.branch.name, style: AppTypography.headlineMd),
          if (widget.branch.address != null)
            Text(
              widget.branch.address!,
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
          const SizedBox(height: AppSpacing.lg),
          _LabeledField(
            label: 'Tarif (%)',
            child: TextField(
              controller: _percentCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: '10',
                suffixText: '%',
                errorText: _errorPercent,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _LabeledField(
            label: 'Label',
            child: TextField(
              controller: _labelCtrl,
              decoration: InputDecoration(
                hintText: 'PB1 / PPN',
                errorText: _errorLabel,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            value: _inclusive,
            onChanged: (v) => setState(() => _inclusive = v),
            title: Text('Sudah termasuk dalam harga (inclusive)',
                style: AppTypography.titleMd),
            subtitle: Text(
              _inclusive
                  ? 'Harga di menu sudah termasuk pajak'
                  : 'Pajak ditambahkan di atas subtotal',
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.surfaceAlt,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PREVIEW',
                  style: AppTypography.labelSm.copyWith(
                    color: context.colors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(preview, style: AppTypography.bodySm),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _saving ? 'Menyimpan…' : 'Simpan',
            icon: Icons.save_outlined,
            // Always enabled when not currently saving — re-saving identical
            // values is idempotent. The dirty check was confusing users who
            // wanted to "re-confirm" 0% (e.g. UMKM tanpa pajak) but the form
            // already showed 0 from a previous save.
            onPressed: _saving ? null : _save,
            isLoading: _saving,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  String _previewExample(double rate, bool inclusive) {
    const base = 10000.0;
    if (rate <= 0) return 'Tarif 0% — tidak ada pajak';
    if (inclusive) {
      final taxComponent = base - (base / (1 + rate / 100));
      return 'Harga ${formatRupiah(base)} sudah termasuk '
          '${formatRupiah(taxComponent)} pajak (${rate.toStringAsFixed(2)}%)';
    }
    final tax = base * rate / 100;
    return 'Subtotal ${formatRupiah(base)} + pajak ${formatRupiah(tax)} '
        '(${rate.toStringAsFixed(2)}%) = ${formatRupiah(base + tax)}';
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSm
              .copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
    );
  }
}
