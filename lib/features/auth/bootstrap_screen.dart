import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_button.dart';
import 'auth_provider.dart';
import 'bootstrap_provider.dart';

/// Shown after a successful sign-in while the master + history pull runs.
/// Blocking — user can't proceed until done, retry, or sign out.
class BootstrapScreen extends ConsumerStatefulWidget {
  const BootstrapScreen({super.key});

  @override
  ConsumerState<BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends ConsumerState<BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    // Kick off the pull on first build. Guard against the user landing here
    // via a stale route (state already complete) by checking state inside.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeRun());
  }

  void _maybeRun() {
    final state = ref.read(bootstrapProvider);
    if (state is BootstrapPending) {
      ref.read(bootstrapProvider.notifier).run();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bootstrapProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Brand(),
                  const SizedBox(height: AppSpacing.xxxl),
                  if (user != null) ...[
                    Text(
                      'Halo, ${user.fullName}',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineMd,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                  ],
                  switch (state) {
                    BootstrapComplete() ||
                    BootstrapPending() =>
                      _LoadingBlock(
                        step: 'Menyiapkan…',
                      ),
                    BootstrapRunning(:final step) => _LoadingBlock(step: step),
                    BootstrapFailed(:final error) => _ErrorBlock(error: error),
                  },
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
        const SizedBox(height: AppSpacing.md),
        Text('KopiyanteaPOS', style: AppTypography.displayMd),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({required this.step});
  final String step;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(
          width: 40,
          height: 40,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          step,
          textAlign: TextAlign.center,
          style: AppTypography.bodyMd
              .copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Mengambil data terbaru dari server. Jangan tutup aplikasi.',
          textAlign: TextAlign.center,
          style: AppTypography.labelSm
              .copyWith(color: context.colors.textTertiary),
        ),
      ],
    );
  }
}

class _ErrorBlock extends ConsumerWidget {
  const _ErrorBlock({required this.error});
  final String error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 56,
          color: AppColors.danger,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Gagal Memuat Data',
          textAlign: TextAlign.center,
          style: AppTypography.headlineMd,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          error,
          textAlign: TextAlign.center,
          style: AppTypography.bodySm
              .copyWith(color: context.colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: 'Coba Lagi',
          icon: Icons.refresh,
          onPressed: () {
            ref.read(bootstrapProvider.notifier).markPending();
            ref.read(bootstrapProvider.notifier).run();
          },
          fullWidth: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          label: 'Keluar',
          icon: Icons.logout,
          variant: AppButtonVariant.secondary,
          onPressed: () async {
            await ref.read(authProvider.notifier).signOut();
            ref.read(bootstrapProvider.notifier).reset();
          },
          fullWidth: true,
        ),
      ],
    );
  }
}
