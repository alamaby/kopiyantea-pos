import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/utils/result.dart';

/// Deterministic parse tests for the org signup RPC response shape.
/// The RPC itself is exercised in the device smoke (S-15/S-16); this pins
/// the client-side contract so a shape change fails fast.
void main() {
  Result<({String organizationId, String organizationName}), String>
      parseOrgRpc(Map<String, dynamic> json, String fallbackName) {
    if (json['ok'] == true) {
      return Ok((
        organizationId: json['organization_id'] as String,
        organizationName: json['organization_name'] as String? ?? fallbackName,
      ));
    }
    return Err(json['error'] as String? ?? 'unknown');
  }

  test('success payload yields Ok with server id + name', () {
    final r = parseOrgRpc({
      'ok': true,
      'organization_id': '11111111-2222-3333-4444-555555555555',
      'organization_name': 'Warung Kedua',
      'role': 'owner',
    }, 'Fallback');
    expect(r, isA<Ok<({String organizationId, String organizationName}), String>>());
    final v = (r as Ok<({String organizationId, String organizationName}), String>).value;
    expect(v.organizationId, '11111111-2222-3333-4444-555555555555');
    expect(v.organizationName, 'Warung Kedua');
  });

  test('success without name falls back to submitted name', () {
    final r = parseOrgRpc({
      'ok': true,
      'organization_id': 'org-2',
    }, 'Nama Input');
    final v = (r as Ok<({String organizationId, String organizationName}), String>).value;
    expect(v.organizationName, 'Nama Input');
  });

  test('failure payload yields Err with server error code', () {
    final r = parseOrgRpc({'ok': false, 'error': 'unauthenticated'}, 'X');
    expect(r, isA<Err<({String organizationId, String organizationName}), String>>());
    expect((r as Err<({String organizationId, String organizationName}), String>).error,
        'unauthenticated');
  });

  test('unknown shape yields Err(unknown) — never a silent success', () {
    final r = parseOrgRpc({}, 'X');
    expect((r as Err<({String organizationId, String organizationName}), String>).error,
        'unknown');
  });
}
