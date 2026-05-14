import 'package:drift/drift.dart';

import '../../domain/enums.dart';

/// Local-only outbox for the offline-sync pipeline (ADR-0004).
/// Every pending push to Supabase starts life here.
class OutboxItems extends Table {
  TextColumn get id => text()(); // UUID v7
  TextColumn get entityType => text().map(
        const EnumNameConverter<OutboxEntityType>(OutboxEntityType.values),
      )();
  TextColumn get payload => text()(); // JSON string
  TextColumn get status => text()
      .map(const EnumNameConverter<OutboxStatus>(OutboxStatus.values))
      .withDefault(const Constant('pending'))();
  IntColumn get attemptCount =>
      integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get nextRetryAt => dateTime().nullable()();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
