import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/utils/org_resolver.dart';

void main() {
  group('resolveOrgForInsert', () {
    test('returns trimmed id when present', () {
      expect(resolveOrgForInsert('org-1'), 'org-1');
      expect(resolveOrgForInsert('  org-1  '), 'org-1');
    });

    test('returns null when absent or blank (insert must abort)', () {
      expect(resolveOrgForInsert(null), isNull);
      expect(resolveOrgForInsert(''), isNull);
      expect(resolveOrgForInsert('   '), isNull);
    });
  });
}
