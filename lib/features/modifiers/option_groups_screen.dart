import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'modifier_providers.dart';

/// FEAT-001 — owner-only list of modifier groups.
class OptionGroupsScreen extends ConsumerWidget {
  const OptionGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(allOptionGroupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier Produk')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_option_groups',
        onPressed: () => context.push('/more/settings/modifiers/new'),
        icon: const Icon(Icons.add),
        label: const Text('Grup Baru'),
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return const AppEmptyState(
              title: 'Belum ada grup modifier',
              icon: Icons.tune_outlined,
              message: 'Buat grup seperti "Tingkat Gula" atau "Ukuran Cup".',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxxl,
            ),
            itemCount: groups.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (_, i) => _GroupTile(group: groups[i]),
          );
        },
      ),
    );
  }
}

class _GroupTile extends ConsumerWidget {
  const _GroupTile({required this.group});
  final OptionGroupRow group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final optsAsync = ref.watch(optionsForGroupProvider(group.id));
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: () => context.push('/more/settings/modifiers/${group.id}'),
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(group.name,
                              style: AppTypography.titleMd),
                        ),
                        if (group.isRequired) ...[
                          const SizedBox(width: AppSpacing.sm),
                          const AppBadge(
                            label: 'Wajib',
                            icon: Icons.priority_high,
                            tone: AppBadgeTone.danger,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    optsAsync.maybeWhen(
                      data: (opts) => Text(
                        opts.isEmpty
                            ? 'Belum ada pilihan'
                            : '${opts.length} pilihan · '
                                '${group.isMultiSelect ? "multi" : "tunggal"}',
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                      orElse: () => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: context.colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
