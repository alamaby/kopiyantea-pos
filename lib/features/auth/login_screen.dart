import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_button.dart';
import '../../l10n/generated/app_localizations.dart';
import '../settings/settings_provider.dart';
import 'auth_provider.dart';
import 'auth_repository.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSubmitting = false;
  bool _obscure = true;
  bool _rememberMe = true;
  bool _prefilled = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final l10n = AppL10n.of(context);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = l10n.authEmailPasswordRequired);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    final result = await auth.signIn(email: email, password: password);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    switch (result) {
      case Ok():
        await _persistRemember(email);
        TextInput.finishAutofillContext();
        // Router redirect will navigate away.
        break;
      case Err(:final error):
        setState(() => _error = _label(l10n, error));
    }
  }

  /// FEAT-007 — persist (or clear) the last login email based on the
  /// checkbox state. Saved on success only.
  Future<void> _persistRemember(String email) async {
    final settings = ref.read(settingsNotifierProvider.notifier);
    await settings.setRememberMe(_rememberMe);
    if (_rememberMe) {
      await settings.setLastLoginEmail(email);
    } else {
      await settings.setLastLoginEmail(null);
    }
  }

  Future<void> _signInWithMagicLink() async {
    final l10n = AppL10n.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = l10n.authEmailRequired);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final result =
        await ref.read(authProvider.notifier).signInWithMagicLink(email);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    switch (result) {
      case Ok():
        await _persistRemember(email);
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.mark_email_read_outlined,
                size: 48, color: AppColors.primary),
            title: Text(l10n.authCheckEmailTitle),
            content: Text(l10n.authCheckEmailMessage(email)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(l10n.actionOk),
              ),
            ],
          ),
        );
      case Err(:final error):
        setState(() => _error = _label(l10n, error));
    }
  }

  Future<void> _signInWithGoogle() async {
    final l10n = AppL10n.of(context);
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final result = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result is Err<Unit, AuthError>) {
      setState(() => _error = _label(l10n, result.error));
    }
    // On Ok the browser is launched; session arrives via onAuthStateChange
    // and the router redirects automatically once Authenticated.
  }

  String _label(AppL10n l10n, AuthError e) => switch (e) {
        AuthError.invalidCredentials => l10n.authInvalidCredentials,
        AuthError.userInactive => l10n.authUserInactive,
        AuthError.userNotRegistered => l10n.authUserNotRegistered,
        AuthError.noBranchAccess => l10n.authNoBranchAccess,
        AuthError.networkUnavailable => l10n.authNetworkUnavailable,
        AuthError.emailDispatchFailed => l10n.authEmailDispatchFailed,
        AuthError.unknown => l10n.authUnknownError,
      };

  @override
  Widget build(BuildContext context) {
    // FEAT-007 — pre-fill saved email on first build. We read settings via
    // `watch` so the field repopulates if the user toggles "Hapus sesi
    // tersimpan" elsewhere and comes back. Guarded by `_prefilled` so we
    // don't clobber a partially-typed email on rebuild.
    final settingsAsync = ref.watch(settingsNotifierProvider);
    final l10n = AppL10n.of(context);
    settingsAsync.whenData((s) {
      if (!_prefilled) {
        _prefilled = true;
        _rememberMe = s.rememberMe;
        final saved = s.lastLoginEmail;
        if (saved != null && saved.isNotEmpty && _emailCtrl.text.isEmpty) {
          _emailCtrl.text = saved;
        }
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Brand
                  Image.asset(
                    Theme.of(context).brightness == Brightness.dark
                        ? 'assets/images/logo_kopiyantea_dark.png'
                        : 'assets/images/logo_kopiyantea_light.png',
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.authLoginSubtitle,
                    style: AppTypography.bodyMd.copyWith(
                      color: context.colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  AutofillGroup(
                    child: Column(
                      children: [
                        // Email
                        TextField(
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          enabled: !_isSubmitting,
                          decoration: InputDecoration(
                            labelText: l10n.authEmail,
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        // Password
                        TextField(
                          controller: _passwordCtrl,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          enableSuggestions: false,
                          autocorrect: false,
                          enabled: !_isSubmitting,
                          onSubmitted: (_) => _signIn(),
                          decoration: InputDecoration(
                            labelText: l10n.authPassword,
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () =>
                                  setState(() => _obscure = !_obscure),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // FEAT-007 — Remember me
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: _isSubmitting
                            ? null
                            : (v) => setState(() => _rememberMe = v ?? true),
                        activeColor: AppColors.primary,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSubmitting
                              ? null
                              : () =>
                                  setState(() => _rememberMe = !_rememberMe),
                          child: Text(
                            l10n.authRememberEmail,
                            style: AppTypography.bodySm,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: AppColors.danger, size: 18),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: AppTypography.bodySm
                                  .copyWith(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xl),

                  // Sign in
                  AppButton(
                    label: l10n.authSignIn,
                    icon: Icons.login,
                    onPressed: _isSubmitting ? null : _signIn,
                    isLoading: _isSubmitting,
                    size: AppButtonSize.primary,
                    fullWidth: true,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Magic link
                  AppButton(
                    label: l10n.authMagicLinkSignIn,
                    icon: Icons.mark_email_read_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _isSubmitting ? null : _signInWithMagicLink,
                    fullWidth: true,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.authMagicLinkHelp,
                    style: AppTypography.labelXs.copyWith(
                      color: context.colors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // FEAT-008 — Google OAuth
                  AppButton(
                    label: l10n.authContinueWithGoogle,
                    icon: Icons.account_circle_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _isSubmitting ? null : _signInWithGoogle,
                    fullWidth: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
