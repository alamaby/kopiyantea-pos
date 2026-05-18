import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/branch_dao.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/network/supabase_providers.dart';
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
}

/// Lightweight result type for sign-in.
class AuthedSession {
  const AuthedSession({required this.user, required this.branchId});
  final AppUserRow user;
  final String branchId;
}

/// Wraps Supabase Auth + maps to the local `app_users` row.
///
/// The session is the source of truth; the local Drift row provides the
/// role + branch access mapping. Sign-out clears both Supabase session and
/// the SecureStorage cache.
class AuthRepository {
  AuthRepository({
    required this.branchDao,
    required this.secureStorage,
    required this.syncRepository,
  });

  final BranchDao branchDao;
  final SecureStorage secureStorage;
  final SyncRepository syncRepository;
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

  /// Dev-only — bypasses Supabase, picks the seed cashier from local Drift.
  /// Outbox push will fail without auth.uid; demo mode is offline-only.
  Future<Result<AuthedSession, AuthError>> signInAsDemo() async {
    const seedCashierId = '00000000-0000-0000-0000-000000000012';
    const seedBranchId = '00000000-0000-0000-0000-000000000001';
    final user = await branchDao.getUserById(seedCashierId);
    if (user == null) return const Err(AuthError.userNotRegistered);
    if (!user.isActive) return const Err(AuthError.userInactive);
    _log.i('[Auth] demo sign-in as ${user.fullName}');
    return Ok(AuthedSession(user: user, branchId: seedBranchId));
  }

  /// Restore a previously-authenticated session on app launch.
  Future<AuthedSession?> restoreSession() async {
    final session = currentSession;
    if (session == null) return null;
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
    return Ok(AuthedSession(user: localUser, branchId: access.first.branchId));
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    branchDao: ref.watch(branchDaoProvider),
    secureStorage: ref.watch(secureStorageProvider),
    syncRepository: ref.watch(syncRepositoryProvider),
  ),
);
