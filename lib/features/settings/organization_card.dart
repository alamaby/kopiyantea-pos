import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/dao_providers.dart';
import '../../core/database/daos/organization_dao.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_card.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_provider.dart';

/// FEAT-002 Stage 5 — Card shown in Settings displaying the current org info.
/// Tapping opens the OrganizationSwitcherBottomSheet.
class OrganizationCard extends ConsumerWidget {
  const OrganizationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final orgAsync = ref.watch(currentOrganizationProvider);
    final orgId = ref.watch(currentOrganizationIdProvider);

    return AppCard(
      variant: AppCardVariant.interactive,
      onTap: () => _openSwitcher(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.settingsCurrentOrganization.toUpperCase(),
                  style: AppTypography.labelSm.copyWith(
                    color: context.colors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: context.colors.textTertiary,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          orgAsync.when(
            loading: () => Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.statusLoadingPlain,
                    style: AppTypography.bodyMd.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            error: (_, __) => Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: const Icon(
                    Icons.error_outline,
                    color: AppColors.danger,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    l10n.settingsNoOrganization,
                    style: AppTypography.bodyMd.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            data: (org) {
              if (org == null) {
                return Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: const Icon(
                        Icons.store_outlined,
                        color: AppColors.primaryDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        l10n.settingsNoOrganization,
                        style: AppTypography.bodyMd.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ),
                    AppBadge(
                      label: l10n.settingsRoleOwner,
                      tone: AppBadgeTone.warning,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: AppRadius.radiusMd,
                    ),
                    child: const Icon(
                      Icons.store_outlined,
                      color: AppColors.primaryDark,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          org.name,
                          style: AppTypography.titleMd,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (org.businessType.isNotEmpty &&
                            org.businessType != 'generic') ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            org.businessType.toUpperCase(),
                            style: AppTypography.labelSm.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _SubscriptionTierBadge(orgId: orgId, l10n: l10n),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _openSwitcher(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const OrganizationSwitcherBottomSheet(),
    );
  }
}

/// Badge showing the subscription tier (Free / Plus / Trial).
class _SubscriptionTierBadge extends ConsumerWidget {
  const _SubscriptionTierBadge({required this.orgId, required this.l10n});

  final String? orgId;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (orgId == null) return const SizedBox.shrink();

    // Pull subscription asynchronously
    final subscriptionAsync = ref.watch(
      FutureProvider<OrganizationSubscriptionRow?>(
        (ref) async {
          final dao = ref.read(organizationDaoProvider);
          return dao.getOrganizationSubscription(orgId!);
        },
      ),
    );

    return subscriptionAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => AppBadge(
        label: l10n.settingsOrganizationTierFree,
        tone: AppBadgeTone.neutral,
      ),
      data: (sub) {
        if (sub == null) {
          return AppBadge(
            label: l10n.settingsOrganizationTierFree,
            tone: AppBadgeTone.neutral,
          );
        }

        final tone = switch (sub.planCode) {
          'free' => AppBadgeTone.neutral,
          'plus' => AppBadgeTone.info,
          _ => AppBadgeTone.neutral,
        };

        final label = switch (sub.status) {
          'trialing' => l10n.settingsOrganizationTierTrial,
          'active' => sub.planCode == 'plus'
              ? l10n.settingsOrganizationTierPlus
              : l10n.settingsOrganizationTierFree,
          _ => l10n.settingsOrganizationTierFree,
        };

        return AppBadge(
          label: label,
          tone: tone,
        );
      },
    );
  }
}

/// FEAT-002 Stage 5 — Bottom sheet listing all orgs the user belongs to,
/// with the option to create a new one.
class OrganizationSwitcherBottomSheet extends ConsumerWidget {
  const OrganizationSwitcherBottomSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final currentUser = ref.watch(currentUserProvider);
    final currentOrgId = ref.watch(currentOrganizationIdProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Title
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Text(
                      l10n.settingsSwitchOrganization,
                      style: AppTypography.titleLg,
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Organization list
              Expanded(
                child: currentUser == null
                    ? Center(child: Text(l10n.statusLoadingPlain))
                    : _OrganizationList(
                        userId: currentUser.id,
                        currentOrgId: currentOrgId,
                        scrollController: scrollController,
                        l10n: l10n,
                      ),
              ),
              // Create new org button
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // Navigate to create org screen
                      GoRouter.of(context).go('/onboarding/create');
                    },
                    icon: const Icon(Icons.add),
                    label: Text(l10n.settingsCreateNewOrganization),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Inner list widget that loads organizations.
class _OrganizationList extends ConsumerWidget {
  const _OrganizationList({
    required this.userId,
    required this.currentOrgId,
    required this.scrollController,
    required this.l10n,
  });

  final String userId;
  final String? currentOrgId;
  final ScrollController scrollController;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orgsAsync = ref.watch(
      FutureProvider<List<OrganizationRow>>(
        (ref) async {
          final dao = ref.read(organizationDaoProvider);
          return dao.getOrganizationsForUser(userId);
        },
      ),
    );

    return orgsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            l10n.errorUnknown,
            style: TextStyle(color: AppColors.danger),
          ),
        ),
      ),
      data: (orgs) {
        if (orgs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.settingsNoOrganization,
                style: AppTypography.bodyMd.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          );
        }

        return ListView.builder(
          controller: scrollController,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: orgs.length,
          itemBuilder: (context, index) {
            final org = orgs[index];
            final isSelected = org.id == currentOrgId;

            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.primarySurface,
                  borderRadius: AppRadius.radiusMd,
                ),
                child: Icon(
                  Icons.store_outlined,
                  color: isSelected ? Colors.white : AppColors.primaryDark,
                  size: 20,
                ),
              ),
              title: Text(
                org.name,
                style: AppTypography.titleMd.copyWith(
                  color: isSelected ? AppColors.primary : null,
                ),
              ),
              subtitle: org.businessType.isNotEmpty &&
                      org.businessType != 'generic'
                  ? Text(
                      org.businessType,
                      style: AppTypography.bodySm.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    )
                  : null,
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () {
                // MVP: Show not-available snackbar
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(l10n.settingsOrganizationSwitchNotAvailable),
                  ),
                );
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }
}