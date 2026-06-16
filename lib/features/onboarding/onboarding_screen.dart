import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_card.dart';
import '../../l10n/generated/app_localizations.dart';

/// FEAT-002 Stage 5 - Onboarding entry screen.
/// Shown when user is signed in but has no organization yet.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl * 2),
              // Welcome header
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: AppRadius.radiusLg,
                      ),
                      child: const Icon(
                        Icons.store_outlined,
                        size: 40,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      l10n.onboardingTitle,
                      style: AppTypography.headlineLg,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  l10n.onboardingSubtitle,
                  style: AppTypography.bodyMd.copyWith(
                    color: context.colors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const Spacer(),
              // Create organization card
              AppCard(
                variant: AppCardVariant.interactive,
                onTap: () => context.go('/onboarding/create'),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: const Icon(
                        Icons.add_business_outlined,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.onboardingCreateOrg,
                            style: AppTypography.titleMd,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.onboardingCreateOrgDescription,
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
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // Join organization card
              AppCard(
                variant: AppCardVariant.interactive,
                onTap: () => context.go('/onboarding/join'),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: const Icon(
                        Icons.group_add_outlined,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.onboardingJoinOrg,
                            style: AppTypography.titleMd,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.onboardingJoinOrgDescription,
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
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
