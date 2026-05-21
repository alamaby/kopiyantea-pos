import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'bank_account_providers.dart';

/// FEAT-015 — bottom sheet to pick a bank account at checkout when the
/// payment method is Transfer. Returns the selected [BankAccountRow] via
/// [Navigator.pop] — caller handles snapshot serialization.
class BankAccountPickerSheet extends ConsumerWidget {
  const BankAccountPickerSheet({this.selectedId, super.key});

  final String? selectedId;

  static Future<BankAccountRow?> show(
    BuildContext context, {
    String? selectedId,
  }) =>
      showModalBottomSheet<BankAccountRow>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        backgroundColor: context.colors.surface,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        builder: (_) => BankAccountPickerSheet(selectedId: selectedId),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(activeBankAccountsProvider);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Pilih Rekening Tujuan',
                      style: AppTypography.headlineMd),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: accountsAsync.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (e, _) => AppEmptyState(
                title: 'Gagal memuat',
                icon: Icons.error_outline,
                message: e.toString(),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return const AppEmptyState(
                    title: 'Belum ada rekening aktif',
                    icon: Icons.account_balance_outlined,
                    message:
                        'Owner perlu menambahkan rekening lewat '
                        'Pengaturan → Rekening Bank.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _AccountTile(
                    row: rows[i],
                    selected: selectedId == rows[i].id,
                    onTap: () => Navigator.of(context).pop(rows[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.row,
    required this.selected,
    required this.onTap,
  });
  final BankAccountRow row;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          selected ? AppColors.primarySurface : context.colors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? AppColors.primary
                  : context.colors.border,
              width: selected ? 2 : 1,
            ),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_outlined,
                  color: selected
                      ? AppColors.primaryDark
                      : context.colors.textSecondary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.bankName, style: AppTypography.titleMd),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      row.accountNumber,
                      style: AppTypography.bodyMd.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'a.n. ${row.accountHolder}',
                      style: AppTypography.bodySm.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
