import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/utils/result.dart';

/// Result is a sealed type — these tests lock the contract so refactors that
/// add helpers (map/fold) or change variance don't silently break callers.
void main() {
  group('Ok / Err construction', () {
    test('Ok holds the success value', () {
      const r = Ok<int, String>(42);
      expect(r.value, 42);
      expect(r, isA<Result<int, String>>());
    });

    test('Err holds the error value', () {
      const r = Err<int, String>('boom');
      expect(r.error, 'boom');
      expect(r, isA<Result<int, String>>());
    });

    test('Ok and Err are distinct subtypes (sealed)', () {
      const Result<int, String> ok = Ok(1);
      const Result<int, String> err = Err('x');
      expect(ok, isA<Ok<int, String>>());
      expect(ok, isNot(isA<Err<int, String>>()));
      expect(err, isA<Err<int, String>>());
      expect(err, isNot(isA<Ok<int, String>>()));
    });
  });

  group('exhaustive pattern matching', () {
    String label(Result<int, String> r) => switch (r) {
          Ok(:final value) => 'ok:$value',
          Err(:final error) => 'err:$error',
        };

    test('matches Ok branch', () {
      expect(label(const Ok(7)), 'ok:7');
    });

    test('matches Err branch', () {
      expect(label(const Err('nope')), 'err:nope');
    });
  });

  group('Unit', () {
    test('Unit.instance is a singleton', () {
      expect(Unit.instance, same(Unit.instance));
    });

    test('Result<Unit, E> idiom: success without a payload', () {
      const r = Ok<Unit, String>(Unit.instance);
      expect(r.value, same(Unit.instance));
    });
  });
}
