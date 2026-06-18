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
/// Code-based invite flow (FEAT-002 Phase 7):
/// 1. Owner generates an 8-char code with role + branch access + max uses + expiry
/// 2. Any signed-in user enters the code → claim RPC → becomes org member.
///
/// RLS: owner/admin manage; self-read by email match; claim bypasses RLS via RPC.
@DataClassName('PendingInvitationRow')
class PendingInvitations extends Table {
  TextColumn get id => text()();
  /// For email-based invites (legacy FEAT-006). Nullable for code-based invites.
  TextColumn get email => text().nullable()();
  TextColumn get fullName => text().nullable()();
  TextColumn get globalRole => text().map(
        const EnumNameConverter<GlobalRole>(GlobalRole.values),
      )();
  /// Comma-separated branch ids the invitee should get access to. Each entry
  /// becomes a `user_branch_access` row at claim time. Empty string = no
  /// branch access (e.g. an owner-only invite).
  TextColumn get branchIdsCsv => text().withDefault(const Constant(''))();
  TextColumn get invitedBy => text().nullable()();
  /// FEAT-002 Phase 7 — 8-char alphanumeric invitation code for users who
  /// already have an account. Null for legacy email-based invites.
  TextColumn get joinCode => text().nullable()();
  /// 'email' (legacy) or 'code'. Default 'email' for backward compatibility.
  TextColumn get inviteType => text().withDefault(const Constant('email'))();
  /// Max number of times a code invite can be claimed. Default 1.
  IntColumn get maxUses => integer().withDefault(const Constant(1))();
  /// How many times the code has been claimed so far. Default 0.
  IntColumn get usedCount => integer().withDefault(const Constant(0))();
  /// 'active', 'consumed', or 'canceled'.
  TextColumn get status => text().withDefault(const Constant('active'))();
  /// Optional expiry timestamp for code-based invites.
  DateTimeColumn get expiresAt => dateTime().nullable()();
  /// FEAT-002 — tenant boundary, nullable during migration then backfilled.
  TextColumn get organizationId => text().nullable()();
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
