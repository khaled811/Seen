# Decisions log

Statuses: DECIDED, ASSUMED (safe default applied, revisit), OPEN (needs an owner).

## Verified project facts

| ID | Fact | Evidence |
|---|---|---|
| F-01 | The repo is a standalone Flutter app (Flutter 3.22.2, Dart 3.4.3). No backend source is present. | Repo root holds only Flutter/platform folders, `docs/`, `lib/`, `test/`. |
| F-02 | The backend is an **external GraphQL-over-HTTPS API**. Laravel and Filament are not involved. | `docs/api/mobile-api.md`. The contract mentions `backend/schema.graphql`, `manage.py export_schema` and SimpleJWT, which suggests Python/Django. That is an inference only and must not be relied on. |
| F-03 | `AuthResult.refreshToken` is always null. `sb_refresh` is an HttpOnly host-only cookie (`Path=/`, `SameSite=Strict`, `Secure` in staging/prod, `Max-Age=86400`), set or rotated by `login` (no 2FA), `verifyOtp`, `completeOtpEnrollment` and `refresh`. 1-day sliding, 7-day absolute cap. Replaying a rotated token ends the session. | Backend developer answers (recorded 2026-10-19). |
| F-04 | Every GraphQL response is HTTP 200; errors are in `errors[].extensions.code`. | Backend answers, contract sections 2 and 4. |
| F-05 | `submitRequest` and `cancelRequest` take no `idempotencyKey`; after an ambiguous timeout read the request state before acting. Only `requestTopUp`, `submitTopUp`, `topUpSubAgent`, `reclaimFromSubAgent` and `openWalletAdjustmentTicket` take one. | Reference + backend answers. |
| F-06 | Email enrollment/verification/reset/email-change links open web pages. No native deep links exist. | Backend answers. |
| F-07 | Booking drafts and traveler/document personal data must not be persisted locally. Only non-personal draft metadata (draft id, service id) may be kept. | Backend answers. |
| F-08 | `gql_http_link` 0.4.5 requires `http ^0.13.0`, so `http` stays pinned. Dio does not depend on `http`. | `gql_http_link-0.4.5/pubspec.yaml` in the pub cache. |

## Decisions

| ID | Date | Decision | Rationale |
|---|---|---|---|
| D-01 | 2026-10-19 | Phase 0: debug fallbacks are opt-in (`USE_DEBUG_FALLBACKS`), DI has an override seam, release requires an https `GRAPHQL_ENDPOINT`, Android `INTERNET` added. | Fallbacks hid real failures. |
| D-02 | 2026-10-19 | Transport: a Dio client with a cookie manager and a secure-storage-backed cookie jar sits under the existing `HttpLink` through an `http.BaseClient` adapter. `GraphQLService`, repositories, use cases and Blocs keep their signatures. | Smallest change. Dio keeps `Set-Cookie` as a list (the `http` package flattens it) and has a cookie manager. Subject to the package-source verification recorded in PROGRESS.md. |
| D-03 | 2026-10-19 | API contract copies live in `docs/api/`. | The originals are outside the repo; copies keep the contract available to every session. |
| D-04 | 2026-10-19 | Phase B: drafts and recent searches are in-memory only; legacy keys are purged at launch; the debug auth bypass needs `USE_DEBUG_FALLBACKS`; Android `allowBackup=false`. | Backend rule F-07; plugin guidance on backup restores. |
| D-05 | 2026-10-19 | Phase C: `cookie_jar` does not enforce `Secure` over http and sends expired Secure cookies over https (source read), so the app wraps it (`StrictPersistCookieJar`) and forbids non-https endpoints outside debug. Cookies persist only in `flutter_secure_storage`. A fresh install wipes cookie entries (iOS Keychain outlives the app). | Verified in `cookie_jar` 4.0.9 source; tests cover each guarantee. |
| D-06 | 2026-10-19 | A refresh is never retried after an ambiguous failure; a rejected one (`session_expired`, `no_refresh_session`, `not_authenticated`) ends the session; any other answer leaves it alone. HTTP 401/403 from a proxy never ends a session. | Rotation is not assumed idempotent; the API answers application errors with HTTP 200. |
| D-07 | 2026-10-19 | Phase D: the app signs in with an **e-mail** only (`login(email, password)`); the app never receives the enrollment token and never asks for it. Enrollment, e-mail verification and reset are web pages (F-06), so `enrollmentRequired` / `enrollmentCodeRequired` / `enrollment_link_required` show a message telling the person to finish setup with the e-mailed link. | Contract section 3.1 and F-06. |
| D-08 | 2026-10-19 | The session is built only from `me` (id, `agentPosition`, `permissions`, agency present). An account without an agency (Seen staff) is refused. An unknown position or empty permissions yields a session with no abilities. `branchId` is null (not in the contract's `User`). | Server-authoritative permissions; fail closed. |
| D-09 | 2026-10-19 | The second step is an authenticator code or a recovery code in the same argument; the API has no resend, so the resend row is replaced by a "use a recovery code" link (existing design-system text field and link). | Contract section 3.1. |
| D-11 | 2026-10-19 | Money: amounts are `Decimal` strings on the wire and integer cents in the app; the amount field accepts plain digits with at most two decimals; every money mutation carries an idempotency key that is reused only for the same details. | Contract section 2 and 6. |
| D-12 | 2026-10-19 | Contract guard: documents sent by data sources are validated in tests against the reference (`test/support/contract_schema.dart`). | Catches wrong operations, fields and types without a server. |
| D-10 | 2026-10-19 | Failures are shown with the app's own localized text keyed by code or failure type (`localizedFailureMessage`), never the server's message. | Contract section 4. |

| D-13 | 2026-10-19 | Booking: the app files a draft on the server only when the person continues (or saves a complete draft); changed data creates a new draft because the contract has no edit/remove-traveler operation (the old draft is left on the server: drafts cannot be cancelled, D-16, answered 2026-10-21). A timeout while adding travelers cancels the draft (never resent) to avoid duplicate travelers. | Contract 10.2; D-11 style "never blindly retry". |
| D-14 | 2026-10-19 | `submitRequest` has no idempotency key: a timeout/5xx is reconciled by reading the request; only a non-draft status counts as sent. The confirmation shown is `referenceCode` (re-read twice if empty), never the internal id. | Contract 10.2 step 7. |
| D-15 | 2026-10-19 | Medical services are listed but not bookable: neither `createDraftRequest` nor `addTraveler` carries a hospital, and dropping the choice silently would be wrong. | Contract has no hospital field (see P-06). |
| D-16 | 2026-10-19 | Drafts are the server's (`portalRequests(group: draft)`); SUPERSEDED 2026-10-21: the backend confirmed a draft cannot be cancelled or deleted (`cancelRequest` refuses it), so the app offers no delete and no discard; no client retention rule is shown. | Contract 10.3; removes the invented 30-day cleanup. |
| D-17 | 2026-10-20 | Notifications carry no server text: titles and bodies are worded from the structure (`eventType`, payload). Push does not exist (contract 14): the permission screen stays, the unread count polls every 45 s on the account screen only. | Contract 6 and 14. |
| D-18 | 2026-10-20 | Password recovery sends a link to the e-mail (`requestPasswordReset`); registration is one `registerMainAgent` call after password and terms (the marketing consent is not sent: no field); the minimum password is 12 characters (contract). | Contract section 3. |
| D-19 | 2026-10-20 | Sub-agent funding: `topUpSubAgent` with one idempotency key per user action, reused only after a dropped connection (never after an answer); after success both balances are read again, nothing is computed on the device. | Contract 2, D-11. |
| D-20 | 2026-10-20 | Sub-agent controls follow the server's `canFund`/`canSuspend`/`canActivate`; absent flags fail closed. The suspension reason typed in the dialog is not sent (`setAgentStatus` has no reason). | Contract `PortalSubAgent`; permissions are the server's. |
| D-21 | 2026-10-20 | Team: users are created with an e-mail and a first password (`createStaffUser`), not invited; a user's role is the only thing that can change (`updateUserRole`). Disabling, enabling, resending and cancelling invitations are not offered. | Contract has no such operations (P-06). |
| D-22 | 2026-10-20 | Branches are flat: the API's `Branch` has id, name and manager only, so counts are absent, the people of a branch are its manager, and "main branch" styling applies to every row. | Contract `Branch`. |
| D-23 | 2026-10-21 | Profit margins are per sub-agency: Account > Profit margin first asks which sub-agency, then edits the margins of the services **enabled** for it (`setAgentServiceEnablement`, one call per changed service, stopping at the first refusal; the figures are read again afterwards). A fixed margin is shown as the amount above the agency's own price (the API stores a price); a percentage is `markupPercent`. A margin edit never switches a service on or off. | Backend answer 2026-10-21; supersedes the earlier "unavailable" decision. |
| D-24 | 2026-10-20 | The home promo banner is the server's (`activeAds`, `home_banner`): nothing shows when there is no ad, and the button shows only for an `https` link (anything else is not opened). The static placeholder banner copy is no longer used. | Contract `activeAds`; a promotion made up by the app would be a business claim. |
| D-25 | 2026-10-20 | A feature the API does not have is answered `unsupported_operation` and the screen says "not available yet" instead of offering a retry (group manifest, issued-approval list for the airline circular, "notify me"). The entry points stay as designed. | Retrying can never work; no Figma change. |
| D-26 | 2026-10-20 | Support tickets and replies can carry one staged file (`kind=ticket_attachment`, then `attachmentFileId`), sent when picked and referred to by id; a reply sends its file once. | Contract 8 / 12. |
| D-27 | 2026-10-20 | `RolePermissions` fails closed: a signed-in session whose position is unknown or missing has no abilities. "No session in scope" (tests, pre-sign-in) is still "all", the server stays the authority. | CLAUDE.md "unknown or missing permissions fail closed". |
| D-28 | 2026-10-20 | Ending a session also clears the branch scope (the branch the previous person was viewing) and the recent searches. | Cache isolation between accounts. |
| D-29 | 2026-10-20 | Home "needs attention" count is the server's (`portalRequests.attention.count`), not a count of the loaded page. The account card shows the agency's name from `portalAccount` once read. | Contract. |
| D-30 | 2026-10-21 | The airline circular is an ordinary service: the custom approval screen was removed. "Copy the details of an earlier request" (`prefillCandidates` / `prefillFromRequest`) appears on the traveler form only when the server lists candidates; values fill the matching fields, nothing is sent until the person continues. | Backend answer 2026-10-21. |
| D-31 | 2026-10-21 | Ticket status: `closed` and `cancelled` are final (read-only, no reopen); replying to a `resolved` or `waiting` ticket reopens it on the server, so those keep the composer. The app has no reopen operation. | Backend answer 2026-10-21. |
| D-32 | 2026-10-21 | A sub-agency's own funding requests (`pendingSubAgentTopUps`) are decided in the approvals screen: approve asks first (money leaves the main agent's wallet), one decision at a time, the list is read again after a lost connection. Reclaiming money from a sub-agency (`reclaimFromSubAgent`) is a sheet on its profile with one idempotency key per action. | Contract section 9. |
| D-33 | 2026-10-21 | Home service tiles come from `portalHome.services`; the static tiles (and the invented "hotels" tile) are gone. Ads are counted (`recordAdImpression` once per showing, `recordAdClick` on a tap). | Contract section 10.1. |
| D-34 | 2026-10-22 | **Two-step verification (design/gaps SEC).** In-app enrollment is built (`beginOtpEnrollment`, `confirmOtpEnrollment`, `regenerateRecoveryCodes`), which reverses D-07 for enrollment from Settings (the login-time "enrollment required" case still sends the person to the e-mailed link). Status comes from `me` and shows as on when either `otpEnabled` or `twoFactorEnrolled` is true (backend lag after a confirm). The secret and the recovery codes stay in the cubit's memory only. There is **no "turn off" row**: the contract only has an administrator's `resetUser2fa`. The QR is drawn by the one new package, `qr_flutter`. | Contract reference (OtpEnrollmentResult, RecoveryCodesResult). |
| D-35 | 2026-10-22 | **Change e-mail (ACC).** `requestEmailChange(newEmail, currentPassword, locale)`; the change is confirmed from the e-mailed web link. The server never says whether an address is taken, has no resend and no `pendingEmail`, so the screen after sending is just "check your e-mail" (open the mail app, edit the address); there is no "pending" row state and no resend. | Contract reference. |
| D-36 | 2026-10-22 | **Reveal masked values (PRIV).** The portal traveler reads carry no value ids, so the request detail also reads `request(id) { travelers { fieldValues } }` for which values are sensitive (a clear text that arrives is masked at once and dropped). `revealFieldValue(fieldValueId)` is audited; one value at a time, 30 s, hidden when the app goes to the background or the screen is left, never stored, Android `FLAG_SECURE` while visible (channel in `MainActivity`). "Seen the notice" is kept on the device (the server has no flag). Only the request detail shows travelers' sensitive values today: the booking review (`PortalReviewTraveler.passportNumber`) and the manifest have no value ids, so they are untouched. | Contract reference and guide 10, 12. |
| D-37 | 2026-10-22 | **Profile photo (PROF).** Stage with `/files/upload/`, then `setMyAvatar(fileId)`; `removeMyAvatar`. The cropped photo is a 512 x 512 **PNG** (no JPEG encoder without a new package); the limit checked on the device is 5 MB and JPG/PNG. A temp file goes through the uploader and is deleted. There is no "cancel upload" (the upload client has no cancellation). The photo address is short-lived and cleared when the session ends. | Contract reference, RULE 8. |
| D-38 | 2026-10-22 | **Support (SUP).** `rateTicket(ticketId, rating)` once, resolved or closed tickets (no comment: the server takes none; the server has no field saying a ticket was rated, so a rated ticket shows its locked state only when `already_rated` comes back). Categories come from `ticketCategories` (no explanation text exists); «Other» (`general`) is always last and the only choice when the list fails to load; the picked `code` is sent as `openGeneralTicket(category)`. Unread: `unreadTicketsCount` for Home's badge, `Ticket.unreadCount` for the "new messages (n)" divider (the contract has no per-message flag); no "mark all as read" (no such operation) and no extra caption above the list (not in the allowed changes). | Contract reference. |
| D-39 | 2026-10-22 | **Passport reading (PASS).** `POST /files/read-passport/` (JPEG/PNG, `request.submit`); the answer has no confidence number, so the server's `checked` flag decides what starts selected. The photo is taken with the system camera (no `camera` package, so no live viewfinder: the capture screen shows the frame guide) or chosen from the gallery, sent once and deleted. Values go through the existing `TravelerPrefillApplied` event (only keys the form asks for). Hidden by the flag `kEnablePassportScan`. Not built: a thumbnail of the photo (it is deleted), focusing the first empty field. | Guide 8.3. |
| D-40 | 2026-10-22 | **Reports (REP), partly.** Built: the result screen (table with a sticky first column and totals, empty / too many rows / error / no-permission states), the export sheet (csv, xlsx, pdf as base64), `Capability.reports` (`report.create`). **Not built:** the source picker, the builder and the Account entry, because the contract does not publish the structure of `spec` or of `agentReportCatalog` (Q34); there are no report jobs and no 7-day file list in the contract either. | Contract reference, Q34. |

## Backend questions still open

1. Is there a short grace window for reusing a just-rotated refresh token (lost-response recovery)?
2. What does `logout` return when the session is already expired, and does it send a deleting `Set-Cookie`?
3. Are multiple concurrent devices per user allowed? Which events besides `changeMyPassword` sign out all sessions?
4. Is staging/production behind Cloudflare Access? Which headers and cookies does it add, and what is the approved automation mechanism?
5. Does `refresh` have a rate limit?
6. Is there an `Origin`/CSRF check on cookie-based `refresh` that a native client would fail?
7. (Answered by a probe, 2026-10-21: `POST /graphql` without the slash answers 405, no redirect; the app keeps the slash.)
8. Which host serves signed download URLs?
9. Can staging lifetimes be shortened for testing? Which test accounts exist (2FA, enrollment-required, pending, suspended, Main/Sub agent, staff)?
10. `User` has no branch field: how does a branch-limited user learn their branch?
11. Define `PortalWalletSummary.balance`, `held`, `total`, `spendable`, `creditUsed` exactly (the app shows them as sent; it assumes `balance` is the available amount and `held` the amount on hold).
12. Valid `submitTopUp` `method` values (the app assumes `bank_transfer`, `cash`, `exchange_house`) and which `accountKinds` each maps to.
13. Is there an agent code the agent quotes at an exchange house / cash desk (the design shows one; the contract has none)?
15. Which request statuses belong to the groups `new` and `processing` (the dashboard's "pending / under review" chip shows `processing` only; are `submitted` and the two approval statuses in `new`?).
16. The vocabulary of `PortalTimelineStep.key` (the app maps a key only when it equals a request status).
17. Is there an API to filter requests by branch (the agent can choose a branch in the account area)?
18. Draft limits and lifetime: how many drafts may an agency hold and when does the server delete an abandoned one (the app shows no number)?
19. `PortalDraftReview.errors` and `violations`: the vocabulary of codes and the shape of `violations` (the app shows one generic "cannot be submitted yet" message and keeps only the codes).
20. Can `cancelRequest` always cancel a draft (and is a cancelled draft hidden from `portalRequests(group: draft)`)? Is there a way to remove a draft's traveler or document (replace a wrong file)?
21. A hospital for medical services: which operation carries it?
22. Where does a ticket's subject live, and what are the notification `eventType` / kind vocabularies (needed for notifications and support)?
23. What does the `file` `fieldType` of a service field mean (the app drops it and relies on `documents`)?
14. Rejected top-ups: `portalWallet` lists only pending and posted movements. Where can the app read a rejected top-up and its reason?
24. `updateUserRole(userId, position, branchId = null)`: does omitting `branchId` clear the user's branch? (the app omits it when only the role changes, and sends it when moving a user.) May the same position be re-sent just to change the branch?
25. `topUpSubAgent` returns a `Wallet`: whose (the caller's or the sub-agency's)? (the app ignores it and reads both balances again.)
26. `portalAgents` hides `balance` (null) for some callers: which, and what should the app show? (it shows 0.)
27. `createStaffUser` / `createSubAgent`: the password rules beyond `password_weak` and the 12-character minimum; may a main agent set another person's first password (the app collects it)?
28. (Answered 2026-10-21: the credit limit is read-only by design; margins are per sub-agency.)
29. `too_many_travelers` is 50 on the server while the Figma UI limits a booking to 9 travelers; which one is the product rule?
30. Agency documents (commercial register, tourism licence with expiry) and the agency manager's name: where can the app read them? (the agency screen shows neither today.)
31. (Answered by building it into the approvals screen, D-32; the design owner should confirm the placement.)
32. What may `ctaLink` of an ad contain (https URL, an in-app route, a phone link)? The app opens only `https` links.
33. Is an ad image meant to be shown on the home banner (`imageUrl` is a short-lived signed link)? The approved banner has no image slot.
34. `agentReportCatalog` and `runAgentReport(spec)` take and return JSON without a published structure. What does the catalog look like (sources, fields, filters, groupings) and what must `spec` contain (source, columns, period, filters, totals, grouping)? Also the layout of `rows` and `totals` (an object per row by column key, or a list)? Without this the report builder cannot be built.
35. `Ticket` has no rating field: can it expose `rating` / `ratedAt` so a rated ticket shows its locked card when reopened, and may `rateTicket` take an optional comment?
36. `PortalReviewTraveler` and `PortalTrackedTraveler` carry no `FieldValue` ids: can the traveler reads expose them (and `isMasked` for the passport number) so the booking review can offer the reveal too?
37. Is there an operation for the signed-in user to turn two-step verification off (today only `resetUser2fa` for an administrator)? And does `confirmOtpEnrollment` set `otpEnabled` (it looked like it did not)?
38. E-mail change: can `me` expose `pendingEmail` and can there be a resend (`resendEmailChange`)? Both are in the design.
39. Support: a per-message `isUnread` on `TicketMessage` (the divider now uses `Ticket.unreadCount`), a bulk "mark all tickets read", and a `description` or `explanation` on `TicketCategory`.
40. Reports: report jobs for long periods and a list of recent exported files (kept 7 days) are in the design but not in the contract.
41. Is there a push or a faster signal than polling for the unread-ticket count?

### Backend round 2 (answered 2026-10-21) and what the app does
- **Host:** `b2b.seenbooking.com` is production with a periodic reset: testing is allowed with no real money, no real WhatsApp and no real traveler data; real agency accounts stay off limits.
- **Drafts** cannot be cancelled or deleted: no delete/discard in the app. An edit after save leaves an orphan draft. Backend ask: a `discardDraft` operation.
- **Travelers:** the product limit is 50 (`too_many_travelers`); the app uses `maxTravelersPerRequest = 50` (Q29 answered).
- **Passwords:** `password_weak` carries `params.rule`; each rule has its own message (Q27 answered).
- **Permissions** come from `me.permissions` codes (role defaults plus individual grants/revocations); missing or unknown codes grant nothing (fail closed).
- **Balance:** `portalAgents.balance` may be null: the app shows a dash, never 0 (Q26 answered).
- **Top-up methods:** bank_transfer, cash, exchange_house, e_wallet. `topUpSubAgent` result is ignored; both balances are read again (Q25).
- **Ads:** `ctaLink` is https or a whitelisted `/agent/...` path; other values are not opened (Q32 answered).
- **Notification kinds** are mapped (`InAppNotificationDto`): the 16 listed kinds map to event types; `generic` and unknown stay neutral.
- **Manifest / airline circular:** parked, not reachable from the UI.
- **New asks for the backend:** `discardDraft`; `me.branch`; branch request counts and a branch filter; `rejectReason` for rejected top-ups (Q14); whether `updateUserRole` clears the branch when `branchId` is omitted (Q24); `confirmOtpEnrollment` returns `otp_enabled` wrongly (2FA enrollment stays web-only until fixed).

## Product decisions

- P-01 Local drafts: removed. Drafts are the server's (`createDraftRequest`, `portalRequests(group: draft)`); a draft can be saved only with every traveler complete, and the leave-form sheet says so. **DONE** (was ASSUMED).
- P-02 Recent searches: in memory only. **ASSUMED.**
- P-03 Email-link flows are web pages. The invented in-app SMS/OTP recovery and phone-change flows have no backend and must show an unavailable state rather than fake success. **ASSUMED.**
- P-04 Certificate pinning: not implemented. **OPEN.**
- P-05 Cloudflare Access credential policy for internal builds. **OPEN.**
- P-06 Unsupported features (hospital picker, manifest, airline circular submit, remind approver, notify-me, notification preferences, user deactivation, team invitations, credit-limit edit, per-service margin screen, ticket reopen, app-status/force update): never faked. Hide-or-redesign decisions **OPEN**; current behavior is the existing "unavailable" states.
- P-07 Screenshot / app-switcher blur on sensitive screens. **OPEN.**
- P-08 Sign-in is by e-mail only. The Figma login field says "phone or email" and the helper text promises a verification code by message. The field keeps its design; a phone number shows a banner asking for the e-mail address, and the invalid-credentials copy now says "email or password". The OTP header copy for authenticator accounts says the code comes from the authenticator app. Recommendation: either the backend adds phone sign-in or the design changes the field. **OPEN** (needs the product owner; current behavior is safe).
- P-09 Launch while offline: a failed or ambiguous refresh signs nobody in and keeps the cookie, so the person sees Welcome/Login and must retry online. A dedicated "cannot reach the server, retry" state at launch would be a new screen state. **ASSUMED** (no new UI).
- P-10 In-app account recovery (forgot password with a code), registration with a phone code and phone-number change use operations that do not exist; they are handled with the other unsupported features in the feature-integration phase.
- P-11 Built on 2026-10-22 (design/gaps): in-app 2FA enrollment, reveal of masked values, e-mail change, profile photo, passport reading, ticket rating / categories / unread, and the report result / export (D-34..D-40). **Still open:** the report builder and Reports entry (Q34), `revealFieldValue` on the booking review (Q36), turning 2FA off (Q37), e-mail change resend / pending (Q38), enabling a service for a sub-agency. **OPEN.**
