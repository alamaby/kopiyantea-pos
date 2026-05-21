import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/domain/enums.dart';
import '../../core/sync/sync_provider.dart';
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
import '../auth/auth_provider.dart';
import 'branch_selection_provider.dart';
import 'settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsNotifierProvider);
    final branches = ref.watch(allBranchesProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isOwner = currentUser?.globalRole == GlobalRole.owner;

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
            if (isOwner) ...[
              const SizedBox(height: AppSpacing.lg),
              const _OwnerSection(),
            ],
            const SizedBox(height: AppSpacing.lg),
            const _SyncSection(),
            const SizedBox(height: AppSpacing.lg),
            _PrivacySection(settings: s),
            const SizedBox(height: AppSpacing.lg),
            const _AboutSection(),
            const SizedBox(height: AppSpacing.lg),
            const _SignOutSection(),
          ],
        ),
      ),
    );
  }
}

// ── Owner-only section (FEAT-004/005/006/001) ────────────────────────────────

class _OwnerSection extends StatelessWidget {
  const _OwnerSection();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(label: 'Khusus Pemilik'),
          const SizedBox(height: AppSpacing.sm),
          _OwnerTile(
            icon: Icons.people_outline,
            title: 'Pengguna',
            subtitle: 'Tambah kasir, manajer, atur akses cabang',
            route: '/more/settings/users',
          ),
          const Divider(height: 1),
          _OwnerTile(
            icon: Icons.tune_outlined,
            title: 'Modifier Produk',
            subtitle: 'Atur grup pilihan (gula, ukuran, dll.)',
            route: '/more/settings/modifiers',
          ),
          const Divider(height: 1),
          _OwnerTile(
            icon: Icons.percent_outlined,
            title: 'Pajak',
            subtitle: 'Tarif & label per cabang (PB1/PPN)',
            route: '/more/settings/tax',
          ),
          const Divider(height: 1),
          _OwnerTile(
            icon: Icons.qr_code_2_outlined,
            title: 'QRIS Statis',
            subtitle: 'Unggah gambar QRIS per cabang',
            route: '/more/settings/qris',
          ),
          const Divider(height: 1),
          _OwnerTile(
            icon: Icons.receipt_long_outlined,
            title: 'Tampilan Struk',
            subtitle: 'Logo, header, footer per cabang',
            route: '/more/settings/receipt',
          ),
        ],
      ),
    );
  }
}

class _OwnerTile extends StatelessWidget {
  const _OwnerTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => GoRouter.of(context).push(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Icon(icon, color: context.colors.textSecondary, size: 20),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTypography.titleMd),
                  Text(
                    subtitle,
                    style: AppTypography.bodySm.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: context.colors.textTertiary, size: 18),
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
                      .copyWith(color: context.colors.textSecondary),
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
                                color: context.colors.textSecondary,
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
                  .copyWith(color: context.colors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          const Divider(),
          InkWell(
            onTap: () => GoRouter.of(context).push('/more/settings/printer'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(Icons.print_outlined,
                      color: context.colors.textSecondary, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Printer Struk', style: AppTypography.titleMd),
                        Text(
                          settings.lastPrinterAddress ??
                              'Belum ada printer terhubung',
                          style: AppTypography.bodySm.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right,
                      color: context.colors.textTertiary, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Privacy / Session (FEAT-007) ─────────────────────────────────────────────

class _PrivacySection extends ConsumerWidget {
  const _PrivacySection({required this.settings});
  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSaved =
        settings.lastLoginEmail != null && settings.lastLoginEmail!.isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(label: 'Privasi & Sesi'),
          SwitchListTile(
            value: settings.rememberMe,
            onChanged: (v) async {
              await ref
                  .read(settingsNotifierProvider.notifier)
                  .setRememberMe(v);
            },
            title: Text('Ingat email login', style: AppTypography.titleMd),
            subtitle: Text(
              hasSaved && settings.rememberMe
                  ? 'Tersimpan: ${settings.lastLoginEmail}'
                  : 'Email akan otomatis terisi di layar masuk',
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          if (hasSaved) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Hapus Email Tersimpan',
              icon: Icons.delete_sweep_outlined,
              variant: AppButtonVariant.secondary,
              onPressed: () async {
                await ref
                    .read(settingsNotifierProvider.notifier)
                    .setLastLoginEmail(null);
              },
              fullWidth: true,
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
                  AppTypography.bodyMd.copyWith(color: context.colors.textSecondary),
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
          color: context.colors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Sign-out section ──────────────────────────────────────────────────────────

class _SignOutSection extends ConsumerWidget {
  const _SignOutSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(label: 'Akun'),
          const SizedBox(height: AppSpacing.sm),
          if (user != null) ...[
            Text(user.fullName, style: AppTypography.titleMd),
            const SizedBox(height: AppSpacing.xs),
            Text(
              user.globalRole.name,
              style: AppTypography.labelSm.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          AppButton(
            label: 'Keluar',
            icon: Icons.logout,
            variant: AppButtonVariant.danger,
            onPressed: () => _confirmSignOut(context, ref),
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Keluar dari akun?'),
        content: const Text(
          'Anda akan kembali ke layar masuk. Transaksi yang belum tersinkron akan tetap tersimpan di perangkat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authProvider.notifier).signOut();
  }
}

// ── Sync section ──────────────────────────────────────────────────────────────

class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingOutboxCountProvider);
    final syncState = ref.watch(syncProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionHeader(label: 'Sinkronisasi'),
              const Spacer(),
              pendingAsync.maybeWhen(
                data: (count) => count > 0
                    ? AppBadge(
                        label: '$count menunggu',
                        icon: Icons.cloud_upload_outlined,
                        tone: AppBadgeTone.warning,
                      )
                    : const AppBadge(
                        label: 'Tersinkron',
                        icon: Icons.cloud_done_outlined,
                        tone: AppBadgeTone.success,
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Row(
            label: 'Terakhir sinkron',
            value: syncState.lastSyncAt == null
                ? 'Belum pernah'
                : formatDateTime(syncState.lastSyncAt!),
          ),
          if (syncState.lastPushed > 0 ||
              syncState.lastFailed > 0 ||
              syncState.lastPulled > 0)
            _Row(
              label: 'Hasil terakhir',
              value: '${syncState.lastPushed} kirim · '
                  '${syncState.lastPulled} terima · '
                  '${syncState.lastFailed} gagal',
            ),
          if (syncState.lastError != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: AppRadius.radiusSm,
              ),
              child: Text(
                syncState.lastError!,
                style: AppTypography.labelSm
                    .copyWith(color: AppColors.danger),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: syncState.isSyncing ? 'Menyinkronkan…' : 'Sinkron Sekarang',
            icon: Icons.sync,
            onPressed: syncState.isSyncing
                ? null
                : () async {
                    // Pull master for all branches the user currently has access to.
                    final branches = await ref
                        .read(allBranchesProvider.future);
                    if (!context.mounted) return;
                    await ref.read(syncProvider.notifier).syncNow(
                          branchIds: branches.map((b) => b.id).toList(),
                        );
                  },
            isLoading: syncState.isSyncing,
            fullWidth: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Lihat Antrian',
            icon: Icons.list_alt_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => context.push('/more/settings/sync'),
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});
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
              style: AppTypography.bodyMd
                  .copyWith(color: context.colors.textSecondary),
            ),
          ),
          Text(value, style: AppTypography.bodyMd),
        ],
      ),
    );
  }
}
