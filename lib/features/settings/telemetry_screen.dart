import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'telemetry_provider.dart';

/// ENH-009 — single-pane diagnostic for owner/support.
class TelemetryScreen extends ConsumerWidget {
  const TelemetryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapAsync = ref.watch(telemetrySnapshotProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Telemetri'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: () => ref.invalidate(telemetrySnapshotProvider),
          ),
        ],
      ),
      body: snapAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat telemetri',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _Card(label: 'Aplikasi', rows: [
              _Row('Nama', s.appName),
              _Row('Versi', s.appVersion),
            ]),
            const SizedBox(height: AppSpacing.lg),
            _Card(label: 'Database', rows: [
              _Row('Ukuran', _formatBytes(s.dbSizeBytes)),
              _Row('Transaksi', '${s.transactionCount}'),
              _Row('Item Transaksi', '${s.transactionItemCount}'),
              _Row('Pergerakan Stok', '${s.inventoryMovementCount}'),
            ]),
            const SizedBox(height: AppSpacing.lg),
            _Card(label: 'Sinkronisasi', rows: [
              _Row(
                'Terakhir Sinkron',
                s.lastSyncAt == null
                    ? '—'
                    : formatRelativeTime(s.lastSyncAt!),
              ),
              _Row('Menunggu', '${s.outboxPending}'),
              _Row('Gagal', '${s.outboxFailed}'),
              _Row('Selesai', '${s.outboxDone}'),
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
