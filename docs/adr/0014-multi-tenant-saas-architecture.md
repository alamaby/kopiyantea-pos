# ADR-0014: Multi-Tenant SaaS Architecture

- **Status:** Accepted
- **Date:** 2026-06-13
- **Deciders:** Project owner

## Context

The current app is an offline-first POS for one business chain. It already has branches, branch access, Supabase RLS, Drift local storage, and an outbox-based sync flow. That model is not enough for SaaS because several tables are effectively global across all authenticated users, including products, categories, customers, modifiers, bank accounts, and company settings.

The target product is a SaaS POS where a new user signs up, enters business information, and receives an organization with a main branch. The first owner gets a free 30-day plus trial. After login, the owner can complete catalog, stock, modifiers, receipt settings, and related setup. The product must support free and plus plans, monthly or yearly billing, transaction and catalog limits, plus-only features, paid additional branches, and two employee invite slots for each paid plus branch. The app also needs to become more generic than an F&B-only Kopiyantea app.

## Decision

Introduce `organizations` as the tenant boundary. All business data must be scoped either directly by `organization_id` or indirectly through a branch that belongs to an organization.

The high-level ownership model becomes:

```text
auth.users
  -> app_users
  -> organization_members
  -> organizations
  -> branches
  -> branch-scoped operational data
```

### Tenant Tables

Add `organizations`:

```text
id
name
business_type
address
phone
owner_user_id
default_timezone
status
trial_ends_at
created_at
updated_at
```

Add `organization_members`:

```text
organization_id
user_id
role: owner, admin, manager, cashier
status: active, invited, inactive
created_at
updated_at
```

`app_users` remains the app-level user profile mirror for `auth.users`, but authorization moves from global role to organization membership. Existing `global_role` becomes legacy compatibility during migration and should not remain the primary SaaS authorization source.

`branches` receives:

```text
organization_id
is_main
```

Tables that are currently chain-wide receive direct `organization_id`, including:

```text
products
categories
option_groups
options
product_option_groups
customers
bank_accounts
company_settings
pending_invitations
```

Tables already scoped by `branch_id` continue to rely on branch ownership for tenant isolation:

```text
branch_products
inventory_items
inventory_movements
product_recipes
receipt_settings
transactions
transaction_items
transaction_item_options
shift_closings
held_orders
customer_point_ledger
```

If a branch-scoped table has heavy query paths that frequently need organization filters, adding a redundant `organization_id` is allowed after the core migration, but the first migration should prefer the minimal safe boundary.

### Subscription and Entitlements

Add plan and subscription tables:

```text
subscription_plans
organization_subscriptions
branch_subscriptions
usage_counters
entitlement_events
```

`subscription_plans` defines free and plus limits:

```text
code: free, plus
monthly_price
yearly_price
max_products
max_monthly_transactions
max_branches_included
max_employees_per_paid_branch
features
is_active
```

`organization_subscriptions` stores the organization's current plan state:

```text
organization_id
plan_code
status: trialing, active, past_due, canceled, expired
billing_period: monthly, yearly
trial_ends_at
current_period_start
current_period_end
provider
provider_subscription_id
```

`branch_subscriptions` stores paid branch add-ons. Each active plus branch add-on grants two employee invite slots for that branch unless a future plan overrides the count.

`usage_counters` stores period-based counters for limit checks, especially transaction count and catalog/product count snapshots. Historical data is never deleted when limits are exceeded.

The app pulls an entitlement snapshot after login and sync:

```text
plan code
subscription status
trial end
feature flags
limits
usage
branch add-on status
invite quota
```

The client can use that snapshot for offline UX, but server-side RLS or RPC checks remain authoritative for tenant isolation and plan-gated writes.

### Signup and Onboarding

New tenant creation must be performed by a backend function or RPC, not by scattered client writes. The function must run in one database transaction:

1. Validate authenticated user.
2. Upsert `app_users`.
3. Insert `organizations`.
4. Insert owner `organization_members`.
5. Insert main `branches` row.
6. Insert `user_branch_access` for the main branch.
7. Insert default `company_settings` and branch `receipt_settings`.
8. Insert plus trial `organization_subscriptions` with `trial_ends_at = now() + interval '30 days'`.
9. Return `organization_id`, `main_branch_id`, and entitlement snapshot.

This keeps first signup atomic and avoids users who exist without a usable organization or branch.

### RLS Direction

ADR-0007 remains valid in spirit, but the helper functions must become organization-aware:

```text
current_user_is_org_member(organization_id)
current_user_org_role(organization_id)
current_user_has_branch_access(branch_id)
branch_org_id(branch_id)
current_user_can_manage_org(organization_id)
current_user_can_manage_branch(branch_id)
```

Business data policies must never rely on all-authenticated access. Policies such as `USING (TRUE)` for tenant business data are not acceptable in the SaaS model.

The expected rule set:

- Organization members can read their organization.
- Owner/admin can manage organization settings and billing.
- Owner/admin can manage branches if entitlement allows it.
- Manager can manage assigned branch operational data.
- Cashier can read assigned branch catalog and insert transactions for themselves.
- Transactions and transaction items remain append-only. Voids remain compensating transactions.
- Subscription expiry or downgrade blocks new writes/features where required, but never deletes historical data.

### Migration Strategy

Follow ADR-0008 strictly. The migration is expand-then-contract:

1. Add new tables.
2. Add nullable `organization_id` columns.
3. Backfill existing data into one default organization.
4. Add indexes and foreign keys.
5. Update app and sync to read/write organization-aware data.
6. Rewrite RLS after staging verification.
7. Enforce `NOT NULL` only after backfill and client compatibility are confirmed.
8. Drop legacy role assumptions only after a soak window.

Production must not receive experimental RLS/schema changes directly. Use a separate Supabase staging project because free tier does not provide Supabase branching.

### Local App and Sync

Drift schema receives matching tenant tables and columns. `AuthedSession` should carry:

```text
user
organizationId
activeBranchId
entitlementSnapshot
```

`SyncRepository` must pull auth context in this order:

1. app user
2. organization memberships
3. organizations
4. user branch access
5. branches
6. entitlement snapshot
7. master data scoped to organization and accessible branches

Outbox payloads for organization-scoped entities must include `organization_id` or resolve it from the local row before push. Push order should prioritize organization, membership, branch, and settings before catalog and transactions.

### Product Generalization

The product should stop assuming all tenants are F&B. Use `business_type` to select terminology presets:

```text
fnb: menu, modifier, recipe, receipt
retail: product, variant/add-on, stock, receipt
service: service, add-on, order, receipt
generic: product, option, inventory, receipt
```

The default UI copy should use generic words like business, catalog, product, branch, and receipt. Kopiyantea-specific names and assets should become demo/seed data or tenant branding, not the SaaS product identity.

## Consequences

**Positive:**

- Strong tenant isolation is enforced by database boundaries and RLS.
- Existing branch-based offline-first model can be preserved.
- Subscription and plan logic can evolve without rewriting core POS data.
- Trial, downgrade, and over-limit flows are non-destructive.
- The app can serve F&B, retail, service, and generic small businesses.

**Negative:**

- This is a large multi-stage migration touching Supabase, Drift, sync, auth, settings, and UI.
- RLS complexity increases because roles are no longer global.
- Offline limit handling requires careful UX because the client can be temporarily stale.
- Existing unique constraints must be reworked to be organization-scoped.

## Alternatives Considered

- **Separate Supabase project per tenant.** Rejected for operations; migrations, support, and analytics become difficult.
- **Schema-per-tenant in one Postgres.** Rejected for this stage; heavy migration and tooling burden.
- **Only add subscription tables without organization boundary.** Rejected because it does not prevent cross-tenant data exposure.
- **Client-only entitlement checks.** Rejected because billing and tenant isolation must not depend on trusted clients.
