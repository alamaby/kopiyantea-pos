import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kopiyantea_pos/main.dart';

void main() {
  testWidgets('App boots to Beranda', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: KopiyanteaPosApp()));
    await tester.pumpAndSettle();

    expect(find.text('Selamat datang'), findsOneWidget);
  });
}
