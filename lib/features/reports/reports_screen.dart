import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/enums.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/localized_labels.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../l10n/generated/app_localizations.dart';
import '../settings/branch_selection_provider.dart';
import 'report_providers.dart';
import 'share_report_image_use_case.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final selection = ref.watch(reportRangeProvider);
    final reportAsync = ref.watch(dailyReportProvider);
    final branchAsync = ref.watch(selectedBranchProvider);

    return Scaffold(
      appBar: AppBar(
        title: branchAsync.maybeWhen(
          data: (b) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.navReports),
              if (b != null)
                Text(
                  b.name,
                  style: AppTypography.labelSm
                      .copyWith(color: context.colors.textSecondary),
                ),
            ],
          ),
          orElse: () => Text(l10n.navReports),
        ),
        actions: const [
          _ShareReportButton(),
        ],
      ),
      body: Column(
        children: [
          _RangeControls(selection: selection),
          const Divider(height: 1),
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (e, _) => AppEmptyState(
                title: l10n.reportsLoadFailed,
                icon: Icons.error_outline,
                message: e.toString(),
              ),
              data: (report) {
                if (report == null) {
                  return AppEmptyState(
                    title: l10n.reportsNoBranchTitle,
                    icon: Icons.store_outlined,
                    message: l10n.reportsNoBranchMessage,
                  );
                }
                if (report.transactionCount == 0) {
                  return AppEmptyState(
                    title: l10n.reportsEmptyTitle,
                    icon: Icons.bar_chart_outlined,
                    message: l10n.reportsEmptyMessage,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(dailyReportProvider);
                    await ref.read(dailyReportProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      _RevenueCard(report: report),
                      const SizedBox(height: AppSpacing.lg),
                      _PaymentCard(report: report),
                      if (report.byBankAccount.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _BankAccountCard(report: report),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      _TopItemsCard(items: report.topItems),
                    ],
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

class _ShareReportButton extends ConsumerStatefulWidget {
  const _ShareReportButton();

  @override
  ConsumerState<_ShareReportButton> createState() => _ShareReportButtonState();
}

class _ShareReportButtonState extends ConsumerState<_ShareReportButton> {
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final report = ref.watch(dailyReportProvider).valueOrNull;
    final branch = ref.watch(selectedBranchProvider).valueOrNull;
    final enabled = report != null && branch != null && !_isSharing;

    return IconButton(
      tooltip: l10n.reportsShareImageTooltip,
      onPressed: enabled ? () => _share(context, report, branch.name) : null,
      icon: _isSharing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.ios_share_outlined),
    );
  }

  Future<void> _share(
    BuildContext context,
    DailyReport report,
    String branchName,
  ) async {
    setState(() => _isSharing = true);
    final renderObject = context.findRenderObject();
    final box = renderObject is RenderBox ? renderObject : null;
    try {
      await const ShareReportImageUseCase().share(
        l10n: AppL10n.of(context),
        report: report,
        branchName: branchName,
        sharePositionOrigin:
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppL10n.of(context).reportsShareFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}

// ── Range controls ────────────────────────────────────────────────────────────

class _RangeControls extends ConsumerWidget {
  const _RangeControls({required this.selection});

  final ReportRangeSelection selection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final p in DatePreset.values) ...[
                  ChoiceChip(
                    label: Text(localizedDatePresetLabel(l10n, p)),
                    selected: selection.preset == p,
                    onSelected: (_) =>
                        ref.read(reportRangeProvider.notifier).setPreset(p),
                    selectedColor: AppColors.primarySurface,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(
                    l10n.reportsStartDate(formatDate(selection.range.start)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _pickCustomDate(context, ref, isStart: true),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(
                    l10n.reportsEndDate(formatDate(selection.range.end)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () =>
                      _pickCustomDate(context, ref, isStart: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickCustomDate(
    BuildContext context,
    WidgetRef ref, {
    required bool isStart,
  }) async {
    final current = selection.range;
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? current.start : current.end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    ref.read(reportRangeProvider.notifier).setCustom(
          start: isStart ? picked : current.start,
          end: isStart ? current.end : picked,
        );
  }
}

// ── Revenue card ──────────────────────────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(l10n.reportsRevenue),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _rangeLabel(report.range),
            style: AppTypography.bodySm.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            formatRupiah(report.totalRevenue),
            style: AppTypography.displayMd.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: l10n.reportsTransactions,
                  value: '${report.transactionCount}',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Stat(
                  label: l10n.reportsAverage,
                  value: formatRupiah(report.averageOrderValue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _rangeLabel(DateTimeRange range) {
    if (_sameDay(range.start, range.end)) {
      return formatDayDate(range.start);
    }
    return '${formatDayDate(range.start)} - ${formatDayDate(range.end)}';
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceAlt,
        borderRadius: AppRadius.radiusMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppTypography.labelXs.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(value, style: AppTypography.titleMd),
        ],
      ),
    );
  }
}

// ── Payment breakdown ─────────────────────────────────────────────────────────

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final entries = report.byPayment.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(l10n.reportsPaymentMethods),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _PaymentRow(
              method: entries[i].key,
              stats: entries[i].value,
              total: report.totalRevenue,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Bank-account breakdown (FEAT-015) ────────────────────────────────────────

class _BankAccountCard extends StatelessWidget {
  const _BankAccountCard({required this.report});
  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final entries = report.byBankAccount.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
    final transferTotal = entries.fold<double>(
      0,
      (sum, e) => sum + e.value.revenue,
    );

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(l10n.reportsTransferByAccount),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _BankAccountRow(
              snapshot: entries[i].key,
              stats: entries[i].value,
              total: transferTotal,
            ),
          ],
        ],
      ),
    );
  }
}

class _BankAccountRow extends StatelessWidget {
  const _BankAccountRow({
    required this.snapshot,
    required this.stats,
    required this.total,
  });
  final String snapshot;
  final PaymentStats stats;
  final double total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final fraction = total > 0 ? stats.revenue / total : 0.0;
    final displaySnapshot = snapshot == missingBankAccountSnapshotKey
        ? l10n.reportsNoBankAccount
        : snapshot;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(displaySnapshot,
                  style: AppTypography.bodyMd,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              l10n.reportsTransactionCountShort(stats.count),
              style: AppTypography.labelSm
                  .copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(formatRupiah(stats.revenue), style: AppTypography.titleMd),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: context.colors.surfaceAlt,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
          ),
        ),
      ],
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({
    required this.method,
    required this.stats,
    required this.total,
  });

  final PaymentMethod method;
  final PaymentStats stats;
  final double total;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final fraction = total > 0 ? stats.revenue / total : 0.0;
    final pct = (fraction * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              localizedPaymentMethodLabel(l10n, method),
              style: AppTypography.titleMd,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$pct%',
              style: AppTypography.labelSm.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              l10n.reportsTransactionCountShort(stats.count),
              style: AppTypography.labelSm
                  .copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(formatRupiah(stats.revenue), style: AppTypography.titleMd),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: context.colors.surfaceAlt,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      ],
    );
  }
}

// ── Top items ─────────────────────────────────────────────────────────────────

class _TopItemsCard extends StatelessWidget {
  const _TopItemsCard({required this.items});

  final List<TopItem> items;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    if (items.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(l10n.reportsTopProducts),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.reportsNoSoldItems,
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(l10n.reportsTopProducts),
          const SizedBox(height: AppSpacing.sm),
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: AppSpacing.lg),
            _TopItemRow(rank: i + 1, item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _TopItemRow extends StatelessWidget {
  const _TopItemRow({required this.rank, required this.item});

  final int rank;
  final TopItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final qty = item.totalQty == item.totalQty.roundToDouble()
        ? item.totalQty.toStringAsFixed(0)
        : item.totalQty.toStringAsFixed(1);

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.primarySurface,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$rank',
            style: AppTypography.labelSm.copyWith(color: AppColors.primaryDark),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: AppTypography.titleMd),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n.reportsQtySold(qty),
                style: AppTypography.labelSm
                    .copyWith(color: context.colors.textSecondary),
              ),
            ],
          ),
        ),
        Text(formatRupiah(item.totalRevenue), style: AppTypography.titleMd),
      ],
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: context.colors.border),
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.labelSm.copyWith(
        color: context.colors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
