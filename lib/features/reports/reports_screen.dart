import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/domain/enums.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/labels.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../settings/branch_selection_provider.dart';
import 'report_providers.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(reportRangeProvider);
    final reportAsync = ref.watch(dailyReportProvider);
    final branchAsync = ref.watch(selectedBranchProvider);

    return Scaffold(
      appBar: AppBar(
        title: branchAsync.maybeWhen(
          data: (b) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Laporan'),
              if (b != null)
                Text(
                  b.name,
                  style: AppTypography.labelSm
                      .copyWith(color: context.colors.textSecondary),
                ),
            ],
          ),
          orElse: () => const Text('Laporan'),
        ),
      ),
      body: Column(
        children: [
          _RangeChips(
            selected: preset,
            onSelect: (p) =>
                ref.read(reportRangeProvider.notifier).set(p),
          ),
          const Divider(height: 1),
          Expanded(
            child: reportAsync.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (e, _) => AppEmptyState(
                title: 'Gagal memuat laporan',
                icon: Icons.error_outline,
                message: e.toString(),
              ),
              data: (report) {
                if (report == null) {
                  return const AppEmptyState(
                    title: 'Belum memilih cabang',
                    icon: Icons.store_outlined,
                    message: 'Pilih cabang aktif di Pengaturan.',
                  );
                }
                if (report.transactionCount == 0) {
                  return const AppEmptyState(
                    title: 'Belum ada transaksi',
                    icon: Icons.bar_chart_outlined,
                    message:
                        'Tidak ada transaksi selesai di periode ini.',
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

// ── Range chips ───────────────────────────────────────────────────────────────

class _RangeChips extends StatelessWidget {
  const _RangeChips({required this.selected, required this.onSelect});

  final DatePreset selected;
  final ValueChanged<DatePreset> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          for (final p in DatePreset.values) ...[
            ChoiceChip(
              label: Text(p.label),
              selected: selected == p,
              onSelected: (_) => onSelect(p),
              selectedColor: AppColors.primarySurface,
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

// ── Revenue card ──────────────────────────────────────────────────────────────

class _RevenueCard extends StatelessWidget {
  const _RevenueCard({required this.report});

  final DailyReport report;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('Pendapatan'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatRupiah(report.totalRevenue),
            style: AppTypography.displayMd.copyWith(color: AppColors.primary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Transaksi',
                  value: '${report.transactionCount}',
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _Stat(
                  label: 'Rata-rata',
                  value: formatRupiah(report.averageOrderValue),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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
    final entries = report.byPayment.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel('Metode Pembayaran'),
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
          _SectionLabel('Transfer per Rekening'),
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
    final fraction = total > 0 ? stats.revenue / total : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(snapshot,
                  style: AppTypography.bodyMd,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${stats.count} tx',
              style: AppTypography.labelSm
                  .copyWith(color: context.colors.textSecondary),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(formatRupiah(stats.revenue),
                style: AppTypography.titleMd),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: context.colors.surfaceAlt,
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.accent),
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
    final fraction = total > 0 ? stats.revenue / total : 0.0;
    final pct = (fraction * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(paymentMethodLabel(method), style: AppTypography.titleMd),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '$pct%',
              style: AppTypography.labelSm.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const Spacer(),
            Text(
              '${stats.count} tx',
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
            valueColor:
                const AlwaysStoppedAnimation<Color>(AppColors.primary),
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
    if (items.isEmpty) {
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel('Produk Terlaris'),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Belum ada item terjual',
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
          _SectionLabel('Produk Terlaris'),
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
            style:
                AppTypography.labelSm.copyWith(color: AppColors.primaryDark),
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
                '$qty terjual',
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
