import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/daos/dao_providers.dart';
import '../../core/database/daos/organization_dao.dart';
import '../../core/domain/enums.dart';
import '../../core/theme/spacing.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_text_field.dart';
import '../../l10n/generated/app_localizations.dart';
import '../auth/auth_provider.dart';
import '../auth/bootstrap_provider.dart';

/// FEAT-002 Stage 5 - Create organization form screen.
class CreateOrgScreen extends ConsumerStatefulWidget {
  const CreateOrgScreen({super.key});

  @override
  ConsumerState<CreateOrgScreen> createState() => _CreateOrgScreenState();
}

class _CreateOrgScreenState extends ConsumerState<CreateOrgScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  BusinessType _selectedBusinessType = BusinessType.fnb;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final auth = ref.read(authProvider);
      final currentUser = switch (auth) {
        NeedsOnboarding(:final user) => user,
        _ => null,
      };

      if (currentUser == null) {
        // Should not happen - only needsOnboarding users reach this screen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppL10n.of(context).createOrgFailed)),
          );
        }
        return;
      }

      final now = DateTime.now();
      final orgId = const Uuid().v7();

      // 1. Create organization row
      final org = OrganizationRow(
        id: orgId,
        name: _nameController.text.trim(),
        businessType: _selectedBusinessType.name,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty
            ? null
            : _addressController.text.trim(),
        ownerUserId: currentUser.id,
        defaultTimezone: 'Asia/Jakarta',
        status: 'active',
        trialEndsAt: now.add(const Duration(days: 30)),
        createdAt: now,
        updatedAt: now,
      );

      // 2. Create owner membership row
      final member = OrganizationMemberRow(
        organizationId: orgId,
        userId: currentUser.id,
        role: OrganizationMemberRole.owner.name,
        status: OrganizationMemberStatus.active.name,
        createdAt: now,
        updatedAt: now,
      );

      // 3. Persist locally
      final orgDao = ref.read(organizationDaoProvider);
      await orgDao.upsertOrganization(org);
      await orgDao.upsertOrganizationMember(member);

      // 4. Transition auth state to authenticated with the new orgId
      //    (data will be synced when bootstrap runs + periodic bg sync)
      await ref.read(authProvider.notifier).completeOnboarding(
            organizationId: orgId,
            organizationName: org.name,
          );

      // 5. Trigger bootstrap to pull org-scoped data
      ref.read(bootstrapProvider.notifier).markPending();

      if (mounted) {
        final l10n = AppL10n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.createOrgSuccess)),
        );

        // Navigate to bootstrap to pull org data
        context.go('/bootstrap');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppL10n.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.createOrgFailed}: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createOrgTitle),
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
              label: l10n.createOrgName,
              controller: _nameController,
              hint: l10n.createOrgNameHint,
              autofocus: true,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return l10n.createOrgNameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            _BusinessTypeDropdown(
              value: _selectedBusinessType,
              onChanged: (type) {
                if (type != null) {
                  setState(() => _selectedBusinessType = type);
                }
              },
              l10n: l10n,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l10n.createOrgPhone,
              controller: _phoneController,
              hint: l10n.createOrgPhoneHint,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.lg),
            AppTextField(
              label: l10n.createOrgAddress,
              controller: _addressController,
              hint: l10n.createOrgAddressHint,
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: l10n.createOrgSubmit,
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

/// Business type dropdown widget.
class _BusinessTypeDropdown extends StatelessWidget {
  const _BusinessTypeDropdown({
    required this.value,
    required this.onChanged,
    required this.l10n,
  });

  final BusinessType value;
  final ValueChanged<BusinessType?> onChanged;
  final AppL10n l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            l10n.createOrgBusinessType,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
        DropdownButtonFormField<BusinessType>(
          initialValue: value,
          decoration: const InputDecoration(),
          items: [
            DropdownMenuItem(
              value: BusinessType.fnb,
              child: Text(l10n.createOrgBusinessTypeFnb),
            ),
            DropdownMenuItem(
              value: BusinessType.retail,
              child: Text(l10n.createOrgBusinessTypeRetail),
            ),
            DropdownMenuItem(
              value: BusinessType.service,
              child: Text(l10n.createOrgBusinessTypeService),
            ),
            DropdownMenuItem(
              value: BusinessType.generic,
              child: Text(l10n.createOrgBusinessTypeGeneric),
            ),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
