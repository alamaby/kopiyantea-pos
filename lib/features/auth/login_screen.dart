import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_button.dart';
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
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email dan password wajib diisi');
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
        // Router redirect will navigate away.
        break;
      case Err(:final error):
        setState(() => _error = _label(error));
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
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Masukkan email dulu');
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
            title: const Text('Cek email Anda'),
            content: Text(
              'Link masuk sudah dikirim ke $email. Buka email tersebut '
              'di perangkat ini lalu tap "Masuk ke Kopiyantea" — Anda '
              'akan otomatis masuk ke aplikasi.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      case Err(:final error):
        setState(() => _error = _label(error));
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final result = await ref.read(authProvider.notifier).signInWithGoogle();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result is Err<Unit, AuthError>) {
      setState(() => _error = _label(result.error));
    }
    // On Ok the browser is launched; session arrives via onAuthStateChange
    // and the router redirects automatically once Authenticated.
  }

  String _label(AuthError e) => switch (e) {
        AuthError.invalidCredentials => 'Email atau password salah',
        AuthError.userInactive =>
          'Akun nonaktif — hubungi pemilik untuk aktivasi',
        AuthError.userNotRegistered =>
          'Pengguna belum terdaftar di aplikasi',
        AuthError.noBranchAccess =>
          'Pengguna tidak punya akses ke cabang manapun',
        AuthError.networkUnavailable =>
          'Tidak ada koneksi ke server — coba lagi',
        AuthError.emailDispatchFailed =>
          'Gagal mengirim email — coba lagi sebentar',
        AuthError.unknown => 'Terjadi kesalahan, coba lagi',
      };

  @override
  Widget build(BuildContext context) {
    // FEAT-007 — pre-fill saved email on first build. We read settings via
    // `watch` so the field repopulates if the user toggles "Hapus sesi
    // tersimpan" elsewhere and comes back. Guarded by `_prefilled` so we
    // don't clobber a partially-typed email on rebuild.
    final settingsAsync = ref.watch(settingsNotifierProvider);
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
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.coffee,
                      size: 36,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'KopiyanteaPOS',
                    style: AppTypography.displayMd,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Masuk untuk mulai bertransaksi',
                    style: AppTypography.bodyMd.copyWith(
                      color: context.colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xxxl),

                  // Email
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isSubmitting,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Password
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    enabled: !_isSubmitting,
                    onSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
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
                            : (v) =>
                                setState(() => _rememberMe = v ?? true),
                        activeColor: AppColors.primary,
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: _isSubmitting
                              ? null
                              : () => setState(
                                  () => _rememberMe = !_rememberMe),
                          child: Text(
                            'Ingat email saya di perangkat ini',
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
                    label: 'Masuk',
                    icon: Icons.login,
                    onPressed: _isSubmitting ? null : _signIn,
                    isLoading: _isSubmitting,
                    size: AppButtonSize.primary,
                    fullWidth: true,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // Magic link
                  AppButton(
                    label: 'Masuk via Link Email',
                    icon: Icons.mark_email_read_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _isSubmitting ? null : _signInWithMagicLink,
                    fullWidth: true,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Untuk pengguna baru yang diundang Pemilik — '
                    'tanpa perlu password.',
                    style: AppTypography.labelXs.copyWith(
                      color: context.colors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: AppSpacing.md),

                  // FEAT-008 — Google OAuth
                  AppButton(
                    label: 'Lanjutkan dengan Google',
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
