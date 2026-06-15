import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_constants.dart';
import '../../core/database/app_database.dart';
import '../../core/domain/enums.dart';
import '../../core/l10n/locale_provider.dart';
import '../../core/network/supabase_providers.dart';
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
import '../../l10n/generated/app_localizations.dart';
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
      appBar: AppBar(title: Text(AppL10n.of(context).navSettings)),
      body: settings.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: AppL10n.of(context).settingsLoadFailed,
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
            const _LanguageSection(),
            const SizedBox(height: AppSpacing.lg),
            _DeviceSection(settings: s),
            if (isOwner) ...[
              const SizedBox(height: AppSpacing.lg),
              const _OwnerSection(),
            ],
            const SizedBox(height: AppSpacing.lg),
            const _SyncSection(),
            const SizedBox(height: AppSpacing.lg),
            const _BackupSection(),
            const SizedBox(height: AppSpacing.lg),
            const _AboutSection(),
            const SizedBox(height: AppSpacing.lg),
            _SignOutSection(settings: s),
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
    final l10n = AppL10n.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.settingsOwnerOnly),
          const SizedBox(height: AppSpacing.sm),
          _SettingsNavTile(
            icon: Icons.people_outline,
            title: l10n.settingsUsers,
            subtitle: l10n.settingsUsersSubtitle,
            route: '/more/settings/users',
          ),
          const Divider(height: 1),
          _SettingsNavTile(
            icon: Icons.category_outlined,
            title: l10n.settingsProductCategories,
            subtitle: l10n.settingsProductCategoriesSubtitle,
            route: '/more/settings/categories',
          ),
          const Divider(height: 1),
          _SettingsNavTile(
            icon: Icons.tune_outlined,
            title: l10n.settingsProductModifiers,
            subtitle: l10n.settingsProductModifiersSubtitle,
            route: '/more/settings/modifiers',
          ),
          const Divider(height: 1),
          _SettingsNavTile(
            icon: Icons.percent_outlined,
            title: l10n.settingsTax,
            subtitle: l10n.settingsTaxSubtitle,
            route: '/more/settings/tax',
          ),
          const Divider(height: 1),
          _SettingsNavTile(
            icon: Icons.qr_code_2_outlined,
            title: l10n.settingsStaticQris,
            subtitle: l10n.settingsStaticQrisSubtitle,
            route: '/more/settings/qris',
          ),
          const Divider(height: 1),
          _SettingsNavTile(
            icon: Icons.account_balance_outlined,
            title: l10n.settingsBankAccounts,
            subtitle: l10n.settingsBankAccountsSubtitle,
            route: '/more/settings/bank-accounts',
          ),
          const Divider(height: 1),
          _SettingsNavTile(
            icon: Icons.analytics_outlined,
            title: l10n.settingsTelemetry,
            subtitle: l10n.settingsTelemetrySubtitle,
            route: '/more/settings/telemetry',
          ),
        ],
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
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
    final l10n = AppL10n.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.settingsBranch),
          const SizedBox(height: AppSpacing.sm),
          branchesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: AppLoadingIndicator(),
            ),
            error: (e, _) => Text(
              l10n.settingsBranchLoadFailed(e.toString()),
              style: AppTypography.bodySm.copyWith(color: AppColors.danger),
            ),
            data: (branches) {
              if (branches.isEmpty) {
                return Text(
                  l10n.settingsNoBranches,
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
    final l10n = AppL10n.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.settingsAppearance),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'system',
                label: Text(
                  l10n.settingsThemeSystem,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                icon: const Icon(Icons.smartphone_outlined),
              ),
              ButtonSegment(
                value: 'light',
                label: Text(
                  l10n.settingsThemeLight,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                icon: const Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: 'dark',
                label: Text(
                  l10n.settingsThemeDark,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                icon: const Icon(Icons.dark_mode_outlined),
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

// ── Language ──────────────────────────────────────────────────────────────────

class _LanguageSection extends ConsumerWidget {
  const _LanguageSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeControllerProvider);
    final l10n = AppL10n.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.settingsLanguage),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'en',
                label: Text('English'),
                icon: Text('EN'),
              ),
              ButtonSegment(
                value: 'id',
                label: Text('Indonesia'),
                icon: Text('ID'),
              ),
            ],
            selected: {locale.languageCode},
            onSelectionChanged: (set) async {
              await ref
                  .read(localeControllerProvider.notifier)
                  .setLanguageCode(set.first);
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
    final l10n = AppL10n.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.settingsDevice),
          SwitchListTile(
            value: settings.printEnabled,
            onChanged: (v) async {
              await ref
                  .read(settingsNotifierProvider.notifier)
                  .setPrintEnabled(v);
            },
            title: Text(
              l10n.settingsAutoPrintReceipt,
              style: AppTypography.titleMd,
            ),
            subtitle: Text(
              l10n.settingsAutoPrintReceiptSubtitle,
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
                        Text(l10n.settingsReceiptPrinter,
                            style: AppTypography.titleMd),
                        Text(
                          settings.lastPrinterAddress ??
                              l10n.settingsNoPrinterConnected,
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
          const Divider(),
          InkWell(
            onTap: () => GoRouter.of(context).push('/more/settings/receipt'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    color: context.colors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.settingsReceiptDisplay,
                            style: AppTypography.titleMd),
                        Text(
                          l10n.settingsReceiptDisplaySubtitle,
                          style: AppTypography.bodySm.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: context.colors.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          InkWell(
            onTap: () => GoRouter.of(context).push('/more/settings/menu-image'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  Icon(
                    Icons.image_outlined,
                    color: context.colors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.settingsMenuImage,
                            style: AppTypography.titleMd),
                        Text(
                          l10n.settingsMenuImageSubtitle,
                          style: AppTypography.bodySm.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: context.colors.textTertiary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── About ─────────────────────────────────────────────────────────────────────

// ── ENH-011 — Settings Backup ────────────────────────────────────────────────

class _BackupSection extends ConsumerWidget {
  const _BackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.settingsBackup),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.settingsBackupDescription,
            style: AppTypography.bodySm
                .copyWith(color: context.colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppButton(
                label: l10n.actionExport,
                icon: Icons.upload_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => _export(context, ref),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppButton(
                label: l10n.actionImport,
                icon: Icons.download_outlined,
                variant: AppButtonVariant.secondary,
                onPressed: () => _import(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    try {
      final json =
          await ref.read(settingsNotifierProvider.notifier).exportToJson();
      await Clipboard.setData(ClipboardData(text: json));
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsCopiedToClipboard)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsExportFailed(e.toString()))),
      );
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppL10n.of(context);
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final raw = data?.text?.trim();
    if (raw == null || raw.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsClipboardEmpty)),
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsImportTitle),
        content: Text(l10n.settingsImportMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionOverwrite),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final n =
          await ref.read(settingsNotifierProvider.notifier).applyFromJson(raw);
      await ref.read(localeControllerProvider.notifier).reload();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsRestoredCount(n))),
      );
    } on FormatException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.settingsImportFailed(
            _settingsImportErrorMessage(l10n, e.message),
          )),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.settingsImportFailed(e.toString()))),
      );
    }
  }

  String _settingsImportErrorMessage(AppL10n l10n, String code) =>
      switch (code) {
        kSettingsImportInvalidJson => l10n.settingsImportInvalidJson,
        kSettingsImportWrongApp => l10n.settingsImportWrongApp,
        kSettingsImportVersionMismatch =>
          l10n.settingsImportVersionMismatch(kSettingsExportVersion),
        kSettingsImportSettingsFieldInvalid =>
          l10n.settingsImportSettingsFieldInvalid,
        _ => code,
      };
}

class _AboutSection extends StatefulWidget {
  const _AboutSection();

  @override
  State<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends State<_AboutSection> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      child: FutureBuilder<PackageInfo>(
        future: _packageInfo,
        builder: (context, snapshot) {
          final packageInfo = snapshot.data;
          final appName = packageInfo?.appName ?? AppConstants.appName;
          final version = packageInfo == null
              ? l10n.statusLoadingPlain
              : '${packageInfo.version}+${packageInfo.buildNumber}';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(label: l10n.settingsAbout),
              const SizedBox(height: AppSpacing.sm),
              _SettingsNavTile(
                icon: Icons.info_outline,
                title: l10n.settingsAboutApp,
                subtitle: '$appName $version',
                route: '/more/settings/about',
              ),
            ],
          );
        },
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
  const _SignOutSection({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final user = ref.watch(currentUserProvider);
    final branchesAsync = ref.watch(allBranchesProvider);
    final selectedBranchAsync = ref.watch(selectedBranchProvider);
    final authUser = ref.watch(supabaseClientProvider).auth.currentUser;
    final loginProviders = _loginProviders(authUser?.appMetadata, l10n);
    final lastLogin = _lastLoginLabel(authUser?.lastSignInAt, l10n);
    final hasSaved =
        settings.lastLoginEmail != null && settings.lastLoginEmail!.isNotEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.settingsAccount),
          const SizedBox(height: AppSpacing.sm),
          if (user != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: const Icon(
                    Icons.person_outline,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: AppTypography.titleMd),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        user.email ??
                            authUser?.email ??
                            l10n.settingsEmailUnavailable,
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _RoleBadge(role: user.globalRole),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _AccountInfoRow(
              icon: Icons.storefront_outlined,
              label: l10n.settingsActiveBranch,
              value: selectedBranchAsync.maybeWhen(
                data: (branch) => branch?.name ?? l10n.settingsNotSelected,
                orElse: () => l10n.statusLoadingPlain,
              ),
            ),
            _AccountInfoRow(
              icon: Icons.account_tree_outlined,
              label: l10n.settingsBranchAccess,
              value: branchesAsync.maybeWhen(
                data: (branches) => l10n.settingsBranchCount(branches.length),
                orElse: () => l10n.statusLoadingPlain,
              ),
            ),
            _AccountInfoRow(
              icon: Icons.verified_user_outlined,
              label: l10n.settingsLogin,
              value: loginProviders,
            ),
            _AccountInfoRow(
              icon: Icons.history_outlined,
              label: l10n.settingsLastLogin,
              value: lastLogin,
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          SwitchListTile(
            value: settings.rememberMe,
            onChanged: (v) async {
              await ref
                  .read(settingsNotifierProvider.notifier)
                  .setRememberMe(v);
            },
            title: Text(l10n.settingsRememberLoginEmail,
                style: AppTypography.titleMd),
            subtitle: Text(
              hasSaved && settings.rememberMe
                  ? l10n.settingsSavedEmail(settings.lastLoginEmail!)
                  : l10n.settingsLoginEmailPrefill,
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          if (hasSaved) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: l10n.settingsClearSavedEmail,
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
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: l10n.actionSignOut,
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
    final l10n = AppL10n.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.settingsSignOutTitle),
        content: Text(l10n.settingsSignOutMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(l10n.actionSignOut),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authProvider.notifier).signOut();
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final GlobalRole role;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return switch (role) {
      GlobalRole.owner => AppBadge(
          label: l10n.settingsRoleOwner,
          icon: Icons.admin_panel_settings_outlined,
          tone: AppBadgeTone.warning,
        ),
      GlobalRole.manager => AppBadge(
          label: l10n.settingsRoleManager,
          icon: Icons.supervisor_account_outlined,
          tone: AppBadgeTone.info,
        ),
      GlobalRole.cashier => AppBadge(
          label: l10n.settingsRoleCashier,
          icon: Icons.point_of_sale_outlined,
          tone: AppBadgeTone.success,
        ),
    };
  }
}

class _AccountInfoRow extends StatelessWidget {
  const _AccountInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.colors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodySm.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySm,
            ),
          ),
        ],
      ),
    );
  }
}

String _loginProviders(Map<String, dynamic>? metadata, AppL10n l10n) {
  final raw = metadata?['providers'];
  final providers = raw is List
      ? raw.whereType<String>().toList()
      : <String>[
          if (metadata?['provider'] case final String provider) provider,
        ];
  if (providers.isEmpty) return l10n.statusUnknown;
  return providers.map(_providerLabel).join(' + ');
}

String _providerLabel(String provider) => switch (provider) {
      'email' => 'Email',
      'google' => 'Google',
      _ => provider,
    };

String _lastLoginLabel(String? raw, AppL10n l10n) {
  if (raw == null || raw.isEmpty) return l10n.statusUnavailable;
  final parsed = DateTime.tryParse(raw);
  return parsed == null
      ? l10n.statusUnavailable
      : formatDateTime(parsed.toLocal());
}

// ── Sync section ──────────────────────────────────────────────────────────────

class _SyncSection extends ConsumerWidget {
  const _SyncSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final pendingAsync = ref.watch(pendingOutboxCountProvider);
    final syncState = ref.watch(syncProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionHeader(label: l10n.settingsSync),
              const Spacer(),
              pendingAsync.maybeWhen(
                data: (count) => count > 0
                    ? AppBadge(
                        label: l10n.settingsWaitingCount(count),
                        icon: Icons.cloud_upload_outlined,
                        tone: AppBadgeTone.warning,
                      )
                    : AppBadge(
                        label: l10n.statusSyncCompleted,
                        icon: Icons.cloud_done_outlined,
                        tone: AppBadgeTone.success,
                      ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _Row(
            label: l10n.settingsLastSync,
            value: syncState.lastSyncAt == null
                ? l10n.statusNever
                : formatDateTime(syncState.lastSyncAt!),
          ),
          if (syncState.lastPushed > 0 ||
              syncState.lastFailed > 0 ||
              syncState.lastPulled > 0)
            _Row(
              label: l10n.settingsLastResult,
              value: l10n.settingsSyncResult(
                syncState.lastPushed,
                syncState.lastPulled,
                syncState.lastFailed,
              ),
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
                style: AppTypography.labelSm.copyWith(color: AppColors.danger),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label:
                syncState.isSyncing ? l10n.statusSyncing : l10n.settingsSyncNow,
            icon: Icons.sync,
            onPressed: syncState.isSyncing
                ? null
                : () async {
                    // Pull master for all branches the user currently has access to.
                    final branches = await ref.read(allBranchesProvider.future);
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
            label: l10n.settingsViewQueue,
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
