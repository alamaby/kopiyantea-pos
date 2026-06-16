import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../l10n/generated/app_localizations.dart';

/// FEAT-002 Stage 5 - Join organization via invitation code.
/// MVP: Shows placeholder since invitation feature is not implemented yet.
class JoinOrgScreen extends StatefulWidget {
  const JoinOrgScreen({super.key});

  @override
  State<JoinOrgScreen> createState() => _JoinOrgScreenState();
}

class _JoinOrgScreenState extends State<JoinOrgScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // MVP: Show placeholder snackbar
    final l10n = AppL10n.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.onboardingJoinNotAvailable)),
    );
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
            AppTextField(
              label: l10n.onboardingJoinEnterCode,
              controller: _codeController,
              hint: l10n.onboardingJoinCodeHint,
              autofocus: true,
              textInputAction: TextInputAction.done,
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
              onPressed: _submit,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
