import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/database/daos/dao_providers.dart';
import '../../core/database/database_provider.dart';
import '../../core/domain/enums.dart';
import '../../core/sync/sync_provider.dart';

part 'telemetry_provider.g.dart';

/// ENH-009 — single snapshot powering the Telemetry screen.
class TelemetrySnapshot {
  const TelemetrySnapshot({
    required this.appName,
    required this.appVersion,
    required this.dbSizeBytes,
    required this.transactionCount,
    required this.transactionItemCount,
    required this.inventoryMovementCount,
    required this.outboxPending,
    required this.outboxFailed,
    required this.outboxDone,
    required this.lastSyncAt,
  });

  final String appName;
  final String appVersion;
  final int dbSizeBytes;
  final int transactionCount;
  final int transactionItemCount;
  final int inventoryMovementCount;
  final int outboxPending;
  final int outboxFailed;
  final int outboxDone;
  final DateTime? lastSyncAt;
}

@riverpod
Future<TelemetrySnapshot> telemetrySnapshot(
  TelemetrySnapshotRef ref,
) async {
  final db = ref.watch(databaseProvider);
  final outboxDao = ref.watch(outboxDaoProvider);

  // DB size — file may not exist in unit tests (memory DB); guard with 0.
  var dbSize = 0;
  try {
    final folder = await getApplicationDocumentsDirectory();
    final file = File(p.join(folder.path, 'kopiyantea.sqlite'));
    if (await file.exists()) dbSize = await file.length();
  } catch (_) {
    // ignore — diagnostic screen, not critical
  }

  Future<int> rowCount(TableInfo table) async {
    final cnt = countAll();
    final row = await (db.selectOnly(table)..addColumns([cnt])).getSingle();
    return row.read(cnt) ?? 0;
  }

  final txCount = await rowCount(db.transactions);
  final txItemCount = await rowCount(db.transactionItems);
  final invMovCount = await rowCount(db.inventoryMovements);

  final allOutbox = await outboxDao.watchAll().first;
  final pending =
      allOutbox.where((r) => r.status == OutboxStatus.pending).length;
  final failed = allOutbox.where((r) => r.status == OutboxStatus.failed).length;
  final done = allOutbox.where((r) => r.status == OutboxStatus.done).length;

  final syncState = ref.watch(syncProvider);
  final packageInfo = await PackageInfo.fromPlatform();

  return TelemetrySnapshot(
    appName: packageInfo.appName,
    appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
    dbSizeBytes: dbSize,
    transactionCount: txCount,
    transactionItemCount: txItemCount,
    inventoryMovementCount: invMovCount,
    outboxPending: pending,
    outboxFailed: failed,
    outboxDone: done,
    lastSyncAt: syncState.lastSyncAt,
  );
}
