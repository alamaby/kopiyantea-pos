import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/domain/enums.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../auth/auth_provider.dart';
import '../settings/branch_selection_provider.dart';
import 'user_providers.dart';

/// FEAT-006 — invite a new user (no [userId]) OR edit existing user.
///
/// New-user flow (invite-only, client-safe — no service_role needed):
///   1. Owner fills name + email + role + checks branches
///   2. App writes `pending_invitations` row + outbox push
///   3. Owner shares the email instruction with invitee out-of-band
///   4. Invitee signs up to Supabase auth using that email
///   5. AuthRepository on first sign-in matches email → creates
///      `app_users` row with auth.uid + role, fans out
///      `user_branch_access` rows, deletes the invitation
///
/// Edit flow: name, role, isActive + branch access list are mutable.
/// Email stays immutable (would break the auth.uid ⇄ app_users link).
class UserFormScreen extends ConsumerStatefulWidget {
  const UserFormScreen({this.userId, super.key});
  final String? userId;

  @override
  ConsumerState<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends ConsumerState<UserFormScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  GlobalRole _role = GlobalRole.cashier;
  bool _isActive = true;
  final Set<String> _selectedBranchIds = {};

  AppUserRow? _existing;
  bool _loading = false;
  bool _saving = false;
  String? _errorName;
  String? _errorEmail;

  bool get _isEditing => widget.userId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dao = ref.read(branchDaoProvider);
    final user = await dao.getUserById(widget.userId!);
    final access = user == null
        ? <UserBranchAccessRow>[]
        : await dao.getAccessForUser(user.id);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _existing = user;
      if (user != null) {
        _nameCtrl.text = user.fullName;
        _emailCtrl.text = user.email ?? '';
        _role = user.globalRole;
        _isActive = user.isActive;
        _selectedBranchIds
          ..clear()
          ..addAll(access.map((a) => a.branchId));
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errorName = null;
      _errorEmail = null;
    });
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    if (name.isEmpty) {
      setState(() {
        _saving = false;
        _errorName = 'Nama wajib diisi';
      });
      return;
    }
    if (!_isEditing && !_isLikelyEmail(email)) {
      setState(() {
        _saving = false;
        _errorEmail = 'Email tidak valid';
      });
      return;
    }

    final dao = ref.read(branchDaoProvider);
    final outboxDao = ref.read(outboxDaoProvider);
    final now = DateTime.now();
    final inviter = ref.read(currentUserProvider)?.id;

    if (_existing == null) {
      // Invite — write pending_invitations + outbox push.
      // Duplicate-email guard: if a user already exists with this email,
      // skip the invitation (the existing user just needs branch access).
      final dupUser = await dao.getUserByEmail(email);
      if (dupUser != null) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _errorEmail = 'Email sudah dipakai pengguna lain';
        });
        return;
      }
      final dupInvite = await dao.getPendingInvitationByEmail(email);
      if (dupInvite != null) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _errorEmail = 'Undangan untuk email ini sudah ada';
        });
        return;
      }
      final invitationId = const Uuid().v7();
      await dao.upsertPendingInvitation(PendingInvitationsCompanion.insert(
        id: invitationId,
        email: email,
        fullName: name,
        globalRole: _role,
        branchIdsCsv: Value(_selectedBranchIds.join(',')),
        invitedBy: Value(inviter),
        createdAt: now,
      ));
      await outboxDao.enqueue(OutboxItemsCompanion.insert(
        id: const Uuid().v7(),
        entityType: OutboxEntityType.pendingInvitation,
        payload: jsonEncode({'id': invitationId}),
        createdAt: now,
      ));
    } else {
      // Edit existing user.
      await dao.updateUserById(
        _existing!.id,
        AppUsersCompanion(
          fullName: Value(name),
          globalRole: Value(_role),
          isActive: Value(_isActive),
          updatedAt: Value(now),
        ),
      );
      await outboxDao.enqueue(OutboxItemsCompanion.insert(
        id: const Uuid().v7(),
        entityType: OutboxEntityType.appUser,
        payload: jsonEncode({'id': _existing!.id}),
        createdAt: now,
      ));

      // Diff branch access: insert new selections, remove deselected.
      final current = await dao.getAccessForUser(_existing!.id);
      final currentIds = current.map((a) => a.branchId).toSet();
      final desired = _selectedBranchIds;
      for (final addId in desired.difference(currentIds)) {
        await dao.upsertUserBranchAccess(UserBranchAccessesCompanion.insert(
          userId: _existing!.id,
          branchId: addId,
          roleAtBranch: Value(_branchRoleFor(_role)),
        ));
        await outboxDao.enqueue(OutboxItemsCompanion.insert(
          id: const Uuid().v7(),
          entityType: OutboxEntityType.userBranchAccess,
          payload: jsonEncode({
            'user_id': _existing!.id,
            'branch_id': addId,
            'action': 'upsert',
          }),
          createdAt: now,
        ));
      }
      for (final removeId in currentIds.difference(desired)) {
        await dao.deleteAccess(userId: _existing!.id, branchId: removeId);
        await outboxDao.enqueue(OutboxItemsCompanion.insert(
          id: const Uuid().v7(),
          entityType: OutboxEntityType.userBranchAccess,
          payload: jsonEncode({
            'user_id': _existing!.id,
            'branch_id': removeId,
            'action': 'delete',
          }),
          createdAt: now,
        ));
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  BranchRole? _branchRoleFor(GlobalRole role) => switch (role) {
        GlobalRole.owner => null, // owner has all branches; role left null
        GlobalRole.manager => BranchRole.manager,
        GlobalRole.cashier => BranchRole.cashier,
      };

  static bool _isLikelyEmail(String v) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v);

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Memuat…')),
        body: const Center(child: AppLoadingIndicator()),
      );
    }
    if (_isEditing && _existing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pengguna')),
        body: const AppEmptyState(
          title: 'Pengguna tidak ditemukan',
          icon: Icons.search_off_outlined,
        ),
      );
    }
    final branchesAsync = ref.watch(allBranchesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Ubah Pengguna' : 'Undang Pengguna'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _LabeledField(
            label: 'Nama lengkap',
            required: true,
            child: TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                hintText: 'mis. Budi Setiawan',
                errorText: _errorName,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _LabeledField(
            label: 'Email',
            required: !_isEditing,
            child: TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              enabled: !_isEditing,
              decoration: InputDecoration(
                hintText: 'email@contoh.com',
                errorText: _errorEmail,
                helperText: _isEditing
                    ? 'Email tidak dapat diubah'
                    : null,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Peran',
              style: AppTypography.labelSm
                  .copyWith(color: context.colors.textSecondary)),
          const SizedBox(height: AppSpacing.xs),
          SegmentedButton<GlobalRole>(
            segments: const [
              ButtonSegment(value: GlobalRole.owner, label: Text('Pemilik')),
              ButtonSegment(value: GlobalRole.manager, label: Text('Manajer')),
              ButtonSegment(value: GlobalRole.cashier, label: Text('Kasir')),
            ],
            selected: {_role},
            onSelectionChanged: (s) => setState(() => _role = s.first),
          ),
          if (_isEditing) ...[
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title:
                  Text('Pengguna aktif', style: AppTypography.titleMd),
              subtitle: Text(
                _isActive
                    ? 'Bisa login dan akses cabang'
                    : 'Tidak bisa login (akses dicabut)',
                style: AppTypography.bodySm
                    .copyWith(color: context.colors.textSecondary),
              ),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('AKSES CABANG',
                    style: AppTypography.labelSm.copyWith(
                      color: context.colors.textSecondary,
                      letterSpacing: 0.8,
                    )),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _role == GlobalRole.owner
                      ? 'Pemilik otomatis akses semua cabang. Pilihan di sini diabaikan.'
                      : 'Pilih cabang yang boleh diakses pengguna.',
                  style: AppTypography.bodySm
                      .copyWith(color: context.colors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.sm),
                branchesAsync.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(AppSpacing.md),
                    child: AppLoadingIndicator(),
                  ),
                  error: (e, _) => Text('Gagal: $e'),
                  data: (branches) => Column(
                    children: [
                      for (final b in branches)
                        CheckboxListTile(
                          value: _selectedBranchIds.contains(b.id),
                          onChanged: _role == GlobalRole.owner
                              ? null
                              : (v) {
                                  setState(() {
                                    if (v == true) {
                                      _selectedBranchIds.add(b.id);
                                    } else {
                                      _selectedBranchIds.remove(b.id);
                                    }
                                  });
                                },
                          title:
                              Text(b.name, style: AppTypography.titleMd),
                          subtitle: b.address == null
                              ? null
                              : Text(
                                  b.address!,
                                  style: AppTypography.bodySm.copyWith(
                                    color: context.colors.textSecondary,
                                  ),
                                ),
                          contentPadding: EdgeInsets.zero,
                          activeColor: AppColors.primary,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: _saving
                ? 'Menyimpan…'
                : _isEditing
                    ? 'Simpan Perubahan'
                    : 'Kirim Undangan',
            icon:
                _isEditing ? Icons.save_outlined : Icons.send_outlined,
            onPressed: _saving ? null : _save,
            isLoading: _saving,
            fullWidth: true,
          ),
          if (!_isEditing) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Bagikan email ini ke pengguna. Setelah mereka daftar di Supabase '
              'dengan email tersebut dan login ke aplikasi, akses akan otomatis '
              'aktif.',
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.child,
    this.required = false,
  });
  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: RichText(
            text: TextSpan(
              text: label,
              style: AppTypography.labelSm
                  .copyWith(color: context.colors.textSecondary),
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.danger),
                  ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}
