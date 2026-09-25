import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/sync/sync_repository.dart';

void main() {
  group('shouldFallbackToUnfiltered', () {
    test('missing organization_id column triggers fallback', () {
      expect(
        shouldFallbackToUnfiltered(
          Exception('column organization_id does not exist (42703)'),
        ),
        isTrue,
      );
    });

    test('PGRST error triggers fallback', () {
      expect(
        shouldFallbackToUnfiltered(
          Exception('PGRST205 table not found'),
        ),
        isTrue,
      );
    });

    test('auth error does not trigger fallback', () {
      expect(
        shouldFallbackToUnfiltered(Exception('invalid JWT')),
        isFalse,
      );
    });

    test('timeout does not trigger fallback', () {
      expect(
        shouldFallbackToUnfiltered(Exception('timeout')),
        isFalse,
      );
    });
  });
}
