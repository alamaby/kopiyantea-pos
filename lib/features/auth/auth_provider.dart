import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/result.dart';
import 'auth_repository.dart';

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
  @override
  AuthState build() {
    // Kick off session restore after the current frame. State starts as
    // loading; the microtask flips it to authenticated/unauthenticated.
    Future.microtask(_restoreSession);
    return const AuthState.loading();
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

  Future<Result<Unit, AuthError>> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthState.loading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signIn(email: email, password: password);
    return switch (result) {
      Ok(:final value) => () {
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

  Future<Result<Unit, AuthError>> signInAsDemo() async {
    state = const AuthState.loading();
    final repo = ref.read(authRepositoryProvider);
    final result = await repo.signInAsDemo();
    return switch (result) {
      Ok(:final value) => () {
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
