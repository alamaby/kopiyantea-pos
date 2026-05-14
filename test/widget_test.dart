import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kopiyantea_pos/main.dart';

void main() {
  testWidgets('App boots to POS shell with adaptive nav', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KopiyanteaPosApp()));
    await tester.pumpAndSettle();

    // POS is the initial branch — its placeholder title should appear.
    expect(find.text('Kasir'), findsAtLeastNWidgets(1));
    // Adaptive nav includes Lainnya as the 5th destination.
    expect(find.text('Lainnya'), findsOneWidget);
  });
}
