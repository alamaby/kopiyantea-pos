import 'package:drift/drift.dart';

import '../../domain/enums.dart';

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
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppUsers extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text()();
  TextColumn get globalRole => text().map(
        const EnumNameConverter<GlobalRole>(GlobalRole.values),
      )();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get failedLoginCount =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get lockedUntil => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

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
