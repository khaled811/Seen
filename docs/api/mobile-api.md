# Seen Business — mobile API guide (agency users)

This is the contract for the **mobile app** (iOS and Android) that serves **agency users**: Owners, Branch Managers and Staff of a Main Agent or a
Sub-Agent. It covers only what an agency user can do. Everything for Seen staff (the operations portal, approvals, providers, supplier data,
Ad manager, legal editor, other agencies) is deliberately **not** documented here and is refused by the server if an agency token calls it.

Two files make the contract:

| File | What it is |
|---|---|
| **`mobile-api.md`** (this file) | How to talk to the API: sessions, errors, limits, files, the flows, the rules. Written by hand. |
| **`mobile-api-reference.md`** | Every operation an agency user may call (arguments, defaults, who may call it) and every type it returns, plus the error-code table. Generated from the schema. |

The full machine-readable schema is `backend/schema.graphql` (it also lists the Seen-only operations: use it for code generation, ignore them in
the app). **Introspection is turned off outside development**, so that file and the reference are how you learn the schema.

> The schema grows only by adding fields and operations; nothing is removed or renamed without telling you first. Treat an unknown field in a
> response as safe to ignore. Re-read the reference when you start a new screen.

---

## 1. Quick facts

| | |
|---|---|
| Protocol | GraphQL over HTTPS, JSON bodies |
| Endpoint | `POST https://<host>/graphql/` (trailing slash optional). **POST only**: a GET carrying a query is refused. |
| Files | `POST https://<host>/files/upload/` and `POST https://<host>/files/read-passport/` (multipart, not GraphQL) |
| Auth | `Authorization: Bearer <accessToken>` |
| Access token | lives **15 minutes** |
| Refresh | a rotating token held in an **httpOnly cookie** named `sb_refresh` (see section 3.4: this matters for a native app) |
| Hard session cap | **7 days** from sign-in, then the person signs in again |
| Languages | Arabic and English. Content has `…Ar` / `…En` fields; error codes are translated by the client |
| Money | `Decimal`, serialised as a string with 2 decimals (`"150.00"`), in the wallet currency (`currency` field, USD today) |
| Times | ISO 8601 with offset (`2026-10-18T14:03:00+00:00`), always UTC |
| IDs | UUID strings, typed `ID` |
| Push notifications | **not available yet**: poll (section 11) |
| Real time | no subscriptions or websockets |

Environments: each environment has its own host. Ask the platform team for the staging host and, later, the production host. Never point a
development build at production data.

---

## 2. Making a request

```http
POST /graphql/ HTTP/1.1
Host: <host>
Content-Type: application/json
Authorization: Bearer eyJ...            (omit for the public operations)

{
  "query": "query($limit: Int!) { portalRequests(group: \"all\", limit: $limit) { items { id referenceCode status } total hasMore } }",
  "variables": { "limit": 20 }
}
```

* Always send variables, never string-built queries (also keeps the query short: see the limits in section 5).
* A GraphQL failure is still **HTTP 200** with an `errors` array. Check `errors` before you read `data`.
* HTTP-level failures you can see: `405` (not POST), `413` (body too large), `429`/`5xx` from a proxy. Treat them as "try again later".
* Do not log request bodies or responses: they contain passport data and tokens.

### Operation kinds

* **Query** reads. Safe to repeat.
* **Mutation** changes state or issues a secret (even `revealFieldValue` and `documentDownloadUrl` are mutations, because they are audited). Run **at
  most 3 mutations in one request** and at most **15 query fields**.
* Mutations that move money take an optional `idempotencyKey: String`. **Always send one** (a UUID you generate once per user action and reuse on a
  retry). A retry with the same key never moves the money twice.

---

## 3. Authentication and sessions

### 3.1 Sign in

`login(email, password)` returns an `AuthResult`. Exactly one of these shapes comes back:

| You get | Meaning | Next |
|---|---|---|
| `accessToken` | Signed in | Store it in memory, call the API |
| `otpRequired: true` + `challengeId` | The account has two-step verification | `verifyOtp(challengeId, code)` with the 6-digit authenticator code, or (lost phone) one single-use recovery code like `xxxx-xxxx-xxxx`, within **5 minutes** |
| `enrollmentRequired: true` + `enrollmentToken` | The person must set up an authenticator now (reached through a one-time link) | `beginOtpEnrollment(enrollmentToken)` → show the QR / secret → `completeOtpEnrollment(enrollmentToken, code)`; this call returns the session **and the recovery codes, shown once** |
| `enrollmentCodeRequired: true` + `challengeId` + `emailHint` | After a 2FA reset the system e-mailed a code | `confirmEnrollmentCode(challengeId, code)`, then the enrolment steps above |

Sign-in errors you must handle: `invalid_credentials`, `agency_pending` (the agency is waiting for Seen's approval), `agency_suspended`,
`too_many_attempts` (wait), `otp_code_invalid`, `otp_challenge_invalid` (start again), `enrollment_link_required`.

```graphql
mutation Login($email: String!, $password: String!) {
  login(email: $email, password: $password) {
    accessToken otpRequired challengeId enrollmentRequired enrollmentToken enrollmentCodeRequired emailHint
  }
}
```

After any successful sign-in call `me` once: it carries the person, the agency and `permissions` (the list that drives your UI).

### 3.2 Sign up (a new agency)

`registerMainAgent(input)` is public. It creates a **pending** Main Agent and an Owner, and e-mails a confirmation link. The agency can sign in
only after the owner confirms the e-mail **and** Seen approves the agency. Required: `name`, `ownerFullName`, `ownerEmail`, `ownerPassword` (at
least 12 characters, not common, not like the name or e-mail), `acceptedTerms: true`. Also collect `city`, `licenseNumber`, `ownerPhone`.
Show the Terms and the Privacy policy from `legalPage(kind: "terms" | "privacy")` (`titleAr/En`, `bodyAr/En`, `version`) before the person accepts;
the server records the accepted versions. Body text is plain: blank line = new paragraph, a line starting `## ` is a heading, a line starting `- ` is a
bullet. Render it as text, never as HTML. `resendVerificationEmail(email, locale)` sends a new link and always answers the same.

There is no document upload at signup. Seen asks for the commercial registry during review.

### 3.3 Passwords, e-mail and recovery

* `requestPasswordReset(email, locale)` always answers the same (no account enumeration). The e-mailed link opens the **web** page
  `/<locale>/reset-password?...`; finish there or build a deep link to it. `confirmPasswordReset` completes it.
* `changeMyPassword(currentPassword, newPassword)` signs **every** session out (all devices): sign in again afterwards.
* `requestEmailChange(newEmail, currentPassword, locale)` e-mails a link to the **new** address; the change takes effect only when it is confirmed
  (`confirmEmailChange`, opened from the link). The old address is told.
* `updateMyProfile(fullName, phone)`, `setMyAvatar(fileId)`, `removeMyAvatar` (section 8 for the picture upload).

### 3.4 Tokens and refresh: read this before you build the networking layer

* The **access token** is returned in the response body. Keep it **in memory** (or the platform secure store), send it as `Bearer`.
* The **refresh token is never in the response body.** The server sets it as the cookie `sb_refresh` (`HttpOnly; Secure; SameSite=Strict; Path=/`,
  1 day, rotated on every refresh). To get a new access token call `refresh` with **no arguments**, the cookie being the credential.
* So the app **must use a persistent cookie jar for the API host**: `URLSession` with the shared `HTTPCookieStorage` on iOS, an `OkHttp`
  `CookieJar` backed by persistent storage on Android. Cookies are `Secure`: HTTPS only (no plain HTTP, not even in development builds
  against a real host).
* Refresh **before** the access token dies (at about 13 minutes) or on the first `not_authenticated` error: call `refresh`, store the new
  `accessToken`, retry the failed operation **once**. Serialise refreshes: if two requests fail together, one `refresh` serves both.
* If `refresh` fails with `session_expired` or `no_refresh_session`, the session is over: clear tokens and show sign-in. Reusing an already-rotated
  refresh token ends that session on purpose (it means two parties hold it).
* `logout` blacklists the refresh token and clears the cookie. Also drop the access token and any cached data.
* A password change, a 2FA reset or a suspended agency invalidates tokens at once; the next call returns `not_authenticated`.

> Gap to decide with the platform team: a client that cannot keep cookies cannot refresh. If the cookie jar proves awkward on a platform, ask for a
> body-token refresh mode for native apps; it does not exist today.

### 3.5 Who is signed in

```graphql
query Me { me {
  id fullName email phone avatarUrl userType agentPosition permissions twoFactorEnrolled recoveryCodesRemaining
  agent { id name status tier isGuaranteed parentAgent { id name } wallet { balance creditLimit currency } }
} }
```

* `agentPosition`: `owner`, `branch_manager`, `staff`. `agent.parentAgent` is `null` for a **Main Agent** and set for a **Sub-Agent**
  (the hierarchy has exactly two levels).
* `permissions` is the person's effective permission list. Use it **only to hide or show controls**: the server checks every call again and answers
  `permission_denied`. Several screens also expose ready-made flags (`canCreate`, `canTopUp`, `actions.canCancel`, ...): prefer those.
* `avatarUrl` is a short-lived signed link; refetch `me` rather than caching it.

---

## 4. Errors

```json
{ "errors": [ { "message": "...", "extensions": { "code": "insufficient_funds", "params": { "available": "40.00" } } } ], "data": null }
```

* Branch on **`extensions.code`**, never on `message`. The reference ends with the table of every code and its English text. Keep your own Arabic and
  English strings keyed by code (the web app's `frontend/src/messages/ar.json`, section `errors`, is a ready Arabic source).
* `params` (when present) holds values to put in your text.
* `internal_error` means something unexpected; the server never returns internals. Show a generic message and offer retry.
* `validation_failed` on `addTraveler`, `batchAddTravelers` or `submitRequest` carries `params.details`: a **JSON string** of
  `[{"traveler": 0, "field": "<fieldKey>", "code": "...", ...}]`. Parse it and mark each field.
* "Not found" and "not allowed" are deliberately indistinguishable for anything outside the agency's scope: handle both as "not available".
* File endpoints answer with a real HTTP status and `{"error": {"code", "message"}}` (section 8).

Codes you will meet on almost every screen: `not_authenticated`, `permission_denied`, `too_many_attempts`, `session_expired`,
`invalid_identifier`, `internal_error`.

---

## 5. Limits and rate limits

| Limit | Value |
|---|---|
| Query depth | 5 levels |
| Query size | 2000 tokens (a normal screen is about 200) |
| Root fields per request | 15 for a query, 3 for a mutation |
| Items in any list | at most 500 (use `limit` / `offset`) |
| Upload size | 8 MiB; files per traveler: 10 |
| Password | at least 12 characters |

Abuse throttles (per window; an exceeded limit returns `too_many_attempts`, wait and retry; do not retry in a tight loop):

| Action | Limit |
|---|---|
| Wrong password | 5 per account and 20 per IP, per 15 minutes |
| Wrong 2FA code | 5 per account and 20 per IP, per 15 minutes |
| Sign-up attempts | 5 per IP per hour |
| Password-reset requests | 10 per IP and 3 per address per hour |
| Verification-link requests / guesses | 10 per IP per hour |
| Uploads | 60 per user and 120 per IP per 10 minutes |
| Signed download links | 120 per user per 10 minutes |
| Passport readings (OCR) | 20 per user per 10 minutes |
| Ad impression / click reports | 120 per user per 10 minutes |
| Contact-form messages | 5 per IP per hour |

---

## 6. Data conventions

* **Language fields.** Content that Seen manages is bilingual: `nameAr` / `nameEn`, `labelAr` / `labelEn`. Pick by the app language. Operations that
  also take a `locale: "ar" | "en"` argument (e-mails, ads, reports) want the same two values.
* **RTL.** Mix Arabic text with Latin tokens (reference codes `SB-20481`, amounts, e-mails, phone numbers) using explicit LTR runs for those tokens.
* **Money.** Never use floating point. Parse `Decimal` strings with a decimal type. Show with the wallet `currency`. Amounts you send must be > 0 with at
  most 2 decimals.
* **Statuses are strings.** Treat unknown values as "other". Vocabularies are in section 13.
* **`JSON` fields** (`payload`, `spec`, `rows`, `validationRules`) are free-form: read defensively.
* **Masked values.** Personal values come masked by default (`isMasked: true`, `travelerNamesMasked`, ...). See `revealFieldValue` in section 10.

### Pagination

List operations take `limit` and `offset` (defaults 20 and 0). Page objects carry `total` and/or `hasMore`. Stop when `hasMore` is false or
`items` is empty. Plain list queries that have no `limit` are bounded server-side (a few dozen rows).

---

## 7. Roles and what the app may show

| Person | Typical abilities |
|---|---|
| Owner | everything for the agency: requests, wallet and top-ups, staff, reports, sub-agents (Main Agent) |
| Branch Manager | requests and staff within the agency, as granted |
| Staff | file and follow requests; nothing financial beyond what is granted |

A **Main Agent** can also manage its **Sub-Agents** (create them, fund them, suspend them, approve their requests and top-ups). A **Sub-Agent**
sees its own data only. `portalHome.isMainAgent` and the `can…` flags tell you which controls to show. Do not hard-code position names to
decide permissions.

Seen only ever talks to Main Agents; a Sub-Agent's confirmations go to its Main Agent.

---

## 8. Files

### 8.1 Upload: `POST /files/upload/`

`multipart/form-data`, header `Authorization: Bearer <access>`, **a `Content-Length` header is mandatory** (a chunked upload without it is refused).

| Field | Required | Notes |
|---|---|---|
| `file` | yes | PDF, JPEG or PNG only, at most 8 MiB. The type is checked from the content, not the name; SVG and HTML are refused. |
| `kind` | yes | `document` or `ticket_attachment` (agency users; `output` is Seen-only) |
| `travelerId` | for `document` | the traveler (from `addTraveler`) the file belongs to |
| `documentRequirementId` | for `document` | one of the service's `documents[].id` |

Success is `201`:

```json
{ "id": "…", "fileId": "…", "name": "passport.jpg" }
```

* `kind=document`: the file is attached to the traveler at once. Allowed only while the request is a **draft** or **info_required**; at most 10
  per traveler. Errors: `document_upload_not_allowed`, `document_requirement_invalid`, `too_many_files`, `request_not_found`.
* `kind=ticket_attachment`: a **staging** upload for anything that is attached by a second call: a support-ticket file (`openGeneralTicket` /
  `replyTicket` `attachmentFileId`), the profile picture (`setMyAvatar(fileId)`) and the top-up receipt (`submitTopUp(receiptFileId)`).
  A staged file nobody attaches is deleted after a day; at most a few can wait at once (`too_many_files`).
* Failure bodies: `{"error": {"code": "file_too_large" | "file_type_not_allowed" | "file_content_mismatch" | "file_empty" | "too_many_attempts" | "not_authenticated" | ..., "message": "..."}}`
  with HTTP `400`, `401`, `403`, `404`, `413`, `429` or `503`.

### 8.2 Download

There is no permanent file URL. `documentDownloadUrl(fileId)` returns `{ url, expiresAt }`, a signed link that lives about **90 seconds**. Open or
download it immediately; never store or share it. Each call is audited. Request outputs (the visa, the approval) arrive in
`portalRequestTracking.outputs` with a `fileId` for this call. `accountStatementPdf` and `exportAgentReport` return the file as base64 in the response.

### 8.3 Passport reading: `POST /files/read-passport/`

`multipart/form-data` with one `file` (JPEG or PNG of the **data page**). Needs `request.submit`. The image is read in memory and thrown away. The response
is `{"allChecksPass": true, "suggestions": [{"key", "value", "checked"}]}`: **suggestions only**. Show them for the person to confirm and put the confirmed
values into the traveler form; never submit them silently. Errors: `passport_not_image`, `ocr_unavailable` (the service may be off: fall back to manual entry).

---

## 9. Money rules the UI must respect

* No money moves when a request is submitted to a service that needs approval: the funds are held **only after approval**, and the check runs again at
  that moment. If the funds are gone by then the approval is invalidated and the agency must **submit a new request**.
* A top-up request (`requestTopUp` / `submitTopUp`) is **pending**: the balance changes only when Seen approves it.
* Wallet history is read-only and permanent. A correction is a new entry (a support ticket of type wallet adjustment), never an edit.
* A Main Agent funds or reclaims from a Sub-Agent with `topUpSubAgent` / `reclaimFromSubAgent` and decides a Sub-Agent's top-up with
  `approveSubAgentTopUp` / `rejectSubAgentTopUp`.

---

## 10. Core flows

Samples are minimal. Field lists are in the reference.

### 10.1 First screen

```graphql
query Home { portalHome(servicesLimit: 6, recentLimit: 3) {
  userName agencyName isMainAgent openRequestsCount actionNeededCount unreadNotifications
  wallet { __typename }
  quickActions { __typename }
  services { id code nameAr nameEn iconKey price currency slaHours requiresApproval }
  recentRequests { id referenceCode status statusGroup serviceNameAr serviceNameEn stage stageCount remainingKind remainingSeconds travelerNames travelerNamesMasked }
} }
```

(`wallet` and `quickActions` are objects: select their fields from the reference.) Ads for the home slot: `activeAds(placement: "home_banner", locale: "ar")`
and report `recordAdImpression(adId)` once per showing and `recordAdClick(adId)` on a tap.

### 10.2 File a request (the wizard)

1. **Catalog**: `portalServiceCatalog(search)` for the grouped list, or `availableServices` for the full form definitions. A service lists its
   `fields` (what to ask) and `documents` (what to upload). `myPrice` is the agency's own price; `requiresManagementApproval` tells the person it will wait.
2. **Optional pre-fill**: `prefillCandidates(serviceTypeId)` then `prefillFromRequest(serviceTypeId, sourceRequestId)` returns values to start from.
3. **Draft**: `createDraftRequest(serviceTypeId)` → `Request.id`. (A Main Agent may pass `agentId` to file for a Sub-Agent.)
4. **Travelers**: one traveler with `addTraveler(requestId, fieldValues: [{fieldDefinitionId, value}])`, or many with `batchAddTravelers`. Values are strings
   (dates as `YYYY-MM-DD`). Errors come back as `validation_failed` (section 4).
5. **Documents**: upload each file with `kind=document` (section 8.1) using the returned traveler id and the requirement id.
6. **Review**: `portalDraftReview(requestId)` returns `quote` (fee), `errors`, `violations` and `canSubmit`. Show it before the final button.
7. **Submit**: `submitRequest(requestId)`. The result's `status` is the new state; `referenceCode` (like `SB-20481`) may take a moment to appear, so if it is
   empty read `request(id)` again after a second or two. Show the reference code as the confirmation.
8. **Cancel** a request that is not final with `cancelRequest(requestId, reason)`; `actions.canCancel` and `cancelReleasesFunds` say whether and what happens.

**Dynamic forms.** Build the form from `ServiceType.fields` ordered by `stepNumber`, `displayOrder`. `fieldType` is `text`, `date`, `select`, `file`, `phone` and may
grow: render unknown types as plain text. `effectiveRules` is a JSON string of hints; the server is the authority:

```json
{ "format": "…", "min_length": 2, "max_length": 80, "options": [{"value": "x", "label_en": "…", "label_ar": "…"}],
  "date_not_future": true, "date_not_past": false, "min_valid_months": 6, "min_age_years": 0, "max_age_years": 120,
  "min_value": 0, "max_value": 99,
  "show_if": {"field": "<fieldKey>", "op": "eq|ne|in|filled|empty", "value": "…"},
  "required_if": {"field": "<fieldKey>", "op": "eq|ne|in|filled|empty", "value": "…"} }
```

`show_if` and `required_if` refer to another field of the same traveler. A hidden field counts as empty. A reference implementation is
`frontend/src/lib/conditions.ts` and `validation.ts`.

### 10.3 Follow a request

* List: `portalRequests(group, search, limit, offset)`; `group` is `all | new | processing | action_needed | completed | closed | draft`. The result also carries
  the chip counts (`filters`) and `attention` (the documents banner).
* Detail: `portalRequestTracking(id)`: `timeline` (steps with `state` and `at`), `infoRequest` (what Seen needs and the countdown), `terminal` (the final result
  message), `travelers`, `outputs`, `actions`, `feeTotal`.
* When `status` is `info_required`, upload the missing documents (section 8.1, `kind=document`), then the request moves on by itself.
* **Sensitive values.** Names and passport numbers come masked. `revealFieldValue(fieldValueId)` returns the clear text of one value; it is audited and
  rate-limited. The app policy: reveal only when the screen needs it, keep the value in memory for that screen, never write it to disk, logs or analytics,
  and clear it on leaving the screen or backgrounding the app.
* A Main Agent decides a Sub-Agent's request that waits for it with `decideMainAgentApproval(requestId, approve, note)`
  (`actions.canDecideApproval` says when).

### 10.4 Wallet

* `portalWallet(filter, type, dateFrom, dateTo, limit, offset)`: `summary` (balance, credit, held), `pendingTopUps`, `statement` rows, `canTopUp`.
* Top-up: `portalTopUpOptions` gives `methods`, the Seen `accounts` to pay into (`paymentAccounts` is the same list), `minimumAmount` and the receipt rules.
  Upload the receipt as `kind=ticket_attachment`, then `submitTopUp(amount, method, referenceNumber, paymentAccountId, receiptFileId, idempotencyKey)`.
  (`requestTopUp` is the same without account and receipt.) The result is `pending`.
* Statement: `accountStatementPdf` (PDF as base64) for the agency, or the on-screen `statement` rows.

### 10.5 Support (called "الدعم الفني" / Support)

* `ticketCategories` → `openGeneralTicket(subject, description, category, priority?, relatedRequestId?, attachmentFileId?)`.
* List: `tickets(limit, offset, status, search)`; one: `ticket(id)` with `messages`. Reply: `replyTicket(ticketId, message, isInternalNote: false, attachmentFileId?)`
  (an agency can never post internal notes). `markTicketRead(ticketId)` when the thread opens; `unreadTicketsCount` for a badge.
* A **live chat** is a ticket with `category: "live_chat"`; poll `ticket(id)` every 5 s while the chat is open and `tickets` every 30 s in the background.
* `rateTicket(ticketId, rating: Int!)` after a resolution, where offered.

### 10.6 Agency team (Owner, Main Agent)

`agentTree` (agency and sub-agencies), `agentStaff`, `portalAgents`; `createStaffUser`, `createBranch`, `updateUserRole`; Main Agent only: `createSubAgent`,
`setAgentStatus` (suspend/activate a Sub-Agent), `setAgentServiceEnablement(agentId, serviceTypeId, enabled, overridePrice?, markupPercent?)` (which services a Sub-Agent may order, and its price),
`updateAgentProfile`. Each needs the permission shown in the reference.

### 10.7 Reports

`agentReportCatalog` lists the data sources (`requests`, `ledger`) and their fields (only the agency's own). `runAgentReport(spec, language)` returns rows;
`exportAgentReport(spec, format: "xlsx" | "pdf", language)` returns the file base64 (the export carries the platform branding line). Needs `report.create`.

---

## 11. Notifications

There is no push yet. Poll while the app is in the foreground:

* `portalHome.unreadNotifications` or `portalNotifications(unreadOnly: true, limit: 1, offset: 0).unreadCount` about every **30–60 seconds**.
* Open the inbox with `portalNotifications(unreadOnly: false, limit: 20, offset: 0)`; each item has `kind`, `tone`, `iconKey`, a `group`
  (`today`, `yesterday`, `earlier`) and the ids to deep-link (`requestId`, `ticketId`). `markNotificationRead(notificationId)`, `markAllNotificationsRead`.
* When the app returns to the foreground, refresh the open screen once.
* Plan the data model for push now (device token registration will be added as a mutation later; it is not in the schema today).

---

## 12. Security rules for the app

* HTTPS only; certificate validation on; no trust-all in any build. Consider pinning the platform certificate.
* Keep the access token in memory (or the OS secure store) and never in logs, analytics, crash reports or screenshots. Blur the app switcher snapshot.
* Never put personal data (names, passport numbers, e-mail) in URLs, deep links, push payloads or analytics events.
* Do not cache request details, documents or revealed values on disk. If you must cache for offline reading, keep only non-sensitive fields and clear on logout.
* Block screenshots or screen recording on screens that show a revealed passport number or document, if the platform allows.
* Treat every `permissions` check in the UI as cosmetic. Handle `permission_denied` everywhere.
* On `not_authenticated` after a refresh attempt, clear everything and show sign-in. On logout, drop the cookie jar entries for the host.
* Pin the app to a minimum server contract: ignore unknown fields, do not crash on unknown statuses.

---

## 13. Status vocabularies

* **Request `status`**: `draft`, `submitted`, `pending_agent_approval` (a Sub-Agent's request waiting for its Main Agent), `pending_management_approval`
  (waiting for Seen's management), `under_review`, `info_required` (the agency must act), `processing`, `completed`, `rejected`, `cancelled`.
  The portal cards also give `statusGroup` and `stage` / `stageCount` for a progress bar, and `slaState` for the deadline colour.
* **Wallet transaction `type`**: `topup`, `hold`, `final_deduction`, `release`, `refund`, `settlement`. **`status`**: `pending`, `approved`, `rejected`.
* **Payment account `kind`**: `wallet_app`, `bank`, `money_transfer`, `other`.
* **Ticket `status`**: `open`, `in_progress`, `waiting`, `resolved`, `closed`, `cancelled`. **`type`**: `general`, `wallet_adjustment`.
* **Agency `status`**: `pending`, `active`, `suspended`.
* **Ad placements**: `home_banner`, `requests_banner`, `wallet_banner`.

Always handle an unknown value.

---

## 14. Not in the API today (so the app must not assume it)

* Push notifications and device registration.
* A body-token refresh mode (refresh is cookie-based).
* Document upload at signup (the commercial registry is requested by Seen).
* Subscriptions / websockets; introspection in staging and production.
* Seen-only functions of any kind.

## 15. Regenerating the reference

`docs/mobile-api-reference.md` is produced from `backend/schema.graphql`, the authorization matrix (`apps/api/test_security_matrix.py` and
`matrix_rows_*.py`) and the resolver docstrings. After the schema changes run `manage.py export_schema apps.api.schema:schema --path schema.graphql`
and regenerate the reference with `docs/tools/gen_mobile_api_reference.py` (the command is in its first lines). An operation appears in the reference only if the matrix lets an agency user call it, minus the short exclusion list in
the generator (Seen-only in effect).
