import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:kopiyantea_pos/core/database/app_database.dart';
import 'package:kopiyantea_pos/core/domain/enums.dart';
import 'package:kopiyantea_pos/core/sync/sync_dtos.dart';

void main() {
  test('legacy 7-col JSON defaults code-invite fields', () {
    final json = <String, dynamic>{
      'id': 'inv-1',
      'email': 'a@x.id',
      'full_name': 'A',
      'global_role': 'cashier',
      'branch_ids_csv': '',
      'invited_by': null,
      'created_at': DateTime(2026, 9, 25, 10, 0).toUtc().toIso8601String(),
    };
    final c = pendingInvitationFromJson(json);
    expect(c.inviteType.value, 'email');
    expect(c.maxUses.value, 1);
    expect(c.usedCount.value, 0);
    expect(c.status.value, 'active');
    expect(c.joinCode.value, isNull);
    expect(c.expiresAt.value, isNull);
  });

  test('full 14-col JSON roundtrips join_code', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    final json = <String, dynamic>{
      'id': 'inv-2',
      'email': null,
      'full_name': 'Code User',
      'global_role': 'cashier',
      'branch_ids_csv': '',
      'invited_by': 'u1',
      'join_code': 'AB12CD34',
      'invite_type': 'code',
      'max_uses': 5,
      'used_count': 2,
      'status': 'active',
      'expires_at': null,
      'organization_id': 'org-1',
      'created_at': DateTime(2026, 9, 25, 10, 0).toUtc().toIso8601String(),
    };
    final c = pendingInvitationFromJson(json);
    await db.into(db.pendingInvitations).insert(c);
    final row = await (db.select(db.pendingInvitations)
          ..where((t) => t.id.equals('inv-2')))
        .getSingle();
    expect(row.joinCode, 'AB12CD34');
    expect(row.inviteType, 'code');
    expect(row.maxUses, 5);
    expect(row.usedCount, 2);
    final pushed = row.toSupabaseJson();
    expect(pushed['join_code'], 'AB12CD34');
    expect(pushed['expires_at'], isNull);
  });

  test('null expires_at stays null in push', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await db.into(db.pendingInvitations).insert(
          PendingInvitationsCompanion.insert(
            id: 'inv-3',
            globalRole: GlobalRole.cashier,
            createdAt: DateTime(2026, 9, 25, 10, 0),
          ),
        );
    final row = await (db.select(db.pendingInvitations)
          ..where((t) => t.id.equals('inv-3')))
        .getSingle();
    expect(row.toSupabaseJson()['expires_at'], isNull);
  });
}
