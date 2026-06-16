import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/daos/organization_dao.dart';
import '../../core/sync/sync_provider.dart';
import '../../core/utils/result.dart';
import 'auth_repository.dart';
import 'bootstrap_provider.dart';

part 'auth_provider.freezed.dart';
part 'auth_provider.g.dart';

/// Auth state — sealed union for exhaustive pattern matching (ADR-0005).
/// Uses [AppUserRow] (Drift) since the rest of the app operates on row types.
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = Unauthenticated;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated({
    required AppUserRow user,
    required String branchId,
    String? organizationId,
  }) = Authenticated;
  // FEAT-002 Stage 5 — user is signed in but has no organization yet;
  // router should redirect to /onboarding.
  const factory AuthState.needsOnboarding({
    required AppUserRow user,
    required String branchId,
  }) = NeedsOnboarding;
}

@riverpod
class Auth extends _$Auth {
  final Logger _log = Logger();
  StreamSubscription<sb.AuthState>? _supaSub;

  @override
  AuthState build() {
    // Kick off session restore after the current frame. State starts as
    // loading; the microtask flips it to authenticated/unauthenticated.
    Future.microtask(_restoreSession);
    // FEAT-006 — listen for magic-link redirects (or any out-of-band sign-in
    // event from Supabase) and re-resolve so the claim flow runs.
    _subscribeToSupabaseEvents();
    ref.onDispose(() => _supaSub?.cancel());
    return const AuthState.loading();
  }

  void _subscribeToSupabaseEvents() {
    final repo = ref.read(authRepositoryProvider);
    final events = repo.authEvents;
    if (events == null) return;
    _supaSub = events.listen((e) async {
      if (e.event != sb.AuthChangeEvent.signedIn) return;
      // Skip if our state already mirrors this session — e.g. signIn() just
      // finished and updated state directly. Magic-link redirects fire when
      // current state is Unauthenticated/Loading.
      final current = state;
      if (current is Authenticated &&
          current.user.id == e.session?.user.id) {
        return;
      }
      // ── FEAT-002 Stage 5: also skip if already in needsOnboarding state
      if (current is NeedsOnboarding &&
          current.user.id == e.session?.user.id) {
        return;
      }
      final session = e.session;
      if (session == null) return;
      _log.i('[Auth] signed-in via Supabase event (magic link?) — '
          'running claim flow');
      state = const AuthState.loading();
      final result = await repo.resolveSessionWithClaim(session);
      state = switch (result) {
        Ok(:final value) => () {
            // Magic-link redirect counts as an explicit sign-in → trigger
            // post-login bootstrap pull.
            ref.read(bootstrapProvider.notifier).markPending();
            // FEAT-002 Stage 5 — if no org, user needs onboarding setup.
            if (value.organizationId == null) {
              return AuthState.needsOnboarding(
                user: value.user,
                branchId: value.branchId,
              );
            }
            return AuthState.authenticated(
              user: value.user,
              branchId: value.branchId,
              organizationId: value.organizationId,
            );
          }(),
        Err() => const AuthState.unauthenticated(),
      };
    });
  }

  Future<void> _restoreSession() async {
    final repo = ref.read(authRepositoryProvider);
    final restored = await repo.restoreSession();
    if (restored == null) {
      state = const AuthState.unauthenticated();
    } else {
      // FEAT-002 Stage 5 — if no org, user needs onboarding setup.
      if (restored.organizationId == null) {
        state = AuthState.needsOnboarding(
          user: restored.user,
          branchId: restored.branchId,
        );
      } else {
        state = AuthState.authenticated(
          user: restored.user,
          branchId: restored.branchId,
          organizationId: restored.organizationId,
        );
      }
      // TODO-BG-SYNC-ON-RESUME — fire-and-forget pull so cached data doesn't
      // go stale when the user reopens the app after edits on another device.
      // Force-sync (minInterval=0) since session restore = first run of this
      // app instance.
      // ignore: unawaited_futures
      ref.read(syncProvider.notifier).bgSyncIfStale(
            minInterval: Duration.zero,
          );
    }
  }

  /// FEAT-006 — request a magic-link email. UI shows a "check your email"
  /// confirmation; auth state flips to Authenticated only after the user
  /// taps the link and the redirect handler fires [resolveSessionWithClaim].
  Future<Result<Unit, AuthError>> signInWithMagicLink(String email) async {
    final repo = ref.read(authRepositoryProvider);
    return repo.signInWithMagicLink(email);
  }

  /// FEAT-008 — kick off Google OAuth. Browser is launched by Supabase;
  /// post-redirect session is handled by the [onAuthStateChange] listener.
  Future<Result<Unit, AuthError>> signInWithGoogle() async {
    final repo = ref.read(authRepositoryProvider);
    return repo.signInWithGoogle();
  }

  Future<Result<Unit, AuthError>> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signIn(email: email, password: password);
    return switch (result) {
      Ok(:final value) => () {
          // Trigger bootstrap pull BEFORE flipping state so the router
          // sees `pending` on first redirect evaluation and routes to
          // /bootstrap (not /pos).
          ref.read(bootstrapProvider.notifier).markPending();
          // FEAT-002 Stage 5 — if no org, user needs onboarding setup.
          if (value.organizationId == null) {
            state = AuthState.needsOnboarding(
              user: value.user,
              branchId: value.branchId,
            );
          } else {
            state = AuthState.authenticated(
              user: value.user,
              branchId: value.branchId,
              organizationId: value.organizationId,
            );
          }
          return const Ok<Unit, AuthError>(Unit.instance);
        }(),
      Err(:final error) => () {
          state = const AuthState.unauthenticated();
          return Err<Unit, AuthError>(error);
        }(),
    };
  }

  Future<void> signOut() async {
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    // Clear bootstrap state so a future sign-in starts from `complete` and
    // the markPending in signIn drives the post-login pull.
    ref.read(bootstrapProvider.notifier).reset();
    state = const AuthState.unauthenticated();
  }

  /// FEAT-002 Stage 5 — called after user completes onboarding
  /// (creates a new org or joins via invitation).
  /// Transitions auth state from `needsOnboarding` to `authenticated`
  /// with the new `organizationId`.
  Future<void> completeOnboarding({
    required String organizationId,
    required String organizationName,
  }) async {
    final current = state;
    if (current is! NeedsOnboarding) {
      _log.w('[Auth] completeOnboarding called in wrong state: $current');
      return;
    }

    state = AuthState.authenticated(
      user: current.user,
      branchId: current.branchId,
      organizationId: organizationId,
    );
    _log.i('[Auth] onboarding complete → org=$organizationId');
  }
}

// ── Convenience derived providers ─────────────────────────────────────────────

final currentUserProvider = Provider<AppUserRow?>(
  (ref) => switch (ref.watch(authProvider)) {
    // FEAT-002 Stage 5: NeedsOnboarding also has a user.
    Authenticated(:final user) => user,
    NeedsOnboarding(:final user) => user,
    _ => null,
  },
);

final currentBranchIdProvider = Provider<String?>(
  (ref) => switch (ref.watch(authProvider)) {
    // FEAT-002 Stage 5: NeedsOnboarding also has a branchId.
    Authenticated(:final branchId) => branchId,
    NeedsOnboarding(:final branchId) => branchId,
    _ => null,
  },
);

/// True only when the user has completed onboarding (has an organization).
/// Used by router to guard /pos and other org-dependent routes.
final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authProvider) is Authenticated,
);

// ── FEAT-002 Stage 5: Organization derived providers ────────────────────────

/// Null when user is not authenticated OR is in needsOnboarding state
/// (no org yet).
final currentOrganizationIdProvider = Provider<String?>(
  (ref) => switch (ref.watch(authProvider)) {
    Authenticated(:final organizationId) => organizationId,
    // NeedsOnboarding: organizationId is always null by definition.
    NeedsOnboarding() => null,
    _ => null,
  },
);

/// Watches the current user's organization. Returns null if:
/// - user is not authenticated
/// - user is in needsOnboarding state
/// - organization has not been synced locally yet
final currentOrganizationProvider = FutureProvider<OrganizationRow?>(
  (ref) async {
    final orgId = ref.watch(currentOrganizationIdProvider);
    if (orgId == null) return null;
    final dao = ref.watch(organizationDaoProvider);
    return dao.getOrganizationById(orgId);
  },
);
