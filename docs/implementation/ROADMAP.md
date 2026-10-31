# Implementation roadmap

Source of truth for status: `PROGRESS.md`. Decisions and open questions: `DECISIONS.md`. API contract: `docs/api/`.
Statuses: TODO, IN PROGRESS, DONE, BLOCKED (reason), PARTIAL (what is missing).

The backend is an external API (see DECISIONS F-02). Staging validation needs a host, test accounts and the Cloudflare Access answer (DECISIONS backend questions 4, 9); until then every staging/device check is BLOCKED and only unit-testable work is done.

| Phase | Scope | Depends on | Acceptance | Status |
|---|---|---|---|---|
| 0 | Release hygiene: Android `INTERNET`, release endpoint validation, opt-in debug fallbacks, DI override seam, test config | none | analyze clean, non-golden tests green | DONE |
| A | Baseline, docs, CLAUDE.md | 0 | docs exist and are accurate; baseline recorded | DONE |
| B | Security/config: backup flags, validate in non-dev builds, debug bypass gated, logging, remove local PII (drafts, searches) | A | tests for each change; no PII persisted locally | DONE |
| C | Transport + session foundation: Dio, encrypted cookie jar, in-memory token, single-flight refresh, correct error parsing, logout/cleanup, cache isolation | B | deterministic unit tests (refresh races, replay once, no refresh retry on timeout, cleanup) | DONE (staging validation BLOCKED) |
| D | Auth integration: `login`, `verifyOtp`, `me`, `refresh` restore, `logout`, 2FA enrollment states, pending/suspended | C | unit and widget tests; no broken login/restore in between | DONE (staging validation BLOCKED) |
| E | Feature integration against the real contract, in slices: E1 home/notifications read, E2 requests read + detail, E3 booking (catalog, dynamic fields, server drafts, review, submit), E4 wallet, E5 support, E6 agents/team/profile, E7 reports/ads (optional) | D | per slice: data source matches the contract, states covered, tests | IN PROGRESS (E1 home, ads, reports remain; E2-E6 DONE) |
| F | Files: multipart upload (Content-Length, 8 MiB, types), signed-URL download on a separate client, passport reading | C, E3 | tests with a stub adapter; nothing sensitive persisted/logged | PARTIAL (upload client, booking documents, info_required upload, receipts, signed download DONE; passport reading, avatar and ticket attachments TODO) |
| G | Business rules, permissions fail-closed, state consistency, duplicate-action guards | E | regression tests | TODO |
| H | Reliability/performance review: lifecycle, polling, pagination, cache bounds | E | measured/demonstrated fixes only | TODO |
| I | Full verification, builds, release-readiness report | all | analyze, full tests (goldens controlled), builds, report | TODO |

## Unsupported by the contract (never faked)
Hospital picker with capacity, group manifest, remind approver, notify-me, notification preferences, disabling an agency's own staff user, team invitations, sub-agent credit-limit edit (read-only by design), app-status/force-update/request-access, SMS/OTP recovery and phone change, push notifications. They keep their existing "unavailable" behavior until a product decision.
