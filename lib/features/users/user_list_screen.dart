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
import 'user_providers.dart';

/// FEAT-006 — owner-only list of users + pending invitations.
class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(allUsersProvider);
    final invitesAsync = ref.watch(pendingInvitationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengguna')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_users',
        onPressed: () => context.push('/more/settings/users/new'),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Undang'),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat pengguna',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (users) {
          final invites = invitesAsync.maybeWhen(
            data: (list) => list,
            orElse: () => const <PendingInvitationRow>[],
          );
          if (users.isEmpty && invites.isEmpty) {
            return const AppEmptyState(
              title: 'Belum ada pengguna',
              icon: Icons.people_outline,
              message: 'Tap "Undang" untuk menambah kasir atau manajer.',
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
                  'MENUNGGU BERGABUNG',
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
                  'PENGGUNA AKTIF',
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
                label: _roleLabel(user.globalRole.name),
                icon: Icons.badge_outlined,
                tone: AppBadgeTone.info,
              ),
              if (!user.isActive) ...[
                const SizedBox(width: AppSpacing.xs),
                const AppBadge(
                  label: 'Nonaktif',
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
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: AppSpacing.xs),
            Text('Batalkan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
          title: const Text('Batalkan undangan?'),
          content: Text(
            'Undangan untuk ${invitation.email} akan dihapus. '
            'Jika link sudah dikirim, pengguna tidak akan bisa klaim akses '
            'lagi dengan link itu.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Jangan'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('Batalkan Undangan'),
            ),
          ],
        ),
      );

  Future<void> _cancelInvitation(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final dao = ref.read(branchDaoProvider);
    final outboxDao = ref.read(outboxDaoProvider);
    await dao.deletePendingInvitation(invitation.id);
    await outboxDao.enqueue(OutboxItemsCompanion.insert(
      id: const Uuid().v7(),
      entityType: OutboxEntityType.pendingInvitation,
      payload: jsonEncode({'id': invitation.id, 'action': 'delete'}),
      createdAt: DateTime.now(),
    ));
    messenger.showSnackBar(
      SnackBar(content: Text('Undangan untuk ${invitation.email} dibatalkan')),
    );
  }
}

class _InvitationTile extends StatelessWidget {
  const _InvitationTile({required this.invitation});
  final PendingInvitationRow invitation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.accentSurface,
        border: Border.all(color: context.colors.border),
        borderRadius: AppRadius.radiusLg,
      ),
      child: Row(
        children: [
          const Icon(Icons.mark_email_unread_outlined,
              color: AppColors.accent),
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
            label: _roleLabel(invitation.globalRole.name),
            icon: Icons.badge_outlined,
            tone: AppBadgeTone.info,
          ),
        ],
      ),
    );
  }
}

String _roleLabel(String r) => switch (r) {
      'owner' => 'Pemilik',
      'manager' => 'Manajer',
      'cashier' => 'Kasir',
      _ => r,
    };
