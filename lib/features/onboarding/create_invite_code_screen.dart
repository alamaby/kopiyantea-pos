import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database_provider.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/daos/organization_dao.dart';
import '../../core/database/app_database.dart';
import '../../core/domain/enums.dart' as enums;
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_text_field.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_repository.dart';
import '../settings/branch_selection_provider.dart';

/// FEAT-002 Phase 7 — Owner/Admin generates an open invitation code.
///
/// Form: role (cashier/manager), branch access (multi-select),
/// max uses (1-50), expiry (date picker, default +7d).
/// On submit a random 8-char code is created on Supabase and displayed
/// with a copy-to-clipboard affordance.
class CreateInviteCodeScreen extends ConsumerStatefulWidget {
  const CreateInviteCodeScreen({super.key});

  @override
  ConsumerState<CreateInviteCodeScreen> createState() =>
      _CreateInviteCodeScreenState();
}

class _CreateInviteCodeScreenState
    extends ConsumerState<CreateInviteCodeScreen> {
  final _formKey = GlobalKey<FormState>();

  enums.GlobalRole _selectedRole = enums.GlobalRole.cashier;
  final Set<String> _selectedBranchIds = {};
  int _maxUses = 1;
  DateTime _expiresAt = DateTime.now().add(const Duration(days: 7));

  bool _isLoading = false;
  String? _generatedCode;
  String? _errorMessage;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedBranchIds.isEmpty) {
      setState(() => _errorMessage = 'Pilih minimal satu cabang');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _generatedCode = null;
    });

    try {
      final orgId = ref.read(currentOrganizationIdProvider);
      final user = ref.read(currentUserProvider);
      if (orgId == null || user == null) {
        setState(() => _errorMessage = 'Tidak ada organisasi aktif');
        return;
      }

      final repo = ref.read(authRepositoryProvider);
      final result = await repo.generateJoinCode(
        organizationId: orgId,
        role: _selectedRole.name,
        branchIdsCsv: _selectedBranchIds.toList().join(','),
        maxUses: _maxUses,
        expiresAt: _expiresAt,
        invitedBy: user.id,
      );

      if (!mounted) return;

      switch (result) {
        case Ok(:final value):
          setState(() => _generatedCode = value);
        case Err(:final error):
          setState(() => _errorMessage = _mapError(error));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Gagal membuat kode: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _mapError(String error) => switch (error) {
        'network_unavailable' => 'Gagal terhubung ke server',
        'insert_failed' => 'Gagal menyimpan kode ke server',
        _ => 'Terjadi kesalahan',
      };

  Future<void> _copyToClipboard() async {
    if (_generatedCode == null) return;
    await Clipboard.setData(ClipboardData(text: _generatedCode!));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppL10n.of(context).createInviteCodeCopied),
        ),
      );
    }
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiresAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final branchesAsync = ref.watch(allBranchesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createInviteCodeTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _generatedCode != null
          ? _buildSuccessState(context)
          : _buildFormState(context, branchesAsync, l10n),
    );
  }

  Widget _buildFormState(
    BuildContext context,
    AsyncValue<List<BranchRow>> branchesAsync,
    AppL10n l10n,
  ) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (_errorMessage != null) ...[
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          // Role
          Text(
            l10n.createInviteCodeRoleLabel,
            style: AppTypography.labelSm.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<enums.GlobalRole>(
            segments: [
              ButtonSegment(
                value: enums.GlobalRole.manager,
                label: Text(l10n.settingsRoleManager),
              ),
              ButtonSegment(
                value: enums.GlobalRole.cashier,
                label: Text(l10n.settingsRoleCashier),
              ),
            ],
            selected: {_selectedRole},
            onSelectionChanged: (set) {
              if (set.isNotEmpty) {
                setState(() => _selectedRole = set.first);
              }
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          // Branches
          Text(
            l10n.createInviteCodeBranchLabel,
            style: AppTypography.labelSm.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          branchesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('${l10n.createInviteCodeBranchError}: $e'),
            data: (branches) {
              if (branches.isEmpty) {
                return Text(l10n.createInviteCodeNoBranch);
              }
              return Column(
                children: branches.map((b) {
                  final selected = _selectedBranchIds.contains(b.id);
                  return CheckboxListTile(
                    value: selected,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selectedBranchIds.add(b.id);
                        } else {
                          _selectedBranchIds.remove(b.id);
                        }
                      });
                    },
                    title: Text(b.name),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          // Max uses
          Text(
            '${l10n.createInviteCodeMaxUsesLabel}: $_maxUses',
            style: AppTypography.labelSm.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Slider(
            value: _maxUses.toDouble(),
            min: 1,
            max: 50,
            divisions: 49,
            label: '$_maxUses',
            onChanged: (v) => setState(() => _maxUses = v.round()),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Expiry
          Text(
            l10n.createInviteCodeExpiresLabel,
            style: AppTypography.labelSm.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton.icon(
            onPressed: _pickExpiry,
            icon: const Icon(Icons.calendar_today),
            label: Text(
              '${_expiresAt.day.toString().padLeft(2, '0')}/${_expiresAt.month.toString().padLeft(2, '0')}/${_expiresAt.year}',
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: l10n.createInviteCodeSubmit,
            onPressed: _isLoading ? null : _submit,
            isLoading: _isLoading,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.createInviteCodeSuccessTitle,
              style: AppTypography.headlineLg,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.createInviteCodeSuccessDesc,
              style: AppTypography.bodyMd.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              variant: AppCardVariant.raised,
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _generatedCode!,
                      style: AppTypography.displayLg.copyWith(
                        letterSpacing: 4,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _copyToClipboard,
                    icon: const Icon(Icons.copy),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Selesai',
              onPressed: () => Navigator.of(context).pop(),
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}
