import 'dart:convert';
import 'dart:math' as math;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/branch_dao.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/daos/organization_dao.dart';
import '../../core/database/daos/outbox_dao.dart';
import '../../core/domain/enums.dart';
import '../../core/network/supabase_providers.dart';
import '../../core/domain/entitlement_snapshot.dart';
import '../../core/storage/secure_storage.dart';
import '../../core/sync/sync_repository.dart';
import '../../core/utils/result.dart';

/// Auth errors surfaced to the UI.
enum AuthError {
  invalidCredentials,
  userInactive,
  userNotRegistered,
  noBranchAccess,
  networkUnavailable,
  unknown,

  /// FEAT-006 magic link: Supabase rejected the email (rate limit, invalid).
  emailDispatchFailed,
}

/// FEAT-006 — deep link target for Supabase magic-link redirects.
///
/// Configured at three places that MUST stay in sync:
///   1. This constant — used as `emailRedirectTo` in signInWithOtp
///   2. `android/app/src/main/AndroidManifest.xml` intent-filter
///   3. Supabase project → Authentication → URL Configuration → Redirect URLs
const String kAuthDeepLink = 'kopiyantea://login-callback';

/// Lightweight result type for sign-in.
class AuthedSession {
  const AuthedSession({
    required this.user,
    required this.branchId,
    this.organizationId,
    this.entitlement,
  });
  final AppUserRow user;
  final String branchId;
  final String? organizationId;
  final EntitlementSnapshot? entitlement;
}

/// Wraps Supabase Auth + maps to the local `app_users` row.
///
/// The session is the source of truth; the local Drift row provides the
/// role + branch access mapping. Sign-out clears both Supabase session and
/// the SecureStorage cache.
class AuthRepository {
  AuthRepository({
    required this.branchDao,
    required this.outboxDao,
    required this.secureStorage,
    required this.syncRepository,
    required this.organizationDao,
  });

  final BranchDao branchDao;
  final OutboxDao outboxDao;
  final SecureStorage secureStorage;
  final SyncRepository syncRepository;
  final OrganizationDao organizationDao;
  final Logger _log = Logger();

  /// Lazy access — returns null when Supabase isn't initialized (e.g. dev
  /// without a project configured). Demo sign-in keeps the app usable offline.
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Session? get currentSession => _supabase?.auth.currentSession;

  /// Stream of Supabase auth events — used by [Auth] notifier to react to
  /// magic-link redirects (SIGNED_IN events fire when the user taps the
  /// magic-link email and the deep link returns to the app).
  Stream<AuthState>? get authEvents => _supabase?.auth.onAuthStateChange;

  /// FEAT-006 — send a magic-link email. No password required. The email
  /// contains a link that deep-links back into the app, which Supabase's
  /// Flutter SDK auto-handles via [onAuthStateChange].
  /// FEAT-008 — kick off Google OAuth via Supabase. Returns Ok once the
  /// browser hand-off is initiated; the actual session arrives later via
  /// `auth.onAuthStateChange` and is handled in [resolveSessionWithClaim].
  /// Requires Supabase project: Auth → Providers → Google enabled, with
  /// `kopiyantea://login-callback` whitelisted as a redirect URL.
  Future<Result<Unit, AuthError>> signInWithGoogle() async {
    final sb = _supabase;
    if (sb == null) return const Err(AuthError.networkUnavailable);
    try {
      await sb.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kAuthDeepLink,
      );
      return Ok(Unit.instance);
    } on AuthException catch (e) {
      _log.w('[Auth] Google OAuth failed: ${e.message}');
      return const Err(AuthError.unknown);
    } catch (e) {
      _log.e('[Auth] Google OAuth error', error: e);
      return const Err(AuthError.networkUnavailable);
    }
  }

  Future<Result<Unit, AuthError>> signInWithMagicLink(String email) async {
    final sb = _supabase;
    if (sb == null) return const Err(AuthError.networkUnavailable);
    try {
      await sb.auth.signInWithOtp(
        email: email,
        emailRedirectTo: kAuthDeepLink,
      );
      await secureStorage.write(SecureStorage.kLastSignedInEmail, email);
      return Ok(Unit.instance);
    } on AuthException catch (e) {
      _log.w('[Auth] magic-link send failed: ${e.message}');
      return const Err(AuthError.emailDispatchFailed);
    } catch (e) {
      _log.e('[Auth] magic-link error', error: e);
      return const Err(AuthError.networkUnavailable);
    }
  }

  /// FEAT-002 Phase 7 — claim an open invitation code to join an existing org.
  /// Calls the `claim_invitation_code` PostgreSQL RPC with row locking.
  /// Returns the organization info on success, or an error string on failure.
  Future<Result<({String organizationId, String organizationName, String role}), String>> claimJoinCode({
    required String code,
    required String userId,
  }) async {
    final sb = _supabase;
    if (sb == null) return const Err('network_unavailable');
    try {
      final result = await sb.rpc(
        'claim_invitation_code',
        params: {'p_code': code, 'p_user_id': userId},
      );
      final json = result as Map<String, dynamic>;
      if (json['ok'] == true) {
        return Ok((
          organizationId: json['organization_id'] as String,
          organizationName: json['organization_name'] as String? ?? '',
          role: json['role'] as String,
        ));
      }
      return Err(json['error'] as String? ?? 'unknown');
    } catch (e) {
      _log.e('[Auth] claimJoinCode error', error: e);
      return const Err('unknown');
    }
  }

  /// FEAT-002 Phase 7 — generate a code-based invitation for an existing org.
  /// Creates a `pending_invitations` row on Supabase with `invite_type='code'`.
  /// The generated code is an 8-char alphanumeric uppercase string.
  Future<Result<String, String>> generateJoinCode({
    required String organizationId,
    required String role,
    required String branchIdsCsv,
    required int maxUses,
    required DateTime? expiresAt,
    required String invitedBy,
  }) async {
    final sb = _supabase;
    if (sb == null) return const Err('network_unavailable');

    // Generate random 8-char alphanumeric code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = math.Random.secure();
    final code = List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join();

    try {
      await sb.from('pending_invitations').insert({
        'id': const Uuid().v7(),
        'organization_id': organizationId,
        'join_code': code,
        'invite_type': 'code',
        'global_role': role,
        'branch_ids_csv': branchIdsCsv,
        'invited_by': invitedBy,
        'max_uses': maxUses,
        'used_count': 0,
        'status': 'active',
        'expires_at': expiresAt?.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      });
      return Ok(code);
    } catch (e) {
      _log.e('[Auth] generateJoinCode error', error: e);
      return const Err('insert_failed');
    }
  }

  /// Called by [Auth] notifier when a session arrives via deep link (magic
  /// link redirect). Mirrors the post-Supabase-signin work that [signIn]
  /// does, minus the password call.
  Future<Result<AuthedSession, AuthError>> resolveSessionWithClaim(
    Session session,
  ) async {
    final uid = session.user.id;
    final email = session.user.email ?? '';
    if (email.isNotEmpty) {
      await secureStorage.write(SecureStorage.kLastSignedInEmail, email);
    }
    await syncRepository.pullMyAuthContext(uid);
    await _restoreMissingAppUserEmail(uid: uid, email: email);
    if (email.isNotEmpty) {
      await syncRepository.pullPendingInvitationByEmail(email);
      await _maybeClaimInvitation(uid: uid, email: email);
    }
    return _resolveAppUser(uid, signOutOnFailure: true);
  }

  Future<Result<AuthedSession, AuthError>> signIn({
    required String email,
    required String password,
  }) async {
    final sb = _supabase;
    if (sb == null) return const Err(AuthError.networkUnavailable);

    try {
      final res = await sb.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final uid = res.user?.id;
      if (uid == null) return const Err(AuthError.invalidCredentials);

      await secureStorage.write(SecureStorage.kLastSignedInEmail, email);

      // Pull the user's auth context (app_users + branch access + branches)
      // BEFORE resolving locally — otherwise first-time sign-in on this
      // device fails with userNotRegistered.
      await syncRepository.pullMyAuthContext(uid);
      await _restoreMissingAppUserEmail(uid: uid, email: email);

      // FEAT-006 — pull any pending invitation matching this email so the
      // claim step below can run on the inviter's device too. Cheap: server
      // returns single row or null.
      await syncRepository.pullPendingInvitationByEmail(email);

      // FEAT-006 — first-time claim of a pending invitation.
      // If app_users row still doesn't exist locally after pull, but there's
      // a pending_invitations row matching this email, create the user
      // record + branch access from the invitation and delete it.
      await _maybeClaimInvitation(uid: uid, email: email);

      return _resolveAppUser(uid, signOutOnFailure: true);
    } on AuthException catch (e) {
      _log.w('[Auth] sign-in failed: ${e.message}');
      if (e.message.toLowerCase().contains('invalid')) {
        return const Err(AuthError.invalidCredentials);
      }
      return const Err(AuthError.unknown);
    } catch (e) {
      _log.e('[Auth] sign-in error', error: e);
      return const Err(AuthError.networkUnavailable);
    }
  }

  /// Restore a previously-authenticated session on app launch.
  Future<AuthedSession?> restoreSession() async {
    final session = currentSession;
    if (session == null) return null;
    await _restoreMissingAppUserEmail(
      uid: session.user.id,
      email: session.user.email ?? '',
    );
    final r = await _resolveAppUser(session.user.id, signOutOnFailure: false);
    return r is Ok<AuthedSession, AuthError> ? r.value : null;
  }

  Future<void> signOut() async {
    try {
      await _supabase?.auth.signOut();
    } catch (e) {
      _log.w('[Auth] sign-out error (ignored)', error: e);
    }
    await secureStorage.clearAll();
  }

  Future<void> _restoreMissingAppUserEmail({
    required String uid,
    required String email,
  }) async {
    final normalizedEmail = email.trim();
    if (normalizedEmail.isEmpty) return;

    final user = await branchDao.getUserById(uid);
    if (user == null || (user.email?.trim().isNotEmpty ?? false)) return;

    final now = DateTime.now();
    await branchDao.updateUserById(
      uid,
      AppUsersCompanion(
        email: Value(normalizedEmail),
        updatedAt: Value(now),
      ),
    );

    try {
      await _supabase?.from('app_users').update({
        'email': normalizedEmail,
        'updated_at': now.toIso8601String(),
      }).eq('id', uid);
    } catch (e) {
      _log.w('[Auth] failed to restore app_users.email on server', error: e);
      await outboxDao.enqueue(
        OutboxItemsCompanion.insert(
          id: const Uuid().v7(),
          entityType: OutboxEntityType.appUser,
          payload: jsonEncode({'id': uid}),
          createdAt: now,
        ),
      );
    }
  }

  /// Claims a pending invitation matching [email] by creating the local
  /// `app_users` row + `user_branch_access` rows + outbox pushes, then
  /// deleting the invitation.
  ///
  /// Idempotent — no-op if the user already exists locally OR no invitation
  /// matches. Server-side, `pending_invitations` is also looked up via
  /// `pullMyAuthContext` (TODO: extend pull to fetch invitations by email
  /// pre-claim; current pull is row-by-id which presumes the row exists).
  Future<void> _maybeClaimInvitation({
    required String uid,
    required String email,
  }) async {
    // Already a registered user? Skip.
    final existing = await branchDao.getUserById(uid);
    if (existing != null) return;

    final invitation = await branchDao.getPendingInvitationByEmail(email);
    if (invitation == null) {
      _log.w('[Auth] no pending invitation for $email');
      return;
    }

    final now = DateTime.now();
    await branchDao.upsertUser(AppUsersCompanion.insert(
      id: uid,
      fullName: invitation.fullName ?? '',
      globalRole: invitation.globalRole,
      email: Value(invitation.email),
      isActive: const Value(true),
      createdAt: now,
      updatedAt: now,
    ));
    await outboxDao.enqueue(OutboxItemsCompanion.insert(
      id: const Uuid().v7(),
      entityType: OutboxEntityType.appUser,
      payload: jsonEncode({'id': uid}),
      createdAt: now,
    ));

    final branchIds = invitation.branchIdsCsv
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty);
    for (final branchId in branchIds) {
      final branchRole = switch (invitation.globalRole) {
        GlobalRole.owner => null,
        GlobalRole.manager => BranchRole.manager,
        GlobalRole.cashier => BranchRole.cashier,
      };
      await branchDao.upsertUserBranchAccess(
        UserBranchAccessesCompanion.insert(
          userId: uid,
          branchId: branchId,
          roleAtBranch: Value(branchRole),
        ),
      );
      await outboxDao.enqueue(OutboxItemsCompanion.insert(
        id: const Uuid().v7(),
        entityType: OutboxEntityType.userBranchAccess,
        payload: jsonEncode({
          'user_id': uid,
          'branch_id': branchId,
          'action': 'upsert',
        }),
        createdAt: now,
      ));
    }

    await branchDao.deletePendingInvitation(invitation.id);
    await outboxDao.enqueue(OutboxItemsCompanion.insert(
      id: const Uuid().v7(),
      entityType: OutboxEntityType.pendingInvitation,
      payload: jsonEncode({'id': invitation.id, 'action': 'delete'}),
      createdAt: now,
    ));
    _log.i('[Auth] claimed invitation for $email → uid=$uid '
        '(${branchIds.length} branches)');
  }

  Future<Result<AuthedSession, AuthError>> _resolveAppUser(
    String uid, {
    required bool signOutOnFailure,
  }) async {
    final localUser = await branchDao.getUserById(uid);
    if (localUser == null) {
      if (signOutOnFailure) await _supabase?.auth.signOut();
      return const Err(AuthError.userNotRegistered);
    }
    if (!localUser.isActive) {
      if (signOutOnFailure) await _supabase?.auth.signOut();
      return const Err(AuthError.userInactive);
    }
    final access = await branchDao.watchAccessForUser(uid).first;
    if (access.isEmpty) {
      if (signOutOnFailure) await _supabase?.auth.signOut();
      return const Err(AuthError.noBranchAccess);
    }
    final org = await organizationDao.getOrganizationForUser(uid);
    return Ok(AuthedSession(
      user: localUser,
      branchId: access.first.branchId,
      organizationId: org?.id,
    ));
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    branchDao: ref.watch(branchDaoProvider),
    outboxDao: ref.watch(outboxDaoProvider),
    secureStorage: ref.watch(secureStorageProvider),
    syncRepository: ref.watch(syncRepositoryProvider),
    organizationDao: ref.watch(organizationDaoProvider),
  ),
);
