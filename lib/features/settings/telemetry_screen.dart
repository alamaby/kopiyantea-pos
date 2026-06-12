import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../l10n/generated/app_localizations.dart';
import 'telemetry_provider.dart';

/// ENH-009 — single-pane diagnostic for owner/support.
class TelemetryScreen extends ConsumerWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final snapAsync = ref.watch(telemetrySnapshotProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTelemetry),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: l10n.telemetryReload,
            onPressed: () => ref.invalidate(telemetrySnapshotProvider),
          ),
        ],
      ),
      body: snapAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: l10n.telemetryLoadFailed,
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _Card(label: l10n.telemetryAppSection, rows: [
              _Row(l10n.telemetryAppName, s.appName),
              _Row(l10n.telemetryVersion, s.appVersion),
            ]),
            const SizedBox(height: AppSpacing.lg),
            _Card(label: l10n.telemetryDatabaseSection, rows: [
              _Row(l10n.telemetryDatabaseSize, _formatBytes(s.dbSizeBytes)),
              _Row(l10n.transactionsTitle, '${s.transactionCount}'),
              _Row(l10n.telemetryTransactionItems, '${s.transactionItemCount}'),
              _Row(
                l10n.telemetryInventoryMovements,
                '${s.inventoryMovementCount}',
              ),
            ]),
            const SizedBox(height: AppSpacing.lg),
            _Card(label: l10n.telemetrySyncSection, rows: [
              _Row(
                l10n.telemetryLastSync,
                s.lastSyncAt == null ? '—' : formatRelativeTime(s.lastSyncAt!),
              ),
              _Row(l10n.telemetryOutboxPending, '${s.outboxPending}'),
              _Row(l10n.telemetryOutboxFailed, '${s.outboxFailed}'),
              _Row(l10n.telemetryOutboxDone, '${s.outboxDone}'),
            ]),
          ],
        ),
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(2)} MB';
}

class _Row {
  const _Row(this.label, this.value);
  final String label;
  final String value;
}

class _Card extends StatelessWidget {
  const _Card({required this.label, required this.rows});
  final String label;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              label.toUpperCase(),
              style: AppTypography.labelSm.copyWith(
                color: context.colors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      r.label,
                      style: AppTypography.bodyMd
                          .copyWith(color: context.colors.textSecondary),
                    ),
                  ),
                  Text(r.value, style: AppTypography.bodyMd),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
