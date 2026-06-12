import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/domain/enums.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../core/widgets/undo_snackbar.dart';
import '../../l10n/generated/app_localizations.dart';
import 'user_providers.dart';

/// FEAT-006 — owner-only list of users + pending invitations.
class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    final usersAsync = ref.watch(allUsersProvider);
    final invitesAsync = ref.watch(pendingInvitationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.usersTitle)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_users',
        onPressed: () => context.push('/more/settings/users/new'),
        icon: const Icon(Icons.person_add_outlined),
        label: Text(l10n.usersInvite),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: l10n.usersLoadFailed,
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (users) {
          final invites = invitesAsync.maybeWhen(
            data: (list) => list,
            orElse: () => const <PendingInvitationRow>[],
          );
          if (users.isEmpty && invites.isEmpty) {
            return AppEmptyState(
              title: l10n.usersEmptyTitle,
              icon: Icons.people_outline,
              message: l10n.usersEmptyMessage,
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxxl,
            ),
            children: [
              if (invites.isNotEmpty) ...[
                Text(
                  l10n.usersPendingSection,
                  style: AppTypography.labelSm.copyWith(
                    color: context.colors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final inv in invites) ...[
                  _DismissibleInvitation(invitation: inv),
                  const SizedBox(height: AppSpacing.sm),
                ],
                const SizedBox(height: AppSpacing.lg),
              ],
              if (users.isNotEmpty) ...[
                Text(
                  l10n.usersActiveSection,
                  style: AppTypography.labelSm.copyWith(
                    color: context.colors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final u in users) ...[
                  _UserTile(user: u),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ],
          );
        },
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final AppUserRow user;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: () => context.push('/more/settings/users/${user.id}'),
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child: Text(
                  user.fullName.isEmpty ? '?' : user.fullName[0].toUpperCase(),
                  style: AppTypography.titleMd
                      .copyWith(color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.fullName, style: AppTypography.titleMd),
                    if (user.email != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        user.email!,
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AppBadge(
                label: _roleLabel(l10n, user.globalRole),
                icon: Icons.badge_outlined,
                tone: AppBadgeTone.info,
              ),
              if (!user.isActive) ...[
                const SizedBox(width: AppSpacing.xs),
                AppBadge(
                  label: l10n.statusInactive,
                  icon: Icons.block,
                  tone: AppBadgeTone.warning,
                ),
              ],
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right,
                  size: 18, color: context.colors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// FEAT-011 — wraps [_InvitationTile] in a Dismissible with confirm dialog.
/// Swipe-left fires a confirm prompt; on confirm we delete the local row
/// and enqueue a `pendingInvitation` outbox entry. The push side already
/// propagates a missing-local row as a server DELETE (see
/// `SyncRepository._pushPendingInvitation`), so no new push branch needed.
class _DismissibleInvitation extends ConsumerWidget {
  const _DismissibleInvitation({required this.invitation});
  final PendingInvitationRow invitation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppL10n.of(context);
    return Dismissible(
      key: ValueKey('invitation-${invitation.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirm(context),
      onDismissed: (_) => _cancelInvitation(context, ref),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: AppRadius.radiusLg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline, color: Colors.white),
            const SizedBox(width: AppSpacing.xs),
            Text(
              l10n.usersCancelInvite,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      child: _InvitationTile(invitation: invitation),
    );
  }

  Future<bool?> _confirm(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.warning_amber_outlined,
              size: 36, color: AppColors.warning),
          title: Text(AppL10n.of(ctx).usersCancelInviteTitle),
          content: Text(
            AppL10n.of(ctx).usersCancelInviteMessage(invitation.email),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppL10n.of(ctx).usersDoNotCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: Text(AppL10n.of(ctx).usersCancelInviteAction),
            ),
          ],
        ),
      );

  Future<void> _cancelInvitation(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(branchDaoProvider);
    final outboxDao = ref.read(outboxDaoProvider);

    final snapshot = invitation;
    final deleteOutboxId = const Uuid().v7();

    await dao.deletePendingInvitation(snapshot.id);
    await outboxDao.enqueue(OutboxItemsCompanion.insert(
      id: deleteOutboxId,
      entityType: OutboxEntityType.pendingInvitation,
      payload: jsonEncode({'id': snapshot.id, 'action': 'delete'}),
      createdAt: DateTime.now(),
    ));

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(buildUndoSnackBar(
      message: AppL10n.of(context).usersInviteCancelled(snapshot.email),
      undoLabel: AppL10n.of(context).actionUndo,
      onUndo: () => _undoCancelInvitation(ref, snapshot, deleteOutboxId),
    ));
  }

  /// Re-insert local row + compensate outbox. The push handler
  /// (`SyncRepository._pushPendingInvitation`) is symmetric: a present
  /// local row → upsert, missing → delete. So enqueueing a new outbox
  /// entry covers the race where the original DELETE already shipped to
  /// the server — Supabase row will be re-created on next sync.
  Future<void> _undoCancelInvitation(
    WidgetRef ref,
    PendingInvitationRow snap,
    String deleteOutboxId,
  ) async {
    final dao = ref.read(branchDaoProvider);
    final outboxDao = ref.read(outboxDaoProvider);

    await dao.upsertPendingInvitation(PendingInvitationsCompanion.insert(
      id: snap.id,
      email: snap.email,
      fullName: snap.fullName,
      globalRole: snap.globalRole,
      branchIdsCsv: Value(snap.branchIdsCsv),
      invitedBy: Value(snap.invitedBy),
      createdAt: snap.createdAt,
    ));

    await outboxDao.deleteById(deleteOutboxId);
    await outboxDao.enqueue(OutboxItemsCompanion.insert(
      id: const Uuid().v7(),
      entityType: OutboxEntityType.pendingInvitation,
      payload: jsonEncode({'id': snap.id}),
      createdAt: DateTime.now(),
    ));
  }
}

class _InvitationTile extends StatelessWidget {
  const _InvitationTile({required this.invitation});
  final PendingInvitationRow invitation;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentSurface,
        border: Border.all(color: context.colors.border),
        borderRadius: AppRadius.radiusLg,
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined, color: AppColors.accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invitation.fullName, style: AppTypography.titleMd),
                Text(
                  invitation.email,
                  style: AppTypography.bodySm.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AppBadge(
            label: _roleLabel(l10n, invitation.globalRole),
            icon: Icons.badge_outlined,
            tone: AppBadgeTone.info,
          ),
        ],
      ),
    );
  }
}

String _roleLabel(AppL10n l10n, GlobalRole role) => switch (role) {
      GlobalRole.owner => l10n.settingsRoleOwner,
      GlobalRole.manager => l10n.settingsRoleManager,
      GlobalRole.cashier => l10n.settingsRoleCashier,
    };
