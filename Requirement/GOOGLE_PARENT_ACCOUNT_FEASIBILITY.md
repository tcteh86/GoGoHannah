# Feasibility Review: Parent Account + Google Login + Google Drive + Scheduled Email Reports

## Request Summary
You asked for the following features:
1. Parent signs in with Google.
2. Child `progress.db` data is saved under the signed-in parent Google Drive.
3. Parent can create up to 5 child profiles.
4. Child profile data is stored under the parent account.
5. Parent can import `vocabulary.csv` from Google Drive and update it over time.
6. Parent receives daily or weekly report emails based on configuration.

## Current State (as of this review)
- The app currently has **no authentication** and identifies a learner by free-text `child_name`.
- The backend persists data in a local SQLite file (`progress.db`).
- Child records are in a `children` table and are not linked to any parent account.
- There is custom vocabulary storage, but no Google Drive integration.
- CSV parsing utility exists, but no endpoint/workflow wired to import from Drive.
- No scheduler/job runner is currently present for periodic email report delivery.

## Feasibility Assessment
**Overall feasibility: HIGH**, but this is a **multi-part integration** (OAuth + Drive API + schema migration + scheduled jobs + email delivery + UI updates). 

It is very feasible with the current FastAPI + Flutter architecture, but it is **not realistic to fully implement, test, and harden in 1 hour**.

## Estimated Implementation Size (LOC)
Rough estimate for a production-ready first version:

- **Backend (FastAPI + DB migration + Google APIs + scheduler + email):** ~900–1,500 LOC
- **Frontend (Flutter web auth flow, parent/child management, Drive import UX, settings):** ~500–900 LOC
- **Tests (unit/integration for auth, API, scheduler, report generation):** ~350–700 LOC
- **Infra/config/docs (env vars, setup notes, runbook):** ~100–250 LOC

**Total estimate:** **~1,850–3,350 LOC**.

> A thinner prototype can be done in fewer lines (~900–1,400 LOC), but with tradeoffs in security, reliability, and UX.

## Time Feasibility for "within 1 hour"
### Can complete entire feature set in 1 hour?
**No** (not responsibly).

### What can be completed in ~1 hour (realistic slice)
A meaningful vertical slice is possible, for example:
- Add DB schema for parent + child linkage and 5-child limit.
- Add placeholder auth abstraction + local mock parent session.
- Add API endpoints for child profile CRUD under parent.
- Add a basic report configuration model (daily/weekly).

This would **not** include finished Google OAuth, Drive sync, and robust scheduled email sending.

## Recommended Delivery Plan

### Phase 0 — Design & Security Baseline (0.5–1 day)
- Define identity model (`parent_accounts`, `children`, ownership constraints).
- Decide token strategy and secure storage.
- Define Drive storage strategy:
  - Option A: Store DB snapshot file on Drive AppData folder.
  - Option B: Keep DB server-side and sync/export/import per child as JSON/CSV.
- Decide scheduler mechanism (APScheduler / Celery + Redis / cloud scheduler).

### Phase 1 — Parent Accounts + Child Profiles (1–2 days)
- Implement Google OAuth login (backend callback + frontend sign-in).
- Persist parent identity (`google_sub`, email).
- Add child profile APIs and enforce max 5 children per parent.
- Migrate existing data model to parent-owned records.

### Phase 2 — Google Drive Integration (1.5–3 days)
- Implement Drive OAuth scopes + refresh token handling.
- Implement file strategy (folder naming, metadata, versioning).
- Add upload/download sync for child progress data.
- Add conflict handling and idempotent sync behavior.

### Phase 3 — Vocabulary CSV from Drive (0.5–1.5 days)
- List/select CSV files from parent Drive.
- Parse and validate CSV, then apply to selected child profile.
- Add update flow (replace vs append + audit timestamp).

### Phase 4 — Scheduled Email Reports (1–2 days)
- Add report settings (daily/weekly + timezone + send time).
- Generate per-child/per-parent summary payload.
- Send email via provider (e.g., SendGrid/SES/Postmark).
- Add retry/dead-letter/error logging and simple admin observability.

### Phase 5 — Testing & Hardening (1–2 days)
- Unit tests for auth, permissions, profile limits, CSV validation.
- Integration tests for Drive sync and report scheduling.
- Security checks, secrets handling, and deployment docs.

## Proposed Data Model Additions
- `parent_accounts(id, google_sub, email, display_name, created_at, updated_at)`
- `children(id, parent_id, name, created_at, archived_at)`
- `parent_integrations(id, parent_id, provider, access_token_enc, refresh_token_enc, scope, expires_at, created_at)`
- `drive_sync_state(id, child_id, drive_file_id, etag, last_synced_at, last_error)`
- `report_settings(id, parent_id, frequency[daily|weekly], timezone, send_hour, enabled)`
- `report_runs(id, parent_id, scheduled_for, status, sent_at, error)`

## Key Risks / Unknowns
- OAuth consent and Google verification requirements (especially sensitive scopes).
- Secure token storage + refresh token lifecycle.
- Sync conflict behavior between local DB and Drive copies.
- Reliable scheduling in your target hosting platform.
- Email deliverability and spam-domain setup (SPF/DKIM/DMARC).

## Suggested MVP Scope (fastest safe path)
If speed is priority, start with:
1. Parent Google login.
2. Parent-managed child profiles (max 5).
3. Server-side DB only (no Drive sync yet).
4. CSV import from local upload first.
5. Weekly email only first.

Then add Google Drive integration in next iteration.

## Release-Freeze Plan (Ship in 2 hours, implement in 1 hour)

If you must freeze today, implement only a **small, low-risk vertical slice** that gives parent-account structure without external integrations.

### Scope to implement now (target: ~1 hour coding + ~30 min validation)
1. **Parent-scoped child profiles in backend (max 5)**
   - Add `parent_id` field association model (or temporary table) and enforce `<=5` children per parent.
   - Keep parent identity simple for now using a temporary header or stub parent key (e.g., `X-Parent-Id`) to avoid full OAuth today.
2. **Child profile management endpoints**
   - `GET /v1/children`
   - `POST /v1/children` (with max-5 validation)
   - `DELETE /v1/children/{id}` (optional soft delete)
3. **Keep existing learning flow compatible**
   - Existing progress/vocab endpoints continue working, but now use selected child under parent scope.
4. **UI minimal patch**
   - Replace free-text start with a simple child selector + “Add child” dialog.
   - Validate 5-child limit in UI and backend.

### Explicitly defer (do not implement in this release)
- Google OAuth login.
- Google Drive sync/storage of `progress.db`.
- Drive picker/import for `vocabulary.csv`.
- Automated daily/weekly email scheduling and sending.

### Why this is the best freeze-safe cut
- Delivers real product value now: multi-child parent structure.
- Avoids risky external dependencies (OAuth, Drive, SMTP/scheduler) under time pressure.
- Keeps schema and API forward-compatible for future Google integration.

### Timebox breakdown (practical)
- **0:00–0:10**: DB migration + parent/child constraints.
- **0:10–0:30**: Add child profile APIs + max-5 checks.
- **0:30–0:50**: Minimal frontend child selector + add-child UX.
- **0:50–1:00**: Smoke tests and bug fix pass.
- **+30 min buffer**: QA + release packaging.

### Definition of Done for today
- Parent-scoped child profiles work end-to-end.
- Cannot create more than 5 children per parent.
- Existing practice/quiz/results still function for selected child.
- API and UI return clear error message when limit is exceeded.
- Basic tests or smoke checks pass for create/list/select child workflows.


## Implemented Quick-Win for Freeze
To support immediate parent backup and vocabulary portability during this release freeze, the following backend endpoints are suitable as quick wins:
- `GET /v1/progress/db-export`: download current `progress.db` backup file.
- `POST /v1/progress/db-import`: upload and replace current `progress.db`.
- `GET /v1/vocab/custom/export?child_name=...`: export child custom vocabulary as CSV.
- `POST /v1/vocab/custom/import`: import custom vocabulary CSV (`append` or `replace`).
- Optional shared-secret guard for DB transfer endpoints via `GOGOHANNAH_DB_EXPORT_TOKEN` + `X-DB-Export-Token` header.

This still does **not** replace Google Drive sync, but gives immediate manual import/export flows for freeze-day operations.
