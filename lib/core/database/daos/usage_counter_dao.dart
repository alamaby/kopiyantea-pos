import 'package:drift/drift.dart';

import '../app_database.dart';

/// DAO for usage_counters table (raw SQL, not registered in @DriftDatabase).
class UsageCounterDao {
  UsageCounterDao(this._db);

  final AppDatabase _db;

  Future<List<UsageCounterRow>> getByOrganization(String orgId) async {
    final rows = await _db.customSelect(
      'SELECT * FROM usage_counters WHERE organization_id = ?',
      variables: [Variable<String>(orgId)],
    ).get();
    return rows.map(_mapRow).toList();
  }

  Future<UsageCounterRow?> getForPeriod(
    String orgId,
    DateTime periodStart,
    DateTime periodEnd,
  ) async {
    final row = await _db.customSelect(
      'SELECT * FROM usage_counters '
      'WHERE organization_id = ? AND period_start = ? AND period_end = ?',
      variables: [
        Variable<String>(orgId),
        Variable<String>(periodStart.toIso8601String()),
        Variable<String>(periodEnd.toIso8601String()),
      ],
    ).getSingleOrNull();
    return row == null ? null : _mapRow(row);
  }

  Future<void> upsert(UsageCounterRow row) async {
    await _db.customStatement(
      'INSERT INTO usage_counters '
      '(organization_id, period_start, period_end, transaction_count, '
      'product_count_snapshot, branch_count_snapshot, employee_count_snapshot, '
      'updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(organization_id, period_start, period_end) DO UPDATE SET '
      'transaction_count = excluded.transaction_count, '
      'product_count_snapshot = excluded.product_count_snapshot, '
      'branch_count_snapshot = excluded.branch_count_snapshot, '
      'employee_count_snapshot = excluded.employee_count_snapshot, '
      'updated_at = excluded.updated_at',
      [
        row.organizationId,
        row.periodStart.toIso8601String(),
        row.periodEnd.toIso8601String(),
        row.transactionCount,
        row.productCountSnapshot,
        row.branchCountSnapshot,
        row.employeeCountSnapshot,
        row.updatedAt.toIso8601String(),
      ],
    );
  }

  UsageCounterRow _mapRow(QueryRow row) => UsageCounterRow(
        organizationId: row.read<String>('organization_id'),
        periodStart: DateTime.parse(row.read<String>('period_start')),
        periodEnd: DateTime.parse(row.read<String>('period_end')),
        transactionCount: row.read<int>('transaction_count'),
        productCountSnapshot: row.read<int>('product_count_snapshot'),
        branchCountSnapshot: row.read<int>('branch_count_snapshot'),
        employeeCountSnapshot: row.read<int>('employee_count_snapshot'),
        updatedAt: DateTime.parse(row.read<String>('updated_at')),
      );
}

class UsageCounterRow {
  const UsageCounterRow({
    required this.organizationId,
    required this.periodStart,
    required this.periodEnd,
    required this.updatedAt,
    this.transactionCount = 0,
    this.productCountSnapshot = 0,
    this.branchCountSnapshot = 0,
    this.employeeCountSnapshot = 0,
  });

  final String organizationId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int transactionCount;
  final int productCountSnapshot;
  final int branchCountSnapshot;
  final int employeeCountSnapshot;
  final DateTime updatedAt;
}
