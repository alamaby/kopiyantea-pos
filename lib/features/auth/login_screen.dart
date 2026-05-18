import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_button.dart';
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
        // Router redirect will navigate away.
        break;
      case Err(:final error):
        setState(() => _error = _label(error));
    }
  }

  Future<void> _signInDemo() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final auth = ref.read(authProvider.notifier);
    final result = await auth.signInAsDemo();
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (result is Err<Unit, AuthError>) {
      setState(() => _error = _label(result.error));
    }
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
        AuthError.unknown => 'Terjadi kesalahan, coba lagi',
      };

  @override
  Widget build(BuildContext context) {
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

                  const SizedBox(height: AppSpacing.lg),
                  Row(
                    children: [
                      Expanded(child: Divider(color: context.colors.border)),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                        ),
                        child: Text(
                          'atau',
                          style: AppTypography.labelSm.copyWith(
                            color: context.colors.textTertiary,
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: context.colors.border)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Demo
                  AppButton(
                    label: 'Masuk sebagai Demo Kasir',
                    icon: Icons.flash_on_outlined,
                    variant: AppButtonVariant.secondary,
                    onPressed: _isSubmitting ? null : _signInDemo,
                    fullWidth: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Mode offline — tanpa Supabase. Transaksi tidak akan tersinkron.',
                    style: AppTypography.labelXs.copyWith(
                      color: context.colors.textTertiary,
                    ),
                    textAlign: TextAlign.center,
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
