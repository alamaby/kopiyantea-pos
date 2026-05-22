import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/database/database_provider.dart';
import 'package:kopiyantea_pos/main.dart';

void main() {
  testWidgets('App boots to POS shell with adaptive nav', (tester) async {
    // Boot with an in-memory Drift DB — main.dart's databaseProvider asserts
    // it has been overridden, and the app immediately watches several DAOs
    // during the first frame (branches, outbox count, menu grid, …).
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const KopiyanteaPosApp(),
      ),
    );
    // pumpAndSettle would hang on the auth loading splash + any periodic
    // animations; a bounded pump is enough to reach the first stable frame.
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    // POS is the initial branch — its placeholder title should appear.
    expect(find.text('Kasir'), findsAtLeastNWidgets(1));
    // Adaptive nav includes Lainnya as the 5th destination.
    expect(find.text('Lainnya'), findsOneWidget);
  });
}
