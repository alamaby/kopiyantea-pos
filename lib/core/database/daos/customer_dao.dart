import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/customer_tables.dart';

part 'customer_dao.g.dart';

@DriftAccessor(tables: [Customers])
class CustomerDao extends DatabaseAccessor<AppDatabase>
    with _$CustomerDaoMixin {
  CustomerDao(super.db);

  Stream<List<CustomerRow>> watchAll() =>
      (select(customers)
            ..orderBy([(c) => OrderingTerm.asc(c.name)]))
          .watch();

  Future<List<CustomerRow>> searchByName(String query) =>
      (select(customers)
            ..where((c) => c.name.like('%$query%'))
            ..limit(20))
          .get();

  Future<CustomerRow?> getByPhone(String phone) =>
      (select(customers)..where((c) => c.phone.equals(phone)))
          .getSingleOrNull();

  Future<void> upsertCustomer(CustomersCompanion companion) =>
      into(customers).insertOnConflictUpdate(companion);
}
