import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'branch_selection_provider.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final branches = ref.watch(allBranchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: settings.when(
        loading: () =>
            const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat pengaturan',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (s) => ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _BranchSection(settings: s, branchesAsync: branches),
            const SizedBox(height: AppSpacing.lg),
            _ThemeSection(settings: s),
            const SizedBox(height: AppSpacing.lg),
            _DeviceSection(settings: s),
            const SizedBox(height: AppSpacing.lg),
            const _AboutSection(),
          ],
        ),
      ),
    );
  }
}

// ── Branch ────────────────────────────────────────────────────────────────────

class _BranchSection extends ConsumerWidget {
  const _BranchSection({required this.settings, required this.branchesAsync});

  final AppSettings settings;
  final AsyncValue<List<BranchRow>> branchesAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(label: 'Cabang'),
          const SizedBox(height: AppSpacing.sm),
          branchesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppLoadingIndicator(),
            ),
            error: (e, _) => Text(
              'Gagal memuat cabang: $e',
              style: AppTypography.bodySm.copyWith(color: AppColors.danger),
            ),
            data: (branches) {
              if (branches.isEmpty) {
                return Text(
                  'Tidak ada cabang tersedia',
                  style: AppTypography.bodyMd
                      .copyWith(color: AppColors.textSecondary),
                );
              }
              return Column(
                children: [
                  for (final b in branches)
                    RadioListTile<String>(
                      value: b.id,
                      groupValue: settings.selectedBranchId,
                      onChanged: (val) async {
                        if (val != null) {
                          await ref
                              .read(settingsNotifierProvider.notifier)
                              .setSelectedBranch(val);
                        }
                      },
                      title: Text(b.name, style: AppTypography.titleMd),
                      subtitle: b.address != null
                          ? Text(
                              b.address!,
                              style: AppTypography.bodySm.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            )
                          : null,
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.primary,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Theme ─────────────────────────────────────────────────────────────────────

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(label: 'Tampilan'),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'system',
                label: Text('Sistem'),
                icon: Icon(Icons.smartphone_outlined),
              ),
              ButtonSegment(
                value: 'light',
                label: Text('Terang'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: 'dark',
                label: Text('Gelap'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (set) async {
              await ref
                  .read(settingsNotifierProvider.notifier)
                  .setThemeMode(set.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColors.primarySurface
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Device ────────────────────────────────────────────────────────────────────

class _DeviceSection extends ConsumerWidget {
  const _DeviceSection({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(label: 'Perangkat'),
          SwitchListTile(
            value: settings.printEnabled,
            onChanged: (v) async {
              await ref
                  .read(settingsNotifierProvider.notifier)
                  .setPrintEnabled(v);
            },
            title: Text(
              'Cetak struk otomatis',
              style: AppTypography.titleMd,
            ),
            subtitle: Text(
              'Kirim struk ke printer Bluetooth setelah pembayaran',
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          if (settings.lastPrinterAddress != null) ...[
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(Icons.print_outlined,
                      color: AppColors.textSecondary, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Printer terakhir: ${settings.lastPrinterAddress}',
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── About ─────────────────────────────────────────────────────────────────────

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(label: 'Tentang'),
          const SizedBox(height: AppSpacing.sm),
          _AboutRow(label: 'Aplikasi', value: 'KopiyanteaPOS'),
          _AboutRow(label: 'Versi', value: '0.1.0+1'),
          _AboutRow(label: 'Lisensi', value: 'Proprietary'),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style:
                  AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(value, style: AppTypography.bodyMd),
        ],
      ),
    );
  }
}

// ── Shared ────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSm.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
