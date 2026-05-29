import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/domain/enums.dart';
import '../../core/sync/sync_provider.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'branch_selection_provider.dart';

part 'outbox_queue_screen.g.dart';

/// FEAT-003 — observable list of all outbox rows for the queue screen.
@riverpod
Stream<List<OutboxItemRow>> allOutboxRows(AllOutboxRowsRef ref) =>
    ref.watch(outboxDaoProvider).watchAll();

class OutboxQueueScreen extends ConsumerWidget {
  const OutboxQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowsAsync = ref.watch(allOutboxRowsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antrian Sinkronisasi'),
        actions: [
          IconButton(
            tooltip: 'Coba ulang semua yang gagal',
            icon: const Icon(Icons.refresh),
            onPressed: () => _retryAllFailed(context, ref),
          ),
          IconButton(
            tooltip: 'Hapus semua yang gagal',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => _deleteAllFailed(context, ref),
          ),
        ],
      ),
      body: rowsAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat antrian',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (rows) {
          if (rows.isEmpty) {
            return const AppEmptyState(
              title: 'Antrian kosong',
              icon: Icons.cloud_done_outlined,
              message: 'Semua data sudah tersinkron.',
            );
          }
          final pending = rows
              .where((r) => r.status == OutboxStatus.pending)
              .toList(growable: false);
          final failed = rows
              .where((r) => r.status == OutboxStatus.failed)
              .toList(growable: false);
          final done = rows
              .where((r) => r.status == OutboxStatus.done)
              .toList(growable: false);
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              if (failed.isNotEmpty) ...[
                _SectionHeader(
                  label: 'GAGAL (${failed.length})',
                  tone: AppBadgeTone.danger,
                ),
                ...failed.map((r) => _OutboxTile(row: r)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (pending.isNotEmpty) ...[
                _SectionHeader(
                  label: 'MENUNGGU (${pending.length})',
                  tone: AppBadgeTone.warning,
                ),
                ...pending.map((r) => _OutboxTile(row: r)),
                const SizedBox(height: AppSpacing.lg),
              ],
              if (done.isNotEmpty) ...[
                _SectionHeader(
                  label: 'SELESAI (${done.length})',
                  tone: AppBadgeTone.success,
                ),
                ...done.take(20).map((r) => _OutboxTile(row: r)),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteAllFailed(BuildContext context, WidgetRef ref) async {
    final rows = ref.read(allOutboxRowsProvider).valueOrNull ?? const [];
    final failedCount =
        rows.where((r) => r.status == OutboxStatus.failed).length;
    if (failedCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada baris gagal untuk dihapus')),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua yang gagal?'),
        content: Text(
          '$failedCount baris gagal akan dihapus permanen. Data yang '
          'belum sampai ke server akan hilang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus Semua'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final n = await ref.read(outboxDaoProvider).deleteAllFailed();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$n baris gagal dihapus')),
    );
  }

  Future<void> _retryAllFailed(BuildContext context, WidgetRef ref) async {
    final dao = ref.read(outboxDaoProvider);
    final n = await dao.retryAllFailed();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$n baris di-reset ke status menunggu')),
    );
    // Trigger an immediate push attempt.
    final branchIds =
        ref.read(allBranchesProvider).valueOrNull?.map((b) => b.id).toList();
    await ref.read(syncProvider.notifier).syncNow(branchIds: branchIds);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.tone});
  final String label;
  final AppBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.sm,
      ),
      child: Text(
        label,
        style: AppTypography.labelSm.copyWith(
          color: context.colors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _OutboxTile extends ConsumerWidget {
  const _OutboxTile({required this.row});
  final OutboxItemRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preview = _payloadPreview(row);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_iconFor(row.entityType),
                    size: 18, color: context.colors.textSecondary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _entityLabel(row.entityType),
                  style: AppTypography.titleMd,
                ),
                const Spacer(),
                if (row.attemptCount > 0)
                  Text(
                    '${row.attemptCount}×',
                    style: AppTypography.labelXs.copyWith(
                      color: context.colors.textTertiary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              preview,
              style: AppTypography.bodySm.copyWith(
                color: context.colors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${formatRelativeTime(row.createdAt)} · ${formatDateTime(row.createdAt)}',
              style: AppTypography.labelXs.copyWith(
                color: context.colors.textTertiary,
              ),
            ),
            if (row.lastError != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Builder(builder: (ctx) {
                final isDark = Theme.of(ctx).brightness == Brightness.dark;
                // Mirror the danger-tone palette from AppBadge so the banner
                // stays legible in both modes (master prompt §6.7).
                final bg = isDark
                    ? AppColors.danger.withValues(alpha: 0.22)
                    : const Color(0xFFFEE2E2);
                final fg = isDark ? const Color(0xFFFECACA) : AppColors.danger;
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline, size: 14, color: fg),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: SelectableText(
                          row.lastError!,
                          style: AppTypography.labelSm.copyWith(color: fg),
                          maxLines: 6,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            if (row.status != OutboxStatus.done) ...[
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  AppButton(
                    label: 'Coba lagi',
                    icon: Icons.refresh,
                    variant: AppButtonVariant.secondary,
                    onPressed: () => _retry(context, ref),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppButton(
                    label: 'Hapus',
                    icon: Icons.delete_outline,
                    variant: AppButtonVariant.danger,
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    await ref.read(outboxDaoProvider).retryNow(row.id);
    if (!context.mounted) return;
    final branchIds =
        ref.read(allBranchesProvider).valueOrNull?.map((b) => b.id).toList();
    await ref.read(syncProvider.notifier).syncNow(branchIds: branchIds);
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus dari antrian?'),
        content: const Text(
          'Data ini akan dihapus permanen dari antrian sinkronisasi. '
          'Jika data belum sampai ke server, data akan hilang.',
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
    await ref.read(outboxDaoProvider).deleteById(row.id);
  }

  static String _entityLabel(OutboxEntityType t) => switch (t) {
        OutboxEntityType.transaction => 'Transaksi',
        OutboxEntityType.transactionItem => 'Item Transaksi',
        OutboxEntityType.inventoryMovement => 'Pergerakan Stok',
        OutboxEntityType.customer => 'Pelanggan',
        OutboxEntityType.branch => 'Cabang',
        OutboxEntityType.inventoryItem => 'Item Stok',
        OutboxEntityType.appUser => 'Pengguna',
        OutboxEntityType.userBranchAccess => 'Akses Cabang',
        OutboxEntityType.pendingInvitation => 'Undangan Pengguna',
        OutboxEntityType.optionGroup => 'Grup Modifier',
        OutboxEntityType.optionItem => 'Opsi Modifier',
        OutboxEntityType.productOptionGroup => 'Link Modifier',
        OutboxEntityType.receiptSetting => 'Tampilan Struk',
        OutboxEntityType.product => 'Produk',
        OutboxEntityType.branchProduct => 'Override Cabang',
        OutboxEntityType.productRecipe => 'Resep',
        OutboxEntityType.bankAccount => 'Rekening Bank',
        OutboxEntityType.category => 'Kategori',
        OutboxEntityType.customerPointLedger => 'Poin Pelanggan',
      };

  static IconData _iconFor(OutboxEntityType t) => switch (t) {
        OutboxEntityType.transaction => Icons.point_of_sale_outlined,
        OutboxEntityType.transactionItem => Icons.receipt_long_outlined,
        OutboxEntityType.inventoryMovement => Icons.inventory_2_outlined,
        OutboxEntityType.customer => Icons.person_outline,
        OutboxEntityType.branch => Icons.store_outlined,
        OutboxEntityType.inventoryItem => Icons.kitchen_outlined,
        OutboxEntityType.appUser => Icons.badge_outlined,
        OutboxEntityType.userBranchAccess => Icons.vpn_key_outlined,
        OutboxEntityType.pendingInvitation => Icons.mark_email_unread_outlined,
        OutboxEntityType.optionGroup => Icons.tune,
        OutboxEntityType.optionItem => Icons.toggle_on_outlined,
        OutboxEntityType.productOptionGroup => Icons.link,
        OutboxEntityType.receiptSetting => Icons.receipt_long_outlined,
        OutboxEntityType.product => Icons.coffee_outlined,
        OutboxEntityType.branchProduct => Icons.storefront_outlined,
        OutboxEntityType.productRecipe => Icons.menu_book_outlined,
        OutboxEntityType.bankAccount => Icons.account_balance_outlined,
        OutboxEntityType.category => Icons.category_outlined,
        OutboxEntityType.customerPointLedger => Icons.stars_outlined,
      };

  static String _payloadPreview(OutboxItemRow row) {
    try {
      final decoded = jsonDecode(row.payload) as Map<String, dynamic>;
      // Show a few key fields based on entity type.
      final keys = decoded.keys.take(3).toList();
      return keys.map((k) => '$k: ${decoded[k]}').join(' · ');
    } catch (_) {
      final raw = row.payload;
      return raw.length > 100 ? '${raw.substring(0, 100)}…' : raw;
    }
  }
}
