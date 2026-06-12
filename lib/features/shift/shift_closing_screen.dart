import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
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
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_provider.dart';
import '../settings/branch_selection_provider.dart';
import 'shift_closing_providers.dart';

/// ENH-001 — daily cash reconciliation / Z-report screen.
class ShiftClosingScreen extends ConsumerStatefulWidget {
  const ShiftClosingScreen({super.key});

  @override
  ConsumerState<ShiftClosingScreen> createState() => _ShiftClosingScreenState();
}

class _ShiftClosingScreenState extends ConsumerState<ShiftClosingScreen> {
  final _openingCtrl = TextEditingController(text: '0');
  final _countedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _openingCtrl.dispose();
    _countedCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _opening => double.tryParse(_openingCtrl.text.trim()) ?? 0;
  double get _counted => double.tryParse(_countedCtrl.text.trim()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final branchAsync = ref.watch(selectedBranchProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navShiftClosing)),
      body: branchAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: l10n.shiftLoadBranchFailed,
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (branch) {
          if (branch == null) {
            return AppEmptyState(
              title: l10n.shiftNoBranchTitle,
              icon: Icons.store_outlined,
              message: l10n.shiftNoBranchMessage,
            );
          }
          return _Body(branch: branch, state: this);
        },
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.branch, required this.state});
  final BranchRow branch;
  final _ShiftClosingScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final summaryAsync = ref.watch(todayCashSummaryProvider(branch.id));
    final historyAsync = ref.watch(shiftClosingHistoryProvider(branch.id));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(todayCashSummaryProvider(branch.id));
      },
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Header(branch: branch),
          const SizedBox(height: AppSpacing.lg),
          summaryAsync.when(
            loading: () => const AppCard(
              child: SizedBox(
                height: 120,
                child: Center(child: AppLoadingIndicator()),
              ),
            ),
            error: (e, _) => AppCard(
              child: Text(l10n.shiftLoadFailed('$e')),
            ),
            data: (summary) => _ReconciliationCard(
              branch: branch,
              summary: summary,
              state: state,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            l10n.shiftHistorySection,
            style: AppTypography.labelSm.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          historyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppLoadingIndicator(),
            ),
            error: (e, _) => Text(l10n.shiftLoadFailed('$e'),
                style: AppTypography.bodySm.copyWith(color: AppColors.danger)),
            data: (rows) {
              if (rows.isEmpty) {
                return AppEmptyState(
                  title: l10n.shiftNoHistoryTitle,
                  icon: Icons.history_outlined,
                  message: l10n.shiftNoHistoryMessage,
                );
              }
              return Column(
                children: [
                  for (final r in rows) _HistoryTile(row: r),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.branch});
  final BranchRow branch;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.point_of_sale_outlined,
                color: AppColors.primaryDark),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(branch.name, style: AppTypography.titleMd),
                Text(
                  formatDateTime(DateTime.now()),
                  style: AppTypography.bodySm
                      .copyWith(color: context.colors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReconciliationCard extends ConsumerWidget {
  const _ReconciliationCard({
    required this.branch,
    required this.summary,
    required this.state,
  });
  final BranchRow branch;
  final TodayCashSummary summary;
  final _ShiftClosingScreenState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final expected = state._opening + summary.netCash;
    final variance = state._counted - expected;
    final hasCounted = state._countedCtrl.text.trim().isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.shiftCashSummarySection,
              style: AppTypography.labelSm.copyWith(
                color: context.colors.textSecondary,
                letterSpacing: 0.8,
              )),
          const SizedBox(height: AppSpacing.md),
          _CashRow(
            label: l10n.shiftOpeningFloat,
            valueWidget: SizedBox(
              width: 140,
              child: TextField(
                controller: state._openingCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.right,
                onChanged: (_) => state.setState(() {}),
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  isDense: true,
                ),
              ),
            ),
          ),
          _CashRow(
            label: l10n.shiftCashSales(summary.transactionCount),
            value: formatRupiah(summary.cashIn),
          ),
          if (summary.cashRefunded > 0)
            _CashRow(
              label: l10n.shiftCashRefund(summary.refundCount),
              value: '-${formatRupiah(summary.cashRefunded)}',
              valueColor: AppColors.danger,
            ),
          const Divider(),
          _CashRow(
            label: l10n.shiftExpectedCash,
            value: formatRupiah(expected),
            highlight: true,
          ),
          const SizedBox(height: AppSpacing.md),
          _CashRow(
            label: l10n.shiftCountedCash,
            valueWidget: SizedBox(
              width: 140,
              child: TextField(
                controller: state._countedCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.right,
                onChanged: (_) => state.setState(() {}),
                decoration: const InputDecoration(
                  prefixText: 'Rp ',
                  isDense: true,
                  hintText: '0',
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (hasCounted)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: variance == 0
                    ? const Color(0xFFDBEAFE) // Sky-100 — pair with success
                    : (variance < 0
                        ? const Color(0xFFFEE2E2)
                        : AppColors.accentSurface),
                borderRadius: AppRadius.radiusSm,
              ),
              child: Row(
                children: [
                  Icon(
                    variance == 0
                        ? Icons.check_circle_outline
                        : (variance < 0
                            ? Icons.trending_down
                            : Icons.trending_up),
                    color: variance == 0
                        ? AppColors.success
                        : (variance < 0 ? AppColors.danger : AppColors.accent),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      variance == 0
                          ? l10n.shiftBalanced
                          : (variance < 0
                              ? l10n.shiftShort(
                                  formatRupiah(variance.abs()),
                                )
                              : l10n.shiftOver(formatRupiah(variance))),
                      style: AppTypography.bodyMd.copyWith(
                        color: variance == 0
                            ? AppColors.success
                            : (variance < 0
                                ? AppColors.danger
                                : AppColors.accent),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: state._notesCtrl,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n.shiftNotesOptional,
              hintText: l10n.shiftNotesHint,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: state._saving ? l10n.statusSaving : l10n.navShiftClosing,
            icon: Icons.lock_outline,
            onPressed: !hasCounted || state._saving
                ? null
                : () => _save(context, ref, expected, variance),
            isLoading: state._saving,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Future<void> _save(
    BuildContext context,
    WidgetRef ref,
    double expected,
    double variance,
  ) async {
    state.setState(() => state._saving = true);
    final dao = ref.read(shiftClosingDaoProvider);
    final userId = ref.read(currentUserProvider)?.id;
    try {
      await dao.insert(ShiftClosingsCompanion.insert(
        id: const Uuid().v7(),
        branchId: branch.id,
        closedBy: Value(userId),
        openingFloat: Value(state._opening),
        expectedCash: expected,
        countedCash: state._counted,
        variance: variance,
        notes: Value(state._notesCtrl.text.trim().isEmpty
            ? null
            : state._notesCtrl.text.trim()),
        closedAt: DateTime.now(),
      ));
      if (!context.mounted) return;
      ref.invalidate(shiftClosingHistoryProvider(branch.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).shiftSaved)),
      );
      // Clear inputs for the next session.
      state._countedCtrl.clear();
      state._notesCtrl.clear();
      state.setState(() {});
    } finally {
      if (state.mounted) state.setState(() => state._saving = false);
    }
  }
}

class _CashRow extends StatelessWidget {
  const _CashRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.valueColor,
    this.highlight = false,
  }) : assert(value != null || valueWidget != null);
  final String label;
  final String? value;
  final Widget? valueWidget;
  final Color? valueColor;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: highlight
                  ? AppTypography.titleMd
                  : AppTypography.bodyMd.copyWith(
                      color: context.colors.textSecondary,
                    ),
            ),
          ),
          if (valueWidget != null)
            valueWidget!
          else
            Text(
              value!,
              style: (highlight ? AppTypography.titleMd : AppTypography.bodyMd)
                  .copyWith(
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.row});
  final ShiftClosingRow row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final isShort = row.variance < 0;
    final isOver = row.variance > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border.all(color: context.colors.border),
        borderRadius: AppRadius.radiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDateTime(row.closedAt),
                  style: AppTypography.titleMd,
                ),
              ),
              if (row.variance == 0)
                AppBadge(
                  label: l10n.shiftBalancedBadge,
                  icon: Icons.check_circle_outline,
                  tone: AppBadgeTone.success,
                )
              else if (isShort)
                AppBadge(
                  label: l10n.shiftShort(formatRupiah(row.variance.abs())),
                  icon: Icons.trending_down,
                  tone: AppBadgeTone.danger,
                )
              else if (isOver)
                AppBadge(
                  label: l10n.shiftOver(formatRupiah(row.variance)),
                  icon: Icons.trending_up,
                  tone: AppBadgeTone.warning,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.shiftHistorySummary(
              formatRupiah(row.openingFloat),
              formatRupiah(row.expectedCash),
              formatRupiah(row.countedCash),
            ),
            style: AppTypography.bodySm
                .copyWith(color: context.colors.textSecondary),
          ),
          if (row.notes != null && row.notes!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              row.notes!,
              style: AppTypography.bodySm.copyWith(
                fontStyle: FontStyle.italic,
                color: context.colors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
