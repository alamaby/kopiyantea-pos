import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_badge.dart';
import '../../settings/branch_selection_provider.dart';
import '../today_badge_provider.dart';

/// ENH-002 — compact pill in Home/POS app bars showing today's completed
/// transaction count and revenue. Tap → deeplink to Reports.
class TodayQuickBadge extends ConsumerWidget {
  const TodayQuickBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(selectedBranchProvider);
    final branch = branchAsync.valueOrNull;
    if (branch == null) return const SizedBox.shrink();

    final statsAsync = ref.watch(todayBadgeStatsProvider(branch.id));
    final stats = statsAsync.valueOrNull ?? TodayBadgeStats.empty;
    final label =
        '${stats.transactionCount} tx · ${_compactRupiah(stats.totalRevenue)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Tooltip(
        message: 'Lihat laporan hari ini',
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => context.push('/more/reports'),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: AppBadge(
              label: label,
              icon: Icons.today_outlined,
              tone: AppBadgeTone.accent,
            ),
          ),
        ),
      ),
    );
  }
}

/// Squeezes IDR into AppBar real estate — keeps full digits below 1.000,
/// switches to "rb"/"jt" suffixes above.
String _compactRupiah(double n) {
  if (n >= 1000000) {
    final v = n / 1000000;
    return 'Rp ${_trim(v)}jt';
  }
  if (n >= 1000) {
    final v = n / 1000;
    return 'Rp ${_trim(v)}rb';
  }
  return formatRupiah(n);
}

String _trim(double v) {
  // 1 decimal, drop trailing ".0", use comma as decimal separator (id_ID).
  final s = v.toStringAsFixed(1);
  final trimmed = s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  return trimmed.replaceAll('.', ',');
}
