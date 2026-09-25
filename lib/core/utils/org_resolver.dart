/// FEAT-002 Phase 8 — pure helper for stamping `organization_id` on rows
/// created from the UI.
///
/// Returns the trimmed org id when usable, or `null` when the caller must
/// abort the insert (org-aware RLS rejects NULL-org rows). Kept pure so it
/// is unit-testable without a database or Riverpod container.
String? resolveOrgForInsert(String? currentOrgId) {
  if (currentOrgId == null) return null;
  final trimmed = currentOrgId.trim();
  return trimmed.isEmpty ? null : trimmed;
}
