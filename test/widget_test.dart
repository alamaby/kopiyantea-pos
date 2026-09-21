import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/database/database_provider.dart';
import 'package:kopiyantea_pos/main.dart';

void main() {
  testWidgets('App boots without crashing', (tester) async {
    final db = AppDatabase.memory();
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const KopiyanteaPosApp(),
      ),
    );
    // Bounded pump — app reaches a stable frame (login or env-error screen).
    await tester.pump(const Duration(milliseconds: 300));

    // The app must render something — at minimum a Scaffold with an AppBar.
    expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    // Boot lands on the POS shell in the test environment (BottomNav with
    // POS destination visible). 'Kasir' (old placeholder title) must not
    // appear anywhere.
    expect(find.text('POS'), findsWidgets);
    // The old POS placeholder ('Kasir') is gone; the app now routes through
    // auth guard to /login (or shows env-error if .env is missing).
    expect(find.text('Kasir'), findsNothing);
  });
}
