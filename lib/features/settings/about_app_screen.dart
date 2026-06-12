import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/config/app_constants.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_card.dart';
import '../../l10n/generated/app_localizations.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppL10n.of(context).settingsAboutApp)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _ApplicationInfoCard(),
          const SizedBox(height: AppSpacing.lg),
          _CreatorCard(),
          const SizedBox(height: AppSpacing.lg),
          _CreatorLinksCard(),
        ],
      ),
    );
  }
}

class _ApplicationInfoCard extends StatefulWidget {
  const _ApplicationInfoCard();

  @override
  State<_ApplicationInfoCard> createState() => _ApplicationInfoCardState();
}

class _ApplicationInfoCardState extends State<_ApplicationInfoCard> {
  late final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: FutureBuilder<PackageInfo>(
        future: _packageInfo,
        builder: (context, snapshot) {
          final packageInfo = snapshot.data;
          final l10n = AppL10n.of(context);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeader(label: l10n.aboutAppSection),
              const SizedBox(height: AppSpacing.sm),
              _InfoRow(
                label: l10n.aboutAppName,
                value: packageInfo?.appName ?? AppConstants.appName,
              ),
              _InfoRow(
                label: l10n.aboutVersion,
                value: packageInfo?.version ?? l10n.statusLoadingPlain,
              ),
              _InfoRow(
                label: l10n.aboutBuildNumber,
                value: packageInfo?.buildNumber ?? l10n.statusLoadingPlain,
              ),
              _InfoRow(
                label: l10n.aboutLicense,
                value: AppConstants.appLicense,
              ),
              const Divider(height: AppSpacing.xl),
              _LinkRow(
                icon: Icons.privacy_tip_outlined,
                label: l10n.aboutPrivacyPolicy,
                url: AppLinks.privacyPolicy,
              ),
              _LinkRow(
                icon: Icons.description_outlined,
                label: l10n.aboutTermsOfService,
                url: AppLinks.termsOfService,
              ),
              _LinkRow(
                icon: Icons.feedback_outlined,
                label: l10n.aboutSubmitFeedback,
                url: AppLinks.submitFeedback,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.aboutCreatorSection),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: l10n.aboutCreatorName,
            value: AppConstants.creatorName,
          ),
        ],
      ),
    );
  }
}

class _CreatorLinksCard extends StatelessWidget {
  const _CreatorLinksCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: l10n.aboutLinksSection),
          const SizedBox(height: AppSpacing.sm),
          _LinkRow(
            icon: Icons.business_center_outlined,
            label: l10n.aboutLinkedIn,
            url: AppLinks.linkedin,
          ),
          _LinkRow(
            icon: Icons.code_outlined,
            label: l10n.aboutGithub,
            url: AppLinks.github,
          ),
          _LinkRow(
            icon: Icons.article_outlined,
            label: l10n.aboutBlog,
            url: AppLinks.blog,
          ),
          _LinkRow(
            icon: Icons.work_outline,
            label: l10n.aboutUpwork,
            url: AppLinks.upwork,
          ),
          _LinkRow(
            icon: Icons.coffee_outlined,
            label: l10n.aboutBuyMeACoffee,
            url: AppLinks.buyMeACoffee,
          ),
          _LinkRow(
            icon: Icons.volunteer_activism_outlined,
            label: l10n.aboutSaweria,
            url: AppLinks.saweria,
          ),
          _LinkRow(
            icon: Icons.favorite_border,
            label: l10n.aboutTrakteer,
            url: AppLinks.trakteer,
          ),
          _LinkRow(
            icon: Icons.workspace_premium_outlined,
            label: l10n.aboutPatreon,
            url: AppLinks.patreon,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyMd.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: AppTypography.bodyMd,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.url,
  });

  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.textSecondary, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.titleMd),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  url,
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: AppTypography.labelSm.copyWith(
        color: context.colors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}
