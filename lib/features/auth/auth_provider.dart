import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:logger/logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../core/database/app_database.dart';
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
  }) = Authenticated;
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
            return AuthState.authenticated(
              user: value.user,
              branchId: value.branchId,
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
      state = AuthState.authenticated(
        user: restored.user,
        branchId: restored.branchId,
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
          state = AuthState.authenticated(
            user: value.user,
            branchId: value.branchId,
          );
          return Ok<Unit, AuthError>(Unit.instance);
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
}

// ── Convenience derived providers ─────────────────────────────────────────────

final currentUserProvider = Provider<AppUserRow?>(
  (ref) => switch (ref.watch(authProvider)) {
    Authenticated(:final user) => user,
    _ => null,
  },
);

final currentBranchIdProvider = Provider<String?>(
  (ref) => switch (ref.watch(authProvider)) {
    Authenticated(:final branchId) => branchId,
    _ => null,
  },
);

final isAuthenticatedProvider = Provider<bool>(
  (ref) => ref.watch(authProvider) is Authenticated,
);
