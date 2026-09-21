# Multi-Org Internal — Iterasi Phase I Design Spec

> Date: 2026-06-16  
> Approach: Foundation First (Join Org + Local Isolation + Sync Scoped)  
> Status: Draft — awaiting user review

---

## 1. Context & Problem Statement

RBAC multi-org (FEAT-002) sudah **DONE DEV** di level infrastruktur:

- `organizations`, `organization_members`, `subscription_plans`, `organization_subscriptions` tables di Supabase + Drift.
- Semua RLS policy di-rewrite dengan `organization_id` awareness.
- Onboarding flow `create org` sudah berfungsi.

Namun ada **tiga gap kritis** yang membuat multi-org tidak fungsional di praktik:

1. **Join Org Flow = placeholder** — `JoinOrgScreen` hanya menampilkan form kode 8-char, submit = snackbar "belum tersedia". User yang sudah sign-in tidak bisa bergabung ke org existing.
2. **No local data isolation on org switch** — Local Drift tidak di-purge saat user switch org via `OrganizationSwitcherBottomSheet`. Data produk, transaksi, cabang dari org lama tetap tampil di UI sampai bootstrap baru selesai (racy + leak).
3. **Sync tidak scoped per org aktif** — `pullMasterData` iterasi berdasarkan `user_branch_access`, bukan `organization_id`. Kalau user member di >1 org, data dari semua org ikut ter-pull.

---

## 2. Goals

| # | Goal | Success Criteria |
|---|---|---|
| G1 | User yang sudah sign-in bisa join org existing via 8-char invitation code | Kode generate → claim → org member → onboarding complete |
| G2 | Switch org = atomic purge data lokal + bootstrap fresh org baru | Tidak ada data org lama yang tampil setelah switch |
| G3 | Sync master data strict ter-filter ke `organization_id` aktif | `pullMasterData` tidak return row dari org lain |

Non-goal (out of scope iterasi ini):
- Payment gateway / billing otomatis.
- Usage enforcement (limit produk/transaksi per plan).
- Trial expiry enforcement.
- Client-side entitlement gating UI.

---

## 3. Section 1 — Join Org via Invitation Code

### 3.1 Overview

Owner generate kode undangan (dalam app). User baru yang sudah sign-in masukkan kode → claim → jadi member org → bootstrap data org → masuk POS.

Kode undangan dibedakan dari existing `pending_invitations` (email-based, untuk user belum punya akun):
- **Email-based invitation** → untuk user baru. Path: owner invite email → user sign up with that email → claim otomatis via `resolveSessionWithClaim` (sudah ada).
- **Code-based invitation** → untuk user sudah punya akun. Path: owner generate code → share lisan/WA → user sign in → onboarding → join via code → claim.

### 3.2 Database Schema Changes

**Supabase migration** (non-destructive, `add column if not exists`):

```sql
-- Alter pending_invitations untuk support open code-based invites
alter table public.pending_invitations
  add column if not exists join_code text,
  add column if not exists invite_type text not null default 'email'
    check (invite_type in ('email', 'code')),
  add column if not exists max_uses integer not null default 1
    check (max_uses >= 1),
  add column if not exists used_count integer not null default 0
    check (used_count >= 0);

-- Unique constraint: kode unik per org
alter table public.pending_invitations
  add constraint pending_invitations_org_code_uq
    unique nulls not distinct (organization_id, join_code);

-- Partial index untuk mencari kode fast

create index if not exists pending_invitations_code_idx
  on public.pending_invitations (join_code)
  where invite_type = 'code';
```

**RLS for code-based invites** — policy sudah ada (owner-write). Kode-based row juga di-cover karena RLS menggunakan `organization_id` (bukan email).

### 3.3 Server — Claim Function

**Supabase Edge Function / RPC:** `claim_invitation_code`

Input: `{ p_code: text, p_user_id: uuid }`
Steps:
1. Find row `pending_invitations` where `join_code = p_code`, `invite_type = 'code'`, `status = 'active'`, and (`expires_at IS NULL` or `expires_at > now()`).
2. Lock row (SELECT FOR UPDATE).
3. Check `used_count < max_uses`. Return `'already_exhausted'` if not.
4. Upsert `organization_members` (`organization_id`, `user_id`, `role`, `status='active'`).
5. Increment `used_count` on `pending_invitations`.
6. If `used_count >= max_uses`, set `status = 'consumed'`.
7. Return `{ organization_id, organization_name, role }`.

Error returns:
- `'not_found'` → kode tidak ada.
- `'expired'` → kode melewati expiry.
- `'already_exhausted'` → semua slot sudah habis.
- `'already_member'` → user sudah member di org tsb.

### 3.4 Flutter — Join Org Flow

#### 3.4.1 New / Modified Files

| File | Action | Description |
|---|---|---|
| `lib/features/onboarding/join_org_screen.dart` | **Rewrite** | Replace placeholder dengan claim flow functional. |
| `lib/features/onboarding/create_invite_code_screen.dart` | **New** | Owner generate code: pilih role, pilih branch access, set max uses, set expiry. |
| `lib/features/auth/auth_repository.dart` | **Extend** | Tambah `claimJoinCode({required String code})`. |
| `lib/core/sync/sync_repository.dart` | **Reuse** | Setelah claim sukses, panggil `pullMyAuthContext` + `pullMasterData`. |
| `lib/features/onboarding/onboarding_screen.dart` | **Minor** | Tambah entry untuk "Masuk via kode undangan" (segmen yang berbeda dari create org). |

#### 3.4.2 JoinOrgScreen Rewrite

State machine:
- **Idle** — form kode + tombol claim.
- **Loading** — spinner, tombol disabled.
- **Error** — banner dengan pesan error (`not_found` / `expired` / dll).
- **Success** — navigate to `/bootstrap` (markPending) agar data org baru di-pull.

Validation client:
- Kode 8-char alphanumeric, case-insensitive (auto-uppercase input).

Submit flow:
```
JoinOrgScreen._onClaim
  → AuthRepository.claimJoinCode(code)
    → Supabase RPC claim_invitation_code
    ← returns { orgId, orgName, role }
  → OrganizationDao.upsertOrganizationMember(...)
  → Auth.completeOnboarding(organizationId: orgId)
  → BootstrapProvider.markPending()
  → Router redirect /bootstrap
```

#### 3.4.3 CreateInviteCodeScreen (Owner-Only)

Settings → SettingsScreen owner-only section → "Kode Undangan" entry.

Form:
- **Role** — Dropdown `cashier` / `manager` (owner/admin only).
- **Branch Access** — Multi-select dari active branches di org ini.
- **Max Uses** — Numeric 1–99, default 1.
- **Expiry** — Date picker, default 7 hari.
- **Generated code** — readonly, auto-generate 8-char alphanumeric. Copy button (share ke clipboard).

Submit flow:
```
CreateInviteCodeScreen._onGenerate
  → AuthRepository.generateJoinCode({role, branchIds, maxUses, expiresAt})
    → Validate owner/admin permissions (org-level)
    → Generate random 8-char via dart `Random.secure()`
    → Supabase INSERT pending_invitations (invite_type='code', join_code, ...)
    ← Return code string
  → Show success with copy button
```

### 3.5 Testing Criteria

1. Owner generate code (cashier, 1 use, 7 hari) → kode tampil → bisa dicopy.
2. User lain sign in → onboarding → tap Join → masukkan kode → success → bootstrap org baru → POS muncul.
3. User coba kode yang salah → error "Kode tidak valid".
4. User coba kode yang sudah dipakai (max_uses = 1) → error "Kode sudah habis".
5. Owner lihat list kode aktif + used count.

---

## 4. Section 2 — Local Data Isolation on Org Switch

### 4.1 Problem

User A di Org X memiliki 50 produk + 200 transaksi di local Drift. User switch ke Org Y via `OrganizationSwitcherBottomSheet`. Saat ini:
- `authProvider` update `organizationId` → UI rebuild.
- Semua provider Stream `watch()` tetap emit row-row lama dari Org X karena Drift belum di-purge.
- Data Org X masih tampil sampai bootstrap baru selesai → racy, confusing, dan data leak.

### 4.2 Solution — Atomic Switch + Purge + Bootstrap

#### 4.2.1 AppDatabase.clearOrganizationData()

New method di `AppDatabase`. **Note:** Drift default naming convention adalah `snake_case` class name → table name. Verify table names in generated `app_database.g.dart` if any drift migration renamed them.
```dart
Future<void> clearOrganizationData() async {
  // Delete in dependency order (child → parent)
  await customStatement('DELETE FROM transaction_item_options');
  await customStatement('DELETE FROM transaction_items');
  await customStatement('DELETE FROM inventory_movements');
  await customStatement('DELETE FROM product_recipes');
  await customStatement('DELETE FROM branch_products');
  await customStatement('DELETE FROM product_option_groups');
  await customStatement('DELETE FROM options');
  await customStatement('DELETE FROM option_groups');
  await customStatement('DELETE FROM categories');
  await customStatement('DELETE FROM products');
  await customStatement('DELETE FROM inventory_items');
  await customStatement('DELETE FROM receipt_settings');
  await customStatement('DELETE FROM bank_accounts');
  await customStatement('DELETE FROM customer_point_ledger');
  await customStatement('DELETE FROM customers');
  await customStatement('DELETE FROM user_branch_access');
  await customStatement('DELETE FROM branches');
  await customStatement('DELETE FROM organization_members');
  await customStatement('DELETE FROM organization_subscriptions');
  await customStatement('DELETE FROM organizations');
  // Retain: app_users (global identity), subscription_plans (master table),
  // outbox (global queue), shift_closings (per-device only, can clear if needed),
  // held_orders (per-device), usage_counters/entitlement_events (server-managed).
}
```

Order penting: referential integrity. Drift foreign key constraints harus di-honor. Urutan: child tables first → parent last.

#### 4.2.2 AuthProvider.switchOrganization()

New public method:
```dart
Future<Result<Unit, String>> switchOrganization(String newOrgId) async {
  final current = state;
  if (current is! Authenticated) return Err('not_authenticated');
  if (current.organizationId == newOrgId) return Ok(Unit.instance);

  // 1. Show global loading indicator (not handled here; UI calls this inside
  //    a blocking modal).
  // 2. Clear local org-scoped data.
  await _db.clearOrganizationData();
  // 3. Update auth state with new org.
  state = AuthState.authenticated(
    user: current.user,
    branchId: current.branchId,  // will be replaced during bootstrap
    organizationId: newOrgId,
  );
  // 4. Trigger bootstrap re-pull.
  ref.read(bootstrapProvider.notifier).markPending();
  return Ok(Unit.instance);
}
```

#### 4.2.3 UI — OrganizationSwitcherBottomSheet

Modify `OrganizationCard._openSwitcher` untuk menampilkan full-screen blocking dialog:

1. Tap card → buka bottom sheet listing org yang user miliki.
2. Tap org lain → tampilkan `AlertDialog` konfirmasi: "Beralih ke [Nama Org]? Data lokal akan dimuat ulang."
3. Jika OK → tampilkan fullscreen `ModalBarrier` + `CircularProgressIndicator` (blocking UI selama purge + bootstrap).
4. `Auth.switchOrganization(newOrgId)` → setelah return → router auto-redirect `/bootstrap` karena bootstrap state = pending.
5. Setelah bootstrap selesai → router redirect `/pos`.

Edge cases:
- **User kill app di tengah purge** → next cold start: session restore (orgId baru), bootstrap pending → `/bootstrap` aman.
- **Bootstrap failure** → screen error → "Coba Lagi" / "Kembali ke Org Lama". Butuh tombol "Kembali" yang mengarahkan ke org sebelumnya (revert).

### 4.3 Testing Criteria

1. User di Org X → buat 3 transaksi → lihat di TransactionList.
2. Switch ke Org Y → TransactionList kosong (bukan 3 transaksi Org X).
3. Checkout 1 transaksi di Org Y → TransactionList Org Y tampil 1 item.
4. Switch balik ke Org X → TransactionList Org X tampil 3 item (re-pull dari server).
5. Matikan internet sebelum switch → error bootstrap → user bisa tap "Kembali ke Org Lama".

---

## 5. Section 3 — Sync Scope = Org Aktif

### 5.1 Problem

`SyncRepository.pullMasterData(List<String> branchIds)` tidak menerima `organizationId`. Query Supabase-nya:

```sql
-- existing pattern (phasenya branch-scoped)
SELECT * FROM products WHERE is_active = true;
```

Karena RLS `products_select` menggunakan `current_user_is_org_member(organization_id)`, user yang member di Org A dan Org B bisa lihat produk dari **kedua org** (RLS allow). Sync pull mengambil semua produk yang user visible, bukan hanya org aktif.

### 5.2 Fix — Explicit org_id Filter di Server Queries

Tiga pendekatan:

| Approach | Pros | Cons |
|---|---|---|
| A. Server filter (recommended) | Client passthrough `orgId`, server WHERE. Consistent, single source of truth. | Requires migration update pada sync queries. |
| B. Client-side filter | No server changes. Client skip row dengan orgId mismatch. | Inefficient — bandwidth + parsing row yang nggak dipakai. |
| C. RLS restrictive | RLS filter hanya allow org aktif + tambah `current_active_org_id()` helper. | Tidak support multi-org membership simultan (user nggak bisa switch backward tanpa re-auth). |

**Pilih Approach A.**

#### 5.2.1 SyncDTO Extension

All pull methods in `SyncRepository` extend with `required String organizationId`:

```dart
Future<SyncResult> pullMasterData({
  required List<String> branchIds,
  required String organizationId,  // NEW
}) async { ... }

Future<SyncResult> pullTransactions({
  required List<String> branchIds,
  required String organizationId,  // NEW
  int limit = 100,
}) async { ... }
```

#### 5.2.2 Supabase Query Update

Replace unscoped SELECT dengan `eq('organization_id', orgId)`:

```dart
// Products
final productJson = await sb
  .from('products')
  .select()
  .eq('organization_id', organizationId)  // NEW
  .order('name');

// Categories
final categoryJson = await sb
  .from('categories')
  .select()
  .eq('organization_id', organizationId);  // NEW

// Customers
final customerJson = await sb
  .from('customers')
  .select()
  .eq('organization_id', organizationId);  // NEW

// Branches — custom filter karena branch tidak punya org_id FK langsung
// (sudah punya org_id dari migration 20260613110000).
final branchJson = await sb
  .from('branches')
  .select()
  .eq('organization_id', organizationId)   // NEW
  .eq('is_active', true);

// Bank accounts
final bankJson = await sb
  .from('bank_accounts')
  .select()
  .eq('organization_id', organizationId);  // NEW

// Option groups, options, product_option_groups
each .eq('organization_id', organizationId)
```

**Branch-scoped tables** (inventory_items, receipt_settings, branch_products, product_recipes, transactions, transaction_items, transaction_item_options, inventory_movements):
- These tables do NOT have `organization_id` column directly.
- Scope via JOIN: query where parent `branch_id` belongs to org aktif.
- Simpler: filter `branchIds` list — client-side ensure `branchIds` hanya dari branches dalam org aktif.
- Ensure: `BranchDao.getBranchesForOrg(organizationId)` menghasilkan branchIds yang valid.

Actually, `branches` sudah punya `organization_id`. Saat `pullMyAuthContext`, org data di-pull beserta accessible branches. `branchIds` yang diteruskan ke `pullMasterData` harus sudah ter-filter ke org tersebut.

Fix lebih sederhana:
```dart
// In bootstrap / sync flow
final accessibleBranches = await branchDao.getBranchesForOrg(organizationId);
final branchIds = accessibleBranches.map((b) => b.id).toList();

// Pass these filtered branchIds to pullMasterData / pullTransactions.
// Branch-scoped tables automatically limited karena mereka query WHERE branch_id IN (branchIds).
```

Jadi cukup filter `branchIds` + filter chain-wide tables (`products`, `categories`, `customers`, `option_groups`, `options`, `bank_accounts`) dengan `.eq('organization_id', orgId)`.

### 5.3 Testing Criteria

1. Setup: User member di Org A (produk: Latte, Cappuccino) dan Org B (produk: Pizza, Pasta).
2. User switch ke Org A → pullMasterData → local Drift hanya ada Latte & Cappuccino.
3. User switch ke Org B → pullMasterData → local Drift hanya ada Pizza & Pasta.
4. Verifikasi: tidak ada row `products` dengan org_id mismatch di local Drift setelah setiap switch.

---

## 6. Files Affected Summary

| # | File Path | Action | Section |
|---|---|---|---|
| 1 | `supabase/migrations/20260616_add_code_invite.sql` | New | §3.2 |
| 2 | `supabase/functions/claim_invitation_code/index.ts` | New | §3.3 |
| 3 | `supabase/functions/generate_join_code/index.ts` | New | §3.3 |
| 4 | `lib/features/onboarding/join_org_screen.dart` | Rewrite | §3.4.2 |
| 5 | `lib/features/onboarding/create_invite_code_screen.dart` | New | §3.4.3 |
| 6 | `lib/features/auth/auth_repository.dart` | Extend | §3.4 |
| 7 | `lib/core/database/app_database.dart` | Extend | §4.2.1 |
| 8 | `lib/features/auth/auth_provider.dart` | Extend | §4.2.2 |
| 9 | `lib/features/settings/organization_card.dart` | Extend | §4.2.3 |
| 10 | `lib/core/sync/sync_repository.dart` | Modify | §5.2 |
| 11 | `lib/features/settings/settings_screen.dart` | Extend | §3.4.3 (owner entry) |
| 12 | `lib/router.dart` | Verify | — routing mendukung nested onboarding |
| 13 | `lib/l10n/arb/app_id.arb` / `app_en.arb` | Extend | New strings |

---

## 7. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Purge data lokal terlalu agresif → user kehilangan data offline | Purge hanya org-scoped tables. Outbox tetap di-retain (sync queue global). Shift closings, held orders lokal di-per-org tapi tidak kritis. |
| Switch org di tengah transaksi aktif (cart tidak kosong) | `OrganizationCard._openSwitcher` cek cart state terlebih dahulu. Jika cart tidak kosong → dialog warning: "Keranjang belanja akan hilang. Lanjutkan?" |
| Claim code gagal network → user stuck di onboarding | Error banner dengan tombol "Kembali" ke `/onboarding`. User bisa coba lagi atau create org sendiri. |
| Kode undangan brute-force (menebak 8-char) | Rate limiting: max 5 attempts per 10 menit per IP di Edge Function. Kode 8-char = 2.8T kombinasi, tidak feasible. |
| Multiple user pakai kode yang sama (max_uses > 1) race condition | Edge Function pakai `SELECT FOR UPDATE` pada claim row. Serialisasi claim. |
| Supabase index baru belum ada di production migration | Migration idempotent — `add column if not exists`, `create index if not exists`. |

---

## 8. Acceptance Criteria (Definition of Done)

- [ ] Supabase migration applied & idempotent (`supabase db push` clean on fresh DB).
- [ ] Edge Functions deployed dan callable dari Flutter client.
- [ ] Owner bisa generate kode undangan dengan role, branch access, max uses, expiry.
- [ ] User baru bisa sign in → onboarding → join via kode → jadi org member.
- [ ] `dart analyze` zero errors.
- [ ] Manual E2E: switch org → data lokal tampil kosong sementara → setelah bootstrap selesai, hanya data org baru yang tampil.
- [ ] Manual E2E: sync master data untuk org A tidak mengandung produk/cabang org B.
- [ ] ARB strings extracted (id_ID + en_US).
- [ ] `build_runner` run clean (Freezed / Drift regen ok).

---

*Spec written: 2026-06-16  
Next step: Implementation plan via `writing-plans` skill.*
