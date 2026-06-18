import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/daos/dao_providers.dart';
import '../../core/database/daos/organization_dao.dart';
import '../../core/domain/enums.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_repository.dart';
import '../auth/bootstrap_provider.dart';

/// FEAT-002 Phase 7 — Join organization via invitation code.
///
/// State machine: idle → loading → error | success → bootstrap.
class JoinOrgScreen extends ConsumerStatefulWidget {
  const JoinOrgScreen({super.key});

  @override
  ConsumerState<JoinOrgScreen> createState() => _JoinOrgScreenState();
}

class _JoinOrgScreenState extends ConsumerState<JoinOrgScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final code = _codeController.text.trim().toUpperCase();
      final auth = ref.read(authProvider);
      final currentUser = switch (auth) {
        NeedsOnboarding(:final user) => user,
        _ => null,
      };

      if (currentUser == null) {
        if (mounted) {
          setState(() => _errorMessage = AppL10n.of(context).createOrgFailed);
        }
        return;
      }

      final repo = ref.read(authRepositoryProvider);
      final result = await repo.claimJoinCode(
        code: code,
        userId: currentUser.id,
      );

      if (!mounted) return;

      switch (result) {
        case Ok(:final value):
          await _onClaimSuccess(value, currentUser.id);
        case Err(:final error):
          setState(() => _errorMessage = _mapError(context, error));
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppL10n.of(context);
        setState(() => _errorMessage = '${l10n.createOrgFailed}: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _onClaimSuccess(
    ({String organizationId, String organizationName, String role}) value,
    String userId,
  ) async {
    final now = DateTime.now();

    // Persist membership locally so the UI reflects membership
    // immediately, even before bootstrap pulls full org data.
    final orgDao = ref.read(organizationDaoProvider);
    final member = OrganizationMemberRow(
      organizationId: value.organizationId,
      userId: userId,
      role: value.role,
      status: OrganizationMemberStatus.active.name,
      createdAt: now,
      updatedAt: now,
    );
    await orgDao.upsertOrganizationMember(member);

    // Transition auth state from needsOnboarding → authenticated
    await ref.read(authProvider.notifier).completeOnboarding(
          organizationId: value.organizationId,
          organizationName: value.organizationName,
        );

    // Trigger bootstrap to pull org-scoped data
    ref.read(bootstrapProvider.notifier).markPending();

    if (mounted) {
      final l10n = AppL10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.onboardingJoinSuccess)),
      );
      context.go('/bootstrap');
    }
  }

  String _mapError(BuildContext context, String error) {
    final l10n = AppL10n.of(context);
    return switch (error) {
      'not_found' => l10n.onboardingJoinErrorNotFound,
      'expired' => l10n.onboardingJoinErrorExpired,
      'already_exhausted' => l10n.onboardingJoinErrorExhausted,
      'already_member' => l10n.onboardingJoinErrorAlreadyMember,
      'network_unavailable' => l10n.onboardingJoinErrorNetwork,
      _ => l10n.onboardingJoinErrorUnknown,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.onboardingJoinOrg),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/onboarding'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            if (_errorMessage != null) ...[
              AppCard(
                variant: AppCardVariant.default_,
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            AppTextField(
              label: l10n.onboardingJoinEnterCode,
              controller: _codeController,
              hint: l10n.onboardingJoinCodeHint,
              autofocus: true,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: (_) => _submit(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.onboardingJoinCodeRequired;
                }
                if (value.trim().length != 8) {
                  return l10n.onboardingJoinCodeInvalid;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: l10n.onboardingJoinSubmit,
              onPressed: _isLoading ? null : _submit,
              isLoading: _isLoading,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
