import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/domain/branch.dart';

part 'auth_provider.freezed.dart';
part 'auth_provider.g.dart';

/// Auth state — sealed union for exhaustive pattern matching (ADR-0005).
@freezed
sealed class AuthState with _$AuthState {
  const factory AuthState.unauthenticated() = Unauthenticated;
  const factory AuthState.loading() = AuthLoading;
  const factory AuthState.authenticated({
    required AppUser user,
    required String branchId,
  }) = Authenticated;
}

/// Stub auth notifier. Full Supabase auth wired in Phase 6.
@riverpod
class Auth extends _$Auth {
  @override
  AuthState build() => const AuthState.unauthenticated();

  // Phase 6 will implement:
  //   Future<void> signIn(String email, String password) { ... }
  //   Future<void> signOut() { ... }
  //   void _onSupabaseAuthStateChange(AuthState) { ... }
}

/// Convenience derived providers.

final currentUserProvider = Provider<AppUser?>(
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
