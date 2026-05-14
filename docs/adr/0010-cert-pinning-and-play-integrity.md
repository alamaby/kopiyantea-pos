# ADR-0010: Cert Pinning and Play Integrity

- **Status:** Accepted
- **Date:** 2026-05-14
- **Deciders:** Project owner

## Context

The app handles money and ships to staff phones whose threat surface includes:

- **MITM via rogue CA / corporate proxy / fake Wi-Fi.** A trusted system CA does not imply the connection is safe.
- **Modified APKs sideloaded** with stripped checks (e.g., re-signed to remove price validations, or to send transactions to a different backend).
- **Brute force on login** from a stolen device or a script targeting the auth endpoint.

These are real attacker profiles for a chain handling daily cash receipts.

## Decision

Layered device-and-transport integrity:

### 1. Certificate pinning (transport)

- All Supabase HTTP traffic flows through a `dio` client with `http_certificate_pinning` adapter.
- Pin is **SHA-256 of the server certificate**, declared via env var `SUPABASE_CERT_FINGERPRINTS` (comma-separated, supports rotation overlap).
- Enabled in `production`. In `development` and `staging`, the same code path runs with `staging` fingerprints to keep parity.
- Rotation procedure: ship an app release containing **both** old and new fingerprints before the server cert flips, drop old after the rollout window (Section 14 risk #9).
- Pinning failure = hard error. No "trust on first use," no user override.

### 2. Device attestation (modified-APK defense)

- **Android: Play Integrity API.** Token requested before any "sensitive operation" — initial login, void transaction, owner-only catalog edits. Verified server-side via a Supabase Edge Function.
- **iOS: App Attest.** Same trigger surface, verified server-side.
- Failure handling: sensitive operation blocked; non-sensitive POS flow continues for a previously-attested session. The verdict is cached per session, not per request, to keep cashier flow snappy.
- Encapsulated behind `DeviceIntegrityService` (master prompt §10.3) so platforms are pluggable and a `FakeDeviceIntegrityService` exists for dev/tests.

### 3. Brute-force defense (auth)

- Supabase native rate limiting on auth endpoints.
- App-side counter on `app_users.failed_login_count`; on reaching `branches.failed_login_lockout_threshold` (default 5), set `app_users.locked_until` to `now() + 15 minutes`. Successful login resets the counter.
- Lockout state is enforced server-side in the auth function, not by the client.

### 4. Secrets at rest

- Auth tokens live exclusively in `flutter_secure_storage` (Keychain / Keystore).
- Service role key is never in the app bundle, never in CI artifacts that ship to devices.

## Consequences

**Positive:**
- Rogue-CA MITM, modified APKs, and credential-stuffing scripts each have a meaningful barrier.
- Defense is layered; defeating one layer doesn't yield the rest.
- Rotation is a planned procedure, not a fire drill.

**Negative:**
- Every cert rotation requires an app release (Section 14 risk #9). Overlap pinning mitigates the cliff but doesn't eliminate it.
- Play Integrity has its own quotas and failure modes; we treat it as advisory for non-sensitive flow.
- More moving parts in `main.dart` initialization (pinned HTTP client built before Supabase init). Tradeoff accepted.

## Alternatives Considered

- **Public-key pinning instead of cert pinning.** Slightly more rotation-friendly but harder tooling story; we chose cert pinning + overlap.
- **SafetyNet (deprecated).** Replaced by Play Integrity — not viable.
- **Roll our own device fingerprint.** Easily defeated; not an attestation.
- **No pinning, rely on system trust only.** Rejected: the threat model includes rogue CAs.
