import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/daos/dao_providers.dart';
import '../database/database_provider.dart';
import '../domain/enums.dart';
import 'sync_dtos.dart';

/// Result counters from a sync push pass.
class PushSummary {
  const PushSummary({required this.pushed, required this.failed});
  final int pushed;
  final int failed;
}

/// Orchestrates pull (Supabase → local Drift) + push (local → Supabase).
///
/// MVP scope:
/// - **Push:** transactions + items + linked inventory_movements + customers
///   (driven by the outbox table). Idempotent via UUID v7 + ON CONFLICT DO NOTHING.
/// - **Pull:** user auth context only — current `app_users` row,
///   `user_branch_access`, accessible `branches`. Master data (products,
///   inventory, recipes, settings) deferred to a later iteration.
///
/// Server is the authoritative source for `cached_stock` (updated by trigger
/// 008). Outbox payload only carries the id; this repo re-fetches from local
/// Drift at push time so the local DB stays the single source of truth.
class SyncRepository {
  SyncRepository(this._ref);

  final Ref _ref;
  final Logger _log = Logger();

  AppDatabase get _db => _ref.read(databaseProvider);

  SupabaseClient? get _sb {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ── PULL ────────────────────────────────────────────────────────────────────

  /// Pulls the auth context (user row + branch access + branches) for [userId].
  /// Called right after Supabase signin so the existing `_resolveAppUser` lookup
  /// against local Drift succeeds for first-time logins on this device.
  Future<bool> pullMyAuthContext(String userId) async {
    final sb = _sb;
    if (sb == null) {
      _log.w('[Sync] no supabase — skip pullMyAuthContext');
      return false;
    }

    try {
      final dao = _ref.read(branchDaoProvider);

      // 1. app_users row
      final userJson = await sb
          .from('app_users')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (userJson == null) {
        _log.w('[Sync] user $userId not found in app_users on Supabase');
        return false;
      }
      await dao.upsertUser(appUserFromJson(userJson));

      // 2. user_branch_access rows
      final accessRows = await sb
          .from('user_branch_access')
          .select()
          .eq('user_id', userId);
      final accessList = (accessRows as List).cast<Map<String, dynamic>>();
      for (final row in accessList) {
        await dao.upsertUserBranchAccess(userBranchAccessFromJson(row));
      }

      // 3. Branches the user has access to
      final branchIds =
          accessList.map((r) => r['branch_id'] as String).toList();
      if (branchIds.isNotEmpty) {
        final branchesJson = await sb
            .from('branches')
            .select()
            .inFilter('id', branchIds);
        final branches =
            (branchesJson as List).cast<Map<String, dynamic>>();
        for (final json in branches) {
          await dao.upsertBranch(branchFromJson(json));
        }
      }

      _log.i('[Sync] pulled auth context for $userId '
          '(${accessList.length} access rows)');
      return true;
    } catch (e, st) {
      _log.e('[Sync] pullMyAuthContext failed', error: e, stackTrace: st);
      return false;
    }
  }

  /// Pulls master/operational data for the given branches:
  /// - products (chain-wide; RLS filters)
  /// - branch_products (scoped to branchIds)
  /// - inventory_items + product_recipes (scoped)
  /// - receipt_settings (scoped)
  /// - customers (chain-wide)
  ///
  /// Conflict resolution: master data uses LWW (server `updated_at` wins) via
  /// `insertOnConflictUpdate`. Inventory cached_stock comes from server
  /// (authoritative — reconciled by trigger 008).
  Future<({int upserted, int errors})> pullMasterData(
    List<String> branchIds,
  ) async {
    final sb = _sb;
    if (sb == null) {
      _log.w('[Sync] no supabase — skip pullMasterData');
      return (upserted: 0, errors: 0);
    }
    if (branchIds.isEmpty) return (upserted: 0, errors: 0);

    var upserted = 0;
    var errors = 0;

    // ── products (chain-wide) ──
    try {
      final rows = await sb.from('products').select();
      final catalogDao = _ref.read(catalogDaoProvider);
      for (final json in (rows as List).cast<Map<String, dynamic>>()) {
        await catalogDao.upsertProduct(productFromJson(json));
        upserted++;
      }
    } catch (e) {
      _log.w('[Sync] pull products failed', error: e);
      errors++;
    }

    // ── branch_products (scoped) ──
    try {
      final rows = await sb
          .from('branch_products')
          .select()
          .inFilter('branch_id', branchIds);
      final catalogDao = _ref.read(catalogDaoProvider);
      for (final json in (rows as List).cast<Map<String, dynamic>>()) {
        await catalogDao.upsertBranchProduct(branchProductFromJson(json));
        upserted++;
      }
    } catch (e) {
      _log.w('[Sync] pull branch_products failed', error: e);
      errors++;
    }

    // ── inventory_items (scoped) ──
    try {
      final rows = await sb
          .from('inventory_items')
          .select()
          .inFilter('branch_id', branchIds);
      final invDao = _ref.read(inventoryDaoProvider);
      for (final json in (rows as List).cast<Map<String, dynamic>>()) {
        await invDao.upsertItem(inventoryItemFromJson(json));
        upserted++;
      }
    } catch (e) {
      _log.w('[Sync] pull inventory_items failed', error: e);
      errors++;
    }

    // ── product_recipes (scoped) ──
    try {
      final rows = await sb
          .from('product_recipes')
          .select()
          .inFilter('branch_id', branchIds);
      final invDao = _ref.read(inventoryDaoProvider);
      for (final json in (rows as List).cast<Map<String, dynamic>>()) {
        await invDao.upsertRecipe(productRecipeFromJson(json));
        upserted++;
      }
    } catch (e) {
      _log.w('[Sync] pull product_recipes failed', error: e);
      errors++;
    }

    // ── receipt_settings (scoped) ──
    try {
      final rows = await sb
          .from('receipt_settings')
          .select()
          .inFilter('branch_id', branchIds);
      for (final json in (rows as List).cast<Map<String, dynamic>>()) {
        await _db
            .into(_db.receiptSettings)
            .insertOnConflictUpdate(receiptSettingFromJson(json));
        upserted++;
      }
    } catch (e) {
      _log.w('[Sync] pull receipt_settings failed', error: e);
      errors++;
    }

    // ── customers (chain-wide) ──
    try {
      final rows = await sb.from('customers').select();
      final custDao = _ref.read(customerDaoProvider);
      for (final json in (rows as List).cast<Map<String, dynamic>>()) {
        await custDao.upsertCustomer(customerFromJson(json));
        upserted++;
      }
    } catch (e) {
      _log.w('[Sync] pull customers failed', error: e);
      errors++;
    }

    _log.i('[Sync] master pull — $upserted upserted, $errors errors');
    return (upserted: upserted, errors: errors);
  }

  /// Pulls recent transactions (+ items + linked inventory_movements) for the
  /// given branches. Used so transactions made on other devices show in the
  /// local Transaksi screen.
  ///
  /// MVP: last [limit] transactions ordered by client_created_at DESC, no
  /// incremental cursor yet. Inventory cached_stock is NOT recomputed from
  /// pulled movements — `pullMasterData` already grabs server's authoritative
  /// cached_stock via inventory_items.
  Future<({int upserted, int errors})> pullTransactions(
    List<String> branchIds, {
    int limit = 100,
  }) async {
    final sb = _sb;
    if (sb == null || branchIds.isEmpty) {
      return (upserted: 0, errors: 0);
    }

    var upserted = 0;
    var errors = 0;

    try {
      // ── transactions ──
      final txRows = await sb
          .from('transactions')
          .select()
          .inFilter('branch_id', branchIds)
          .order('client_created_at', ascending: false)
          .limit(limit);
      final txList = (txRows as List).cast<Map<String, dynamic>>();
      final txIds = txList.map((j) => j['id'] as String).toList();

      for (final json in txList) {
        await _db
            .into(_db.transactions)
            .insertOnConflictUpdate(transactionFromJson(json));
        upserted++;
      }

      if (txIds.isNotEmpty) {
        // ── transaction_items ──
        final itemRows = await sb
            .from('transaction_items')
            .select()
            .inFilter('transaction_id', txIds);
        for (final json
            in (itemRows as List).cast<Map<String, dynamic>>()) {
          await _db
              .into(_db.transactionItems)
              .insertOnConflictUpdate(transactionItemFromJson(json));
          upserted++;
        }

        // ── inventory_movements (reference_id = txId) ──
        final movRows = await sb
            .from('inventory_movements')
            .select()
            .inFilter('reference_id', txIds);
        for (final json
            in (movRows as List).cast<Map<String, dynamic>>()) {
          await _db
              .into(_db.inventoryMovements)
              .insertOnConflictUpdate(inventoryMovementFromJson(json));
          upserted++;
        }
      }

      _log.i(
          '[Sync] tx pull — ${txList.length} tx, $upserted total rows upserted');
    } catch (e, st) {
      _log.e('[Sync] pullTransactions failed', error: e, stackTrace: st);
      errors++;
    }

    return (upserted: upserted, errors: errors);
  }

  /// FEAT-006 — pull a pending invitation matching [email] so the local claim
  /// flow can fan it out into `app_users` + `user_branch_access`. Returns
  /// true when an invitation was upserted.
  Future<bool> pullPendingInvitationByEmail(String email) async {
    final sb = _sb;
    if (sb == null) return false;
    try {
      final json = await sb
          .from('pending_invitations')
          .select()
          .eq('email', email)
          .maybeSingle();
      if (json == null) return false;
      await _ref.read(branchDaoProvider).upsertPendingInvitation(
            pendingInvitationFromJson(json),
          );
      return true;
    } catch (e) {
      _log.w('[Sync] pullPendingInvitationByEmail failed', error: e);
      return false;
    }
  }

  // ── PUSH ────────────────────────────────────────────────────────────────────

  /// Drains the outbox in FIFO. Each item is routed by `entityType`:
  /// - transaction → push tx header + items + related inventory_movements
  /// - customer → push customer row (LWW)
  /// Children of a transaction (items, movements) are NOT enqueued
  /// separately — they ride on the parent push.
  Future<PushSummary> pushOutbox() async {
    final sb = _sb;
    if (sb == null) return const PushSummary(pushed: 0, failed: 0);

    final outboxDao = _ref.read(outboxDaoProvider);
    final pending = await outboxDao.getPendingItems(limit: 20);

    var pushed = 0;
    var failed = 0;

    for (final item in pending) {
      try {
        final payload = jsonDecode(item.payload) as Map<String, dynamic>;
        final id = payload['id'] as String;

        switch (item.entityType) {
          case OutboxEntityType.transaction:
            await _pushTransaction(id);
          case OutboxEntityType.customer:
            await _pushCustomer(id);
          case OutboxEntityType.branch:
            await _pushBranch(id);
          case OutboxEntityType.inventoryItem:
            await _pushInventoryItem(id);
          case OutboxEntityType.inventoryMovement:
            // Standalone movements (FEAT-005 manual adjustments) push here;
            // transaction-attached movements ride on parent push and are
            // marked done without a separate call (handled by the parent push
            // when this case fires for a tx child id, the lookup returns null
            // so we skip).
            await _pushInventoryMovementIfStandalone(id);
          case OutboxEntityType.appUser:
            await _pushAppUser(id);
          case OutboxEntityType.userBranchAccess:
            // payload carries both user_id + branch_id for the composite key
            await _pushUserBranchAccess(payload);
          case OutboxEntityType.pendingInvitation:
            await _pushPendingInvitation(id);
          case OutboxEntityType.optionGroup:
            await _pushOptionGroup(id);
          case OutboxEntityType.optionItem:
            await _pushOption(id);
          case OutboxEntityType.productOptionGroup:
            // payload carries both product_id + option_group_id
            await _pushProductOptionGroup(payload);
          case OutboxEntityType.transactionItem:
            // Children of a transaction; rides on parent push.
            break;
        }

        await outboxDao.markDone(item.id);
        pushed++;
      } catch (e, st) {
        _log.w('[Sync] push failed for ${item.id}', error: e, stackTrace: st);
        await outboxDao.markFailed(
          item.id,
          error: e.toString(),
          nextRetry: _nextRetry(item.attemptCount + 1),
        );
        failed++;
      }
    }

    if (pushed > 0 || failed > 0) {
      _log.i('[Sync] push done — $pushed ok, $failed failed');
    }
    return PushSummary(pushed: pushed, failed: failed);
  }

  Future<void> _pushTransaction(String txId) async {
    final sb = _sb!;
    final txDao = _ref.read(transactionDaoProvider);
    final tx = await txDao.getTransactionById(txId);
    if (tx == null) {
      throw StateError('Transaction $txId not found in local DB');
    }
    final items = await txDao.getItemsForTransaction(txId);

    // Push parent header — append-only on server (ADR-0001).
    await sb
        .from('transactions')
        .upsert(tx.toSupabaseJson(), ignoreDuplicates: true);

    if (items.isNotEmpty) {
      await sb.from('transaction_items').upsert(
            items.map((i) => i.toSupabaseJson()).toList(),
            ignoreDuplicates: true,
          );

      // FEAT-001 — push modifier snapshots for these items.
      final itemIds = items.map((i) => i.id).toList();
      final snapshots = await (_db.select(_db.transactionItemOptions)
            ..where((s) => s.transactionItemId.isIn(itemIds)))
          .get();
      if (snapshots.isNotEmpty) {
        await sb.from('transaction_item_options').upsert(
              snapshots.map((s) => s.toSupabaseJson()).toList(),
              ignoreDuplicates: true,
            );
      }
    }

    // Push related inventory_movements (reference_id = txId)
    final movements = await (_db.select(_db.inventoryMovements)
          ..where((m) => m.referenceId.equals(txId)))
        .get();
    if (movements.isNotEmpty) {
      await sb.from('inventory_movements').upsert(
            movements.map((m) => m.toSupabaseJson()).toList(),
            ignoreDuplicates: true,
          );
    }
  }

  Future<void> _pushCustomer(String customerId) async {
    final sb = _sb!;
    final dao = _ref.read(customerDaoProvider);
    final c = await dao.getById(customerId);
    if (c == null) {
      throw StateError('Customer $customerId not found in local DB');
    }
    // Customers use LWW — let upsert update existing rows.
    await sb.from('customers').upsert(c.toSupabaseJson());
  }

  Future<void> _pushBranch(String branchId) async {
    final sb = _sb!;
    final dao = _ref.read(branchDaoProvider);
    final b = await dao.getBranchById(branchId);
    if (b == null) {
      throw StateError('Branch $branchId not found in local DB');
    }
    await sb.from('branches').upsert(b.toSupabaseJson());
  }

  Future<void> _pushInventoryItem(String itemId) async {
    final sb = _sb!;
    final row = await (_db.select(_db.inventoryItems)
          ..where((i) => i.id.equals(itemId)))
        .getSingleOrNull();
    if (row == null) {
      throw StateError('InventoryItem $itemId not found in local DB');
    }
    await sb.from('inventory_items').upsert(row.toSupabaseJson());
  }

  Future<void> _pushInventoryMovementIfStandalone(String movementId) async {
    final sb = _sb!;
    final row = await (_db.select(_db.inventoryMovements)
          ..where((m) => m.id.equals(movementId)))
        .getSingleOrNull();
    if (row == null) return; // child of a tx already pushed via parent
    await sb
        .from('inventory_movements')
        .upsert(row.toSupabaseJson(), ignoreDuplicates: true);
  }

  Future<void> _pushAppUser(String userId) async {
    final sb = _sb!;
    final dao = _ref.read(branchDaoProvider);
    final u = await dao.getUserById(userId);
    if (u == null) {
      throw StateError('AppUser $userId not found in local DB');
    }
    await sb.from('app_users').upsert(u.toSupabaseJson());
  }

  Future<void> _pushUserBranchAccess(Map<String, dynamic> payload) async {
    final sb = _sb!;
    final userId = payload['user_id'] as String;
    final branchId = payload['branch_id'] as String;
    final action = payload['action'] as String? ?? 'upsert';
    if (action == 'delete') {
      await sb
          .from('user_branch_access')
          .delete()
          .eq('user_id', userId)
          .eq('branch_id', branchId);
      return;
    }
    final q = _db.select(_db.userBranchAccesses)
      ..where((a) => a.userId.equals(userId))
      ..where((a) => a.branchId.equals(branchId));
    final row = await q.getSingleOrNull();
    if (row == null) return;
    await sb.from('user_branch_access').upsert(row.toSupabaseJson());
  }

  Future<void> _pushPendingInvitation(String invitationId) async {
    final sb = _sb!;
    final row = await (_db.select(_db.pendingInvitations)
          ..where((i) => i.id.equals(invitationId)))
        .getSingleOrNull();
    if (row == null) {
      // Deleted locally (likely claimed) — propagate delete to server.
      await sb.from('pending_invitations').delete().eq('id', invitationId);
      return;
    }
    await sb.from('pending_invitations').upsert(row.toSupabaseJson());
  }

  Future<void> _pushOptionGroup(String groupId) async {
    final sb = _sb!;
    final row = await (_db.select(_db.optionGroups)
          ..where((g) => g.id.equals(groupId)))
        .getSingleOrNull();
    if (row == null) {
      await sb.from('option_groups').delete().eq('id', groupId);
      return;
    }
    await sb.from('option_groups').upsert(row.toSupabaseJson());
  }

  Future<void> _pushOption(String optionId) async {
    final sb = _sb!;
    final row = await (_db.select(_db.menuOptions)
          ..where((o) => o.id.equals(optionId)))
        .getSingleOrNull();
    if (row == null) {
      await sb.from('options').delete().eq('id', optionId);
      return;
    }
    await sb.from('options').upsert(row.toSupabaseJson());
  }

  Future<void> _pushProductOptionGroup(Map<String, dynamic> payload) async {
    final sb = _sb!;
    final productId = payload['product_id'] as String;
    final groupId = payload['option_group_id'] as String;
    final action = payload['action'] as String? ?? 'upsert';
    if (action == 'delete') {
      await sb
          .from('product_option_groups')
          .delete()
          .eq('product_id', productId)
          .eq('option_group_id', groupId);
      return;
    }
    await sb.from('product_option_groups').upsert({
      'product_id': productId,
      'option_group_id': groupId,
    });
  }

  /// Exponential backoff: 1s, 5s, 30s, 5m, 30m, then plateau (master prompt §9.4).
  DateTime _nextRetry(int attemptCount) {
    const delaysSec = [1, 5, 30, 300, 1800];
    final idx = (attemptCount - 1).clamp(0, delaysSec.length - 1);
    return DateTime.now().add(Duration(seconds: delaysSec[idx]));
  }
}

final syncRepositoryProvider = Provider<SyncRepository>(
  SyncRepository.new,
);
