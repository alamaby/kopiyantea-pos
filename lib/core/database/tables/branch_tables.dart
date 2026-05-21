import 'package:drift/drift.dart';

import '../../domain/enums.dart';

@DataClassName('BranchRow')
class Branches extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get timezone =>
      text().withDefault(const Constant('Asia/Jakarta'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  RealColumn get taxPercentage => real().withDefault(const Constant(10.0))();
  TextColumn get taxLabel => text().withDefault(const Constant('PB1'))();
  BoolColumn get taxInclusive =>
      boolean().withDefault(const Constant(false))();
  IntColumn get failedLoginLockoutThreshold =>
      integer().withDefault(const Constant(5))();
  /// FEAT-013 — public URL of the branch's static QRIS image in Supabase
  /// Storage (`qris-images` bucket). Shown at checkout when payment method
  /// is QRIS, and via a quick-access button on the POS AppBar.
  TextColumn get qrisImageUrl => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AppUserRow')
class AppUsers extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text()();
  TextColumn get globalRole => text().map(
        const EnumNameConverter<GlobalRole>(GlobalRole.values),
      )();
  /// Added in schema v3 (FEAT-006). Nullable for backward compatibility with
  /// rows seeded before invite flow existed.
  TextColumn get email => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get failedLoginCount =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Pre-auth user record created by owner via the User Management UI.
///
/// Flow (FEAT-006, no service_role needed on client):
/// 1. Owner adds invite: name + email + role + branch ids (CSV)
/// 2. Invitee installs the app and signs up to Supabase using that email
/// 3. On first sign-in, AuthRepository looks up `pending_invitations` by email,
///    creates the `app_users` row with auth.uid + role, fans out
///    `user_branch_access` rows, then deletes the invitation.
///
/// RLS: select by own email OR owner; insert/delete by owner only.
@DataClassName('PendingInvitationRow')
class PendingInvitations extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get fullName => text()();
  TextColumn get globalRole => text().map(
        const EnumNameConverter<GlobalRole>(GlobalRole.values),
      )();
  /// Comma-separated branch ids the invitee should get access to. Each entry
  /// becomes a `user_branch_access` row at claim time. Empty string = no
  /// branch access (e.g. an owner-only invite).
  TextColumn get branchIdsCsv => text().withDefault(const Constant(''))();
  TextColumn get invitedBy => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('UserBranchAccessRow')
class UserBranchAccesses extends Table {
  TextColumn get userId =>
      text().references(AppUsers, #id, onDelete: KeyAction.cascade)();
  TextColumn get branchId =>
      text().references(Branches, #id, onDelete: KeyAction.cascade)();
  TextColumn get roleAtBranch => text()
      .nullable()
      .map(const EnumNameConverter<BranchRole>(BranchRole.values))();

  @override
  Set<Column<Object>> get primaryKey => {userId, branchId};
}
