import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/database/daos/outbox_dao.dart';
import 'package:kopiyantea_pos/core/domain/enums.dart';

/// Unit tests for [OutboxDao] — the queue that backs `pushOutbox`.
/// Uses an in-memory Drift DB; no Supabase mock needed.
void main() {
  late AppDatabase db;
  late OutboxDao dao;

  setUp(() {
    db = AppDatabase.memory();
    dao = OutboxDao(db);
  });

  tearDown(() => db.close());

  OutboxItemsCompanion _make({
    required String id,
    OutboxEntityType type = OutboxEntityType.transaction,
    OutboxStatus status = OutboxStatus.pending,
    DateTime? nextRetryAt,
    int? attemptCount,
    String payload = '{"id":"x"}',
    DateTime? createdAt,
  }) =>
      OutboxItemsCompanion.insert(
        id: id,
        entityType: type,
        payload: payload,
        status: Value(status),
        attemptCount:
            attemptCount == null ? const Value.absent() : Value(attemptCount),
        createdAt: createdAt ?? DateTime(2026, 5, 20, 10),
        nextRetryAt: Value(nextRetryAt),
      );

  group('getPendingItems', () {
    test('returns pending + failed rows; ignores done', () async {
      await dao.enqueue(_make(id: 'a', status: OutboxStatus.pending));
      await dao.enqueue(_make(id: 'b', status: OutboxStatus.failed));
      await dao.enqueue(_make(id: 'c', status: OutboxStatus.done));

      final rows = await dao.getPendingItems();
      expect(rows.map((r) => r.id), containsAll(['a', 'b']));
      expect(rows.map((r) => r.id), isNot(contains('c')));
    });

    test('filters out rows whose nextRetryAt is still in the future', () async {
      final future = DateTime.now().add(const Duration(hours: 1));
      final past = DateTime.now().subtract(const Duration(seconds: 30));
      await dao.enqueue(_make(id: 'a', nextRetryAt: future));
      await dao.enqueue(_make(id: 'b', nextRetryAt: past));
      await dao.enqueue(_make(id: 'c')); // nextRetryAt = null → eligible

      final rows = await dao.getPendingItems();
      expect(rows.map((r) => r.id), containsAll(['b', 'c']));
      expect(rows.map((r) => r.id), isNot(contains('a')));
    });

    test('orders by createdAt ASC (FIFO)', () async {
      await dao.enqueue(
          _make(id: 'newer', createdAt: DateTime(2026, 5, 20, 11)));
      await dao.enqueue(
          _make(id: 'older', createdAt: DateTime(2026, 5, 20, 9)));

      final rows = await dao.getPendingItems();
      expect(rows.first.id, 'older');
      expect(rows.last.id, 'newer');
    });

    test('respects the limit parameter', () async {
      for (var i = 0; i < 30; i++) {
        await dao.enqueue(_make(
          id: 'r$i',
          createdAt: DateTime(2026, 5, 20, 10, i),
        ));
      }
      final rows = await dao.getPendingItems(limit: 5);
      expect(rows, hasLength(5));
    });
  });

  group('markDone / markFailed', () {
    test('markDone flips status and removes the row from pending', () async {
      await dao.enqueue(_make(id: 'a'));
      await dao.markDone('a');

      final pending = await dao.getPendingItems();
      expect(pending, isEmpty);

      final row = await (db.select(db.outboxItems)
            ..where((o) => o.id.equals('a')))
          .getSingle();
      expect(row.status, OutboxStatus.done);
    });

    test('markFailed sets status=failed, error message, and nextRetryAt',
        () async {
      await dao.enqueue(_make(id: 'a'));
      final retry = DateTime(2026, 5, 20, 12);
      await dao.markFailed('a', error: 'boom', nextRetry: retry);

      final row = await (db.select(db.outboxItems)
            ..where((o) => o.id.equals('a')))
          .getSingle();
      expect(row.status, OutboxStatus.failed);
      expect(row.lastError, 'boom');
      expect(row.nextRetryAt, retry);
    });
  });

  group('retry helpers', () {
    test('retryNow resets a failed row back to pending', () async {
      await dao.enqueue(_make(
        id: 'a',
        status: OutboxStatus.failed,
        nextRetryAt: DateTime(2030),
      ));
      // ensure lastError is set
      await dao.markFailed('a',
          error: 'old', nextRetry: DateTime(2030));

      await dao.retryNow('a');
      final row = await (db.select(db.outboxItems)
            ..where((o) => o.id.equals('a')))
          .getSingle();
      expect(row.status, OutboxStatus.pending);
      expect(row.nextRetryAt, isNull);
      expect(row.lastError, isNull);
    });

    test('retryAllFailed flips every failed row at once, ignores others',
        () async {
      await dao.enqueue(_make(id: 'a', status: OutboxStatus.failed));
      await dao.enqueue(_make(id: 'b', status: OutboxStatus.failed));
      await dao.enqueue(_make(id: 'c', status: OutboxStatus.pending));
      await dao.enqueue(_make(id: 'd', status: OutboxStatus.done));

      final count = await dao.retryAllFailed();
      expect(count, 2);

      final all = await db.select(db.outboxItems).get();
      final byId = {for (final r in all) r.id: r.status};
      expect(byId['a'], OutboxStatus.pending);
      expect(byId['b'], OutboxStatus.pending);
      expect(byId['c'], OutboxStatus.pending);
      expect(byId['d'], OutboxStatus.done);
    });
  });

  group('deletion helpers', () {
    test('deleteById removes the row', () async {
      await dao.enqueue(_make(id: 'a'));
      final count = await dao.deleteById('a');
      expect(count, 1);
      final rows = await db.select(db.outboxItems).get();
      expect(rows, isEmpty);
    });

    test('deleteAllFailed wipes failed-status rows only', () async {
      await dao.enqueue(_make(id: 'a', status: OutboxStatus.failed));
      await dao.enqueue(_make(id: 'b', status: OutboxStatus.failed));
      await dao.enqueue(_make(id: 'c', status: OutboxStatus.pending));

      final count = await dao.deleteAllFailed();
      expect(count, 2);

      final remaining = await db.select(db.outboxItems).get();
      expect(remaining.map((r) => r.id), ['c']);
    });
  });

  group('watchPendingCount stream', () {
    test('counts pending + failed; emits on insert and on status change',
        () async {
      final stream = dao.watchPendingCount();
      final events = <int>[];
      final sub = stream.listen(events.add);

      // give Drift a beat to emit the initial empty count
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await dao.enqueue(_make(id: 'a', status: OutboxStatus.pending));
      await dao.enqueue(_make(id: 'b', status: OutboxStatus.failed));
      await dao.enqueue(_make(id: 'c', status: OutboxStatus.done));
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(events.last, 2, reason: 'done does not count');

      await dao.markDone('a');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(events.last, 1);

      await sub.cancel();
    });
  });
}
