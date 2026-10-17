# Backend Migration Gaps

Backend capabilities the Figma migration (screens 01–18) needs but the API does
not expose yet. Each gap lists what the app does today, what it needs, and where
the client code waits for it. The client never fakes these: unavailable actions
show an informational state.

Status: open. Last updated with Phase 3F (commit `ea9e596`).

---

## 1. Company bank account (top-up destination)

**Screen:** 12, Top-up. `lib/features/wallet/presentation/screens/top_up_request_screen.dart`

**Today:** the bank details card (`SeenBankDetailsCard`, model `TopUpBankDetails`)
has nothing to show. Release builds show "support will send you the bank
account details". Debug builds (`kDebugMode`) show an obvious placeholder. The
Figma sample IBAN is never shipped.

**Needed:** a read query returning the account an agent wires money to.

| Field | Type | Notes |
|---|---|---|
| `bankName` | String | |
| `beneficiary` / `accountName` | String | |
| `iban` | String | shown LTR, copyable |
| `currency` | String | now fixed to `USD` in the UI |

Open questions for the backend: one account or one per currency / method? Does
cash or exchange-house need a different destination or instructions? Is there a
minimum top-up amount (the UI enforces none)?

**Client wiring:** pass the result to `TopUpRequestScreen(bankDetails: ...)`
through the wallet feature (a new use case and data source). No UI change.

---

## 2. Agency self-registration

**Screens:** 15, Create agency account, and 16, Pending approval.
`lib/features/auth/presentation/screens/create_agency_account_screen.dart`,
`auth_entry_flow.dart`

**Today:** a valid form is validated locally and goes straight to the pending
screen. Nothing is sent or stored, so the screen-16 promise ("within 24 hours")
is not backed by a real request.

**Needed:** an unauthenticated mutation, for example `registerAgency`.

| Input | Type | Notes |
|---|---|---|
| `agencyName` | String | required |
| `commercialRegistrationNumber` | String | required, LTR |
| `city` | String | required (city / region) |
| `contactPhone` | String | E.164 (the form already validates it as a phone) |
| `email` | String | required |
| `commercialRegisterDocument` | upload reference | see gap 4 |

Result: a request id or a status the app can show on screen 16. Also needed:
duplicate CR / phone / email handling, rate limiting (the call is
unauthenticated), and the ops-side review flow behind "within 24 hours".

**Client wiring:** `CreateAgencyAccountScreen.onSubmitted` should call a use case
and only advance on success; the failure and offline states need copy.

---

## 3. Session metadata (agency name, agent name, verification)

**Screens:** 14, Account, plus the greeting on 05, Home.
`lib/features/home/presentation/screens/account_screen.dart`,
`lib/features/auth/domain/entities/user_session.dart`

**Today:** `UserSession` carries `userId`, `userType`, `positionRaw`, `branchId`
and `permissionCodes` only. The account header shows "Agency account" and the
user's role. No name and no verified badge are shown, because nothing real backs
them.

**Needed** in the login / session payload (or a `me` query):

| Field | Used for |
|---|---|
| `agencyName` | account header, agency details |
| `agentDisplayName` | account header, home greeting |
| `agentStatus` (`pending` / `active` / `suspended`) | verified badge; gate routing |
| `commercialRegistration` (number, city, status) | "Agency details & commercial register" row |

`AgentStatus` already exists in `core/constants/enums.dart` but is not delivered
by auth. Once it is, the auth gate should route `pending` to
`AgencyPendingApprovalScreen`, and `suspended` to a dedicated state.

**Client wiring:** extend `UserSession` and its DTO mapping, then replace the
fallback text in `AccountScreen`.

---

## 4. Document attachment / upload contracts

**Screens:** 09, Travelers (passport and documents); 12, Top-up (receipt);
15, Create agency (commercial register copy).

**Today:** each slot is a visual `SeenDropzone` that says attachments are not
available yet. No picker is opened and no fake attachment is created.

**Needed:** one upload contract the three flows share:

- Upload mechanism: pre-signed URL, multipart GraphQL upload, or a REST endpoint,
  with the returned file reference.
- Constraints: allowed types (image / PDF), max size, max files per slot.
- Authorization: the agency-registration upload runs before login, so it needs
  its own unauthenticated, rate-limited path.
- Linking: how a file reference attaches to a traveler, a top-up request
  (`requestTopUp` has no attachment argument today) and a registration.
- Lifecycle: virus scanning, retention, and how the client previews or
  re-downloads a file.

**Client wiring:** add a picker dependency (decide it then; none is added now),
an upload use case with progress and retry, and the new argument on the
mutations above.

---

## Other gaps found during migration

Smaller items, listed so they are not lost:

- **Statement export** (screen 11): no API, so the button opens an informational
  sheet. Needs an export query or a download URL.
- **Create sub-agent** (screen 13): no mutation, so "Add agent" says it is coming
  soon.
- **Sub-agent model** (screen 13): only `isActive` exists. Edit limit, a Pending
  agent state and commission totals need backend data (credit limit, a status
  enum, commission amounts).
- **Support contact** (screen 16): no phone, email or chat target to link to
  before sign-in.

---

## 5. Service catalog (Figma 08) and top-up (Figma 12) data

**Screens:** 08, New request · Catalog (`service_selection_screen.dart`,
`service_card_copy.dart`), and 12, Top-up.

**Today:** Figma 08 has two sections, "Visas" (India, Egypt entry, Saudi) and
"Approvals & travel" (hotels as coming soon, security approval, flight). The
backend only knows approval / airline categories, so the app draws one
"Approvals & travel" section. The Visas section is built but stays hidden until
a service lands in it. Section, icon and label are all derived on the client
from `ServiceCategory`.

**The backend should provide**, per service in the catalog query:

| Field | Why |
|---|---|
| Visa services (India, Saudi, Egypt entry) as real services | the Visas section |
| `section` / `group` (`visas`, `approvals_travel`) | the client should not infer the section from the category |
| `iconKey` (or an icon URL) | icons are chosen by category today; new services would show a generic one |
| `sortOrder` | Figma orders the tiles (visas first; hotels last) |
| `shortName` (localized, ar / en) | three tiles per row fit about 14 characters on one line; long names wrap |
| `availability` incl. "coming soon" entries (e.g. Hotels) | the dashed tile with the "Soon" tag |
| localized `name` / `description` | today a single string is returned |
| `perPersonPrice` | not shown on the tiles (Figma has none) but needed on the traveler and review screens |

**Top-up (12), in addition to gap 1:**
- Payment methods as data (code, localized label, icon key, enabled). Figma shows
  Bank transfer, Cash deposit and **Electronic wallet**; the API only has bank
  transfer, cash and exchange house, so the third card is labelled "Exchange house".
- A minimum top-up amount (Figma shows "Minimum 50.00 USD"; the app shows none
  because none is defined) and the validation error it returns.
- Whether the bank's transfer reference is required (the API requires it; Figma
  has no field, so the screen asks for it).
- Receipt upload with progress (gap 4): Figma shows an uploading state with a
  file name, size and percentage.

---

## 6. Per-screen backend requirements (Figma 05–13)

What each migrated screen still needs from the backend. "Today" says what the
app does instead; nothing is invented on the client.

### 05 · Home
- **Agency identity:** agency name and agent display name (greeting, avatar
  initials). Today: greeting without a name, a person glyph as the avatar.
- **Request summary fields:** first traveler name, destination / service type,
  service icon key and the current step text ("لدى الجهة المختصة · ٣ من ٥") with
  the step count. Today: service name and traveler count.
- **Banners:** an announcements API for the promo banner (title, subtitle, CTA,
  badge, expiry). Today: static copy behind `kShowHomePromoBanner`.
- **Search:** a search endpoint for requests and travelers. Today: the search pill
  opens the requests list.
- **"Needs follow-up" count:** returned by the server instead of computed from
  the loaded requests.

### 06 · Requests
- Same summary fields as Home (traveler name, destination, service icon, step text).
- **Counts:** totals for all / processing / awaiting action / completed from the
  server; the loaded page may be only part of the data.
- **Pagination and server-side filter / search** (status, text, date).
- **72 h window:** the deadline of every request waiting for documents (drives the
  banner and the countdown pill).
- **Search by reference or traveler name.** Today: the search UI is not shown (not
  in Figma); the bloc still supports it.

### 07 · Request tracking
- **Stage timeline from the server:** stage names and count, per-stage timestamps,
  the active stage with "started N hours ago", and expected durations for future
  stages ("expected within 48 h"; "right after issue"). Today: five stages derived
  on the client from the status.
- **Authority-response deadline:** the "remaining time for the authority's reply"
  counter in Figma is shown while the request is at the authority; today only the
  documents deadline (action required) is shown. Needs a deadline and its reason
  (`deadlineKind`: documents / authority) per request.
- **Ticket data:** lead traveler, destination, fee total and request date (present),
  plus the service icon key.
- **Documents:** list and download of the request's documents (issued approval,
  receipts), per traveler. Today: a documents sheet with no real files.
- **Cancellation rules:** whether a request can be cancelled, and why not.

### 08 · Catalog / 09 · Form / 10 · Review (see also gap 5)
- **09:** form definitions per service (fields, order, which fields sit side by
  side, passport number length and helper text); passport / document upload
  (gap 4); server-side passport validation (expiry, number format) with a result
  per field; the list of nationalities.
- **10:** fee breakdown lines (service fee, authority fee, any margin), service
  details line ("Umrah · single entry · 90 days") and processing time, and the
  wallet hold done by the backend, returning the balance after the hold.

### 11 · Wallet
- **Ledger rows:** the service name and its icon key, and the request reference
  for charges. Today: the transaction type plus the reference, one generic icon.
- **Pending top-up:** the payment method (bank transfer, cash, exchange house).
- **Statement export** (PDF / Excel, by period). Today: an informational sheet.
- **Server-side ledger filter** (direction, date) with pagination.
- **Rejection reason** for rejected top-ups and charges.

### 12 · Top-up
- See gaps 1, 4 and 5: company bank account, payment methods as data (incl. the
  electronic wallet method Figma shows), a minimum amount, whether the transfer
  reference is required, and receipt upload with progress.

### 13 · Sub-agents
- **Overview:** monthly profit total for the agent network (Figma shows "monthly
  profits"; the app shows the total of agent balances instead).
- **Agent card:** city and request count per agent; a pending / suspended / active
  status enum (today only `isActive`).
- **Create agent** mutation, **edit credit limit** mutation, and commission data.
- **Approvals entry point:** the pending-approvals screen exists but is no longer
  linked from the sub-agents screen (Figma has no entry); decide where it lives.

---

## 7. Per-screen backend requirements (Figma 01–04, 15–18)

Same format as section 6.

### 01 · Splash
- Nothing screen-specific. Session restore at launch depends on the session
  payload of gap 3 (agent status, agency identity).

### 02 · Welcome
- **Terms and Privacy:** URLs (per language) for the two documents; the line is
  plain text today.
- **Self-registration:** see gap 2 (the "Create agency account" button leads to a
  form that sends nothing).

### 03 · Login
- **Forgot password:** request a reset code and set a new password. Today the link
  says "coming soon".
- **Login errors:** distinct error codes (wrong credentials, account suspended or
  pending review, too many attempts with the lockout time).
- **Account status** in the login result, so a pending agency is routed to the
  pending screen (gap 3).
- **Phone format:** confirm E.164 and the accepted countries; the +967 prefix is a
  fixed default in the app.
- **OTP after every login:** the helper text promises a verification code, so
  every sign-in needs the OTP step (or the copy has to change).

### 04 · OTP
- **Masked destination** (phone or email) returned with the "code sent" response
  instead of rebuilt on the client.
- **Resend cooldown** in seconds from the server (the countdown seeds from it).
- **Error codes:** wrong code, expired code, attempts exhausted (with the lockout
  time).

### 15 · Create agency account
- **`registerAgency` mutation** (unauthenticated, rate-limited): agency name,
  manager name, phone, email, city, license number, commercial-register file
  reference; returns a request id. Handle duplicates (phone, email, license).
  See gap 2.
- **Phone verification:** the form says "we will send a verification code to this
  number", so registration needs an OTP send and confirm step.
- **Commercial-register upload** without a session (gap 4).
- **Cities** as data (the field is free text).
- **Manager name:** confirm it is part of the registration payload and its format
  (three-part name).

### 16 · Pending approval
- **Registration status** (received, documents under review, activated, rejected
  with a reason) to drive the three-step card; today the second step is always
  "current".
- **Routing:** return the agent status at sign-in so a pending agent lands here.
- **Review time promise** ("within one business day") must match a real SLA, or the
  backend returns the expected time.
- **Activation notice** (message or push) when the account is activated.
- **Support channel before sign-in** (phone, email or chat) for the "Contact
  support" button.

### 17 · Notifications
- **Ready-to-show text** in the user's language and a stable event key per event
  (visa issued, document required, top-up accepted, status change, new agent).
- **Push notifications** (FCM / APNs) with device-token registration.
- **`markAllRead`** and the **unread count** from the server (the screen no longer
  has a mark-all button because Figma has none; decide where it should live).
- **Pagination** for the feed.
- **Deep-link target** (request, wallet, agent), not only a request id.

### 18 · Requests, empty
- **Total request count** returned with the query, to tell "the agency has no
  requests" (this screen) from "the filter matches nothing".
- **Empty vs. failed:** a response that distinguishes an empty list from a
  connection error, so an error never shows "no requests yet".

---

## 8. Assumed contract: forgot password (implemented in the app, awaiting the backend)

The Flutter side of the recovery flow (Figma AUTH-01 … AUTH-04) is built against
the placeholder below (`password_recovery_remote_data_source.dart`). In debug
builds a fallback answers when the real call fails; **release builds call the
real mutations, so they fail until these exist**.

```graphql
mutation RequestPasswordReset($identifier: String!)   # E.164 phone or email
  -> { challengeToken maskedDestination resendCooldownSeconds }
mutation ResendPasswordReset($challengeToken: String!)
  -> { challengeToken maskedDestination resendCooldownSeconds }
mutation VerifyPasswordReset($challengeToken: String!, $code: String!)
  -> { resetToken }
mutation ResetPassword($resetToken: String!, $newPassword: String!)
  -> { success }
```

Error codes (GraphQL `extensions.code`, with `extensions` details) the app maps:

| Code | Details | Screen state |
|---|---|---|
| `ACCOUNT_NOT_FOUND` | none | AUTH-01b red field message + links |
| `RATE_LIMITED` | `retryAfterSeconds` | AUTH-01b amber banner with a countdown |
| `OTP_INVALID` | `attemptsLeft` | AUTH-02b red cells + "N attempts left" |
| `OTP_EXPIRED` | none | AUTH-02b amber banner with Send |
| `OTP_ATTEMPTS_EXHAUSTED` | `lockoutMinutes` | AUTH-02b red banner, resend disabled |
| `PASSWORD_REUSED` | none | AUTH-03 rule "not a previous password" fails |
| `PASSWORD_WEAK` | none | AUTH-03 banner (client rules: 8+ chars, upper + lower, a digit) |

Also needed from the backend: the code is 6 digits and valid for 10 minutes (the
helper text says so); the reset ends the user's other sessions (the success screen
says so); the password policy above is enforced server-side as well.

## 9. Agency registration after the form (Figma AUTH-05 … AUTH-07)

The "Create agency account" form (step 1 of 4) no longer jumps straight to the
pending screen: it continues with a password (2/4), a phone code (3/4) and the
terms consent (4/4), then the pending-approval screen. None of this exists on the
backend yet. The app calls the placeholders below
(`agency_registration_remote_data_source.dart`); debug builds fall back to canned
answers when the real call fails, **release builds call the real mutations and
fail until these exist**.

```graphql
mutation StartAgencyRegistration($input: AgencyRegistrationInput!)
  # input: agencyName managerName phone(E.164) email city licenseNumber password
  -> { challengeToken maskedPhone resendCooldownSeconds }   # stores a PENDING registration, texts the code
mutation ResendRegistrationCode($challengeToken: String!)
  -> { challengeToken maskedPhone resendCooldownSeconds }
mutation VerifyRegistrationPhone($challengeToken: String!, $code: String!)
  -> { verificationToken }
mutation CompleteAgencyRegistration($verificationToken: String!, $consent: RegistrationConsentInput!)
  # consent: acceptedTerms acceptedPrivacy marketing
  -> { success }                                            # creates the account in "pending review"
```

| Code | Details | Screen state |
|---|---|---|
| `PHONE_ALREADY_REGISTERED` | none | AUTH-06 red banner "linked to another account" + Sign in |
| `RATE_LIMITED` | `retryAfterSeconds` | amber banner |
| `OTP_INVALID` | `attemptsLeft` | red cells + "N attempts left" |
| `OTP_EXPIRED` | none | amber banner |
| `OTP_ATTEMPTS_EXHAUSTED` | `lockoutMinutes` | red banner |
| `PASSWORD_WEAK` | none | red banner on AUTH-05 |

Also needed from the backend:
- Duplicate **email** and **license number** checks (Figma AUTH-08 shows field
  errors; not built until that frame is approved). Today only the phone is
  reported, and only when the code is verified.
- Store the consent with a timestamp and the document versions accepted
  (terms / privacy); the app sends only the three flags.
- The commercial-register upload on the form is still not sent anywhere (section 3).
- Terms and privacy texts (AUTH-09 / 10 readers) — the "Read" links show a
  "coming soon" snackbar for now.
- The password is sent once, in `StartAgencyRegistration`, and is never kept in
  app state; the backend must hash it and discard the pending registration after a
  timeout.


## 10. Upload the missing document (Figma REQ-05 / REQ-05b)

A request in "info required" can now be answered from the tracking screen
("Upload the required document"): the screen shows what is asked and why, the
deadline, then file / gallery / camera, a preview, and the send with progress.
The backend contract below is a placeholder
(`missing_document_remote_data_source.dart`); debug builds fall back to canned
answers when the real call fails, **release builds call the real operations and
fail until they exist**.

```graphql
query MissingDocumentRequest($requestId: ID!)
  -> { requestId referenceId documentTitle travelerName reason deadline
       maxBytes allowedExtensions }          # what the authority asked for, and why
mutation UploadMissingDocument($requestId: ID!, $file: Upload!)   # multipart upload
  -> { success }
```

| Code | Screen state |
|---|---|
| `DEADLINE_PASSED` | amber banner "deadline passed, request cancelled, held amount returned" + New request |
| `FILE_TOO_LARGE` | red banner with the limit |
| `FILE_TYPE_NOT_ALLOWED` | red banner |

Also needed from the backend:
- **Progress:** a multipart GraphQL call cannot report byte progress, so the bar
  jumps to 100%. A pre-signed URL upload (then a confirm mutation) gives real
  progress; decide which one with the shared upload contract (section 4).
- **The request's `missingDocument` data** must come with the request while it is
  in "info required" (title, traveler, reason, deadline, limits). The app does not
  invent the reason text.
- **Deadline:** the app disables upload locally once `deadline` has passed, but the
  server stays the authority and answers `DEADLINE_PASSED`.
- **Copy promises the server must keep:** after the deadline the request is
  cancelled automatically and the held amount is refunded to the wallet (the
  banner says so).
- **After a successful upload** the request must leave "info required" (the detail
  is reloaded on return) and the document must be visible to the reviewer.
- Virus scanning / retention of the uploaded file (section 4).

Client side: this adds two plugins, `image_picker` (gallery, camera) and
`file_picker` (PDF / files), behind a `DocumentPicker` interface in the domain.
iOS `Info.plist` now carries the camera and photo-library usage strings; Android
needs no manifest permission for either plugin as used here.

## 11. Booking success / receipt (Figma BOOK-01)

The receipt after "Confirm and send" shows the request number, service, traveler
count, held amount and the balance after the hold, with "Follow request" (Requests
tab) and "New request" (Home).

Needed from the backend:
- **Return the receipt data with `submitBooking`:** today the result carries only
  `requestId`, status, total and `createdAt`. The app computes "available balance
  after booking" itself (balance read before submitting minus the hold). The
  mutation should return `heldAmount` and `availableBalanceAfter` (and the
  service name / traveler count) so the receipt shows what the server did.
- **Receipt PDF and share:** both buttons say "coming soon". The clean fix is a
  server-generated receipt (`receiptUrl` on the request, PDF, authenticated) that
  the app downloads or shares; the alternative is adding `share_plus` and a PDF
  library and rendering the receipt on the device. Decision needed.
- **Copy promise:** "held, not charged; charged when the visa is issued, returned
  if rejected" must match the wallet hold rules (section on wallet holds).

## 12. Session expired (Figma AUTH-13)

Any request answered 401 while signed in now keeps the current screen under a
blocking "Session expired" dialog; "Sign in" clears the stored session and opens
Login. (Before, the screen was dropped immediately and the stored token was left in
secure storage, so a relaunch restored a dead session.)

Needed from the backend / product:
- **Drafts:** the design says "we saved your form as a draft and you will return
  to it after signing in". The app has no drafts (no storage, no restore flow, and
  the "show drafts" screen is still undesigned), so that line is **not shown**.
  Decide: server-side drafts (`saveBookingDraft` / `bookingDrafts`) or local
  encrypted storage; then the dialog can show the banner and Login can restore.
- **Refresh token:** a silent refresh before showing the dialog would avoid most
  expiries; the backend must say whether refresh tokens exist (the app has none).
- **401 must mean "expired", never "wrong permission"** (403) or "wrong password"
  (login errors are normal failures): the dialog appears on every 401.
- Return the user to where they were after sign-in: not done (Login opens fresh).

## 13. Document viewer (Figma REQ-11 / REQ-11b)

"View documents" on the tracking screen now opens a viewer: pages with zoom
(− 100% +, pinch) and thumbnails, Share and Download; "not ready yet" (with where
the request is) when the request has no document; "could not open" with Retry /
Report to support when the download fails.

**Client gap (decision needed): no PDF engine is installed.** Rendering a PDF
needs a native plugin; `pdfx` is the candidate, but it pulls `photo_view` (~23 MB
package) and could not be downloaded on this machine's connection, so it was not
added. Today: images render fully; a PDF shows "PDF preview is not available yet"
with Download / Share working. To finish, add the plugin and implement
`PdfPageRenderer` (3 methods: open → page count, renderPage, close) and return it
from `InjectionContainer.createPdfPageRenderer`. The pages / thumbnails / zoom UI
is already built and tested against a fake renderer.

Needed from the backend:
- **A fetchable document URL.** The app does a plain HTTPS GET of
  `outputDocumentUrl` (30 s timeout, no auth header), so it must be a pre-signed,
  time-limited URL. If it needs the session token instead, say so and the app adds
  the header.
- **Several documents per request.** The API gives at most one `outputDocumentUrl`
  and only once the request is `completed`. Figma's viewer is multi-page and the
  tracker lists several documents (approval, receipt, traveler files): the request
  detail should return a list `[{ id, title, fileName, mimeType, sizeBytes, url }]`.
- **Content type** (`application/pdf` / image) so the app does not guess from the
  file extension.
- **Copy promise:** "we will notify you as soon as the document is issued" needs a
  push / in-app notification when a document becomes available.
- **Expired URL:** the app shows the generic "could not open" card; a distinct code
  (e.g. 403 / `LINK_EXPIRED`) would let it refetch the request and retry itself.

Client side: adds `path_provider` as a direct dependency (temp file for sharing);
saving uses the system save dialog (`file_picker`), sharing uses `share_plus`
(already a dependency).

## 14. Transfer to agent (Figma WAL-07 / 07b / 07c)

The wallet's "Transfer to agent" now opens a flow instead of the sub-agents list:
choose an active sub-agent, amount (quick chips 100 / 300 / 500 / 1,000) and an
optional note, a confirmation sheet, then a success page showing the refetched
balance. It uses the existing `fundSubAgentWallet` mutation.

Changed contract (placeholder, additive): `fundSubAgentWallet(subAgentId, amount,
note)`: `note` is new, optional, sent only when the user typed one.

Needed from the backend:
- **Accept and store `note`** (shown in both ledgers) or tell us it is not wanted
  and the field is removed.
- **Return a transfer reference.** Figma's success text says "Reference TR-5521";
  the mutation returns only the sub-agent, so the reference is **not shown**. Return
  `{ subAgent, transferReference, masterBalanceAfter }`; the app would then show the
  reference and stop refetching the balance.
- **Ledger entries for both sides** (debit for the master, credit for the
  sub-agent) with the note and reference, so the wallet history shows the transfer.
- **Authorization:** only a master agent may transfer; the app checks the amount
  against the available balance but the server must re-check (and reject while
  amounts are on hold) and answer a clear code for insufficient balance
  (`INSUFFICIENT_BALANCE`, with `available`), which today surfaces as a generic message.
- **Atomicity / idempotency:** a retry after a timeout must not transfer twice
  (idempotency key), since the confirm button can be pressed again after an error.
- **"Cannot be undone"** is the copy on the confirm sheet: no reversal exists in the app.

## 15. Add sub-agent and edit credit limit (Figma AGT-01 / 01b / 02)

The FAB on the agents list opens "Add sub-agent" (replacing the "not available yet"
message); success shows "Agent added" with an "Activating" chip while the invite is
pending. "Edit credit limit" is a sheet reached from the fund sheet (the card tap)
until the agent profile (AGT-04) exists (it now does: "Edit limit" is a button there, section 17). Both call placeholders; debug builds fall
back to canned answers, **release builds call the real operations and fail until
they exist**.

```graphql
mutation CreateSubAgent($input: CreateSubAgentInput!)
  # input: agencyName managerName phone(E.164) email? marginPercent? creditLimit? sendInvite
  -> SubAgent { id name code balanceAmount isActive marginPercent
                creditLimitAmount creditUsedAmount invitePending }
mutation UpdateSubAgentCreditLimit($subAgentId: ID!, $creditLimit: String!)
  -> SubAgent
```

`SubAgent` gains `creditLimitAmount`, `creditUsedAmount` (decimal strings) and
`invitePending`; the `subAgents` query must return them (the sheet shows "—" when absent).

| Code | Details | Screen state |
|---|---|---|
| `SUBAGENT_PHONE_TAKEN` | none | red message under the phone field |
| `SUBAGENT_EMAIL_TAKEN` | none | red message under the email field |
| `CREDIT_LIMIT_BELOW_USAGE` | `usedCents` | red message under the new limit |
| `CREDIT_LIMIT_ABOVE_ALLOWED` | `maxCents` | red message under the new limit |

Needed from the backend / product:
- **The login invitation:** `sendInvite` must send a link (SMS / email) to create a
  password, and the agent stays `invitePending` until it is accepted. Who is the
  login of the sub-agent (phone or email)? The form's email is optional.
- **Credit-limit rules.** Figma's hint says the limit may not exceed the master's
  available main balance, and cannot go under the amount in use. The app checks both
  locally; the server must enforce them (the main balance changes), with the codes above.
- **Margin** is a percentage 0–100; confirm the scale and whether it can be changed later.
- **Code generation:** the sub-agent `code` (AG-101…) is server-assigned.
- **Success page action:** Figma's second button is "Agent profile"; that screen
  (AGT-04) does not exist, so the button is "Back to agents".
- **Edit entry point:** needs the agent profile (AGT-04) or a card menu to be
  discoverable; today it is a link inside the fund sheet.

## 16. Connectivity and error patterns (Figma SYS-01 / 02 / 02b)

Built: an app-wide offline banner ("You are offline. Showing data as of 10:42" with
Retry, then a green "Connection is back" that hides itself), and reusable error
patterns: inline section error with retry, "taking longer than usual" notice,
error sheet for a failed action, and the full-screen server error. They are applied
to the requests list (offline → inline error; server error → full screen with the
error code) and to the transfer confirmation (failure → error sheet with Retry).
Other screens still use their older error views.

Not built, and why:
- **Stale-data marker and cached lists (SYS-01).** The app keeps no cache, so
  offline the screens keep whatever they already loaded; the "as of" time is the last
  successful backend answer (in memory). A real offline mode needs a local cache with
  a defined staleness policy.
- **Queued actions ("waiting for connection").** Replaying a document upload or a
  transfer after reconnecting needs persistent queueing and **idempotency keys** on
  every mutation (a replay after a timeout must not run twice). Until then the app
  fails the action and offers Retry. Product and backend decision.
- **"Data updated and 1 action sent" (green banner).** The banner says only
  "Connection is back": nothing refreshes or sends on reconnect yet (no queue, no
  global refetch).
- **"No amount was charged" (SYS-02 error sheet).** Not claimed: after a timeout the
  client cannot know. If the server guarantees all-or-nothing and reports it, add a
  flag to the failure and the sheet can say so.

Needed from the backend:
- **A request reference on every error:** the header `x-request-id` on HTTP errors
  and `extensions.requestId` on GraphQL errors; the app quotes `502 · a91f` (status
  or code + first 4 characters) so support can find the request.
- **Error codes:** keep `extensions.code` stable; 5xx vs 4xx drives which pattern shows.
- **Timeout policy:** the client times out at its own limit; the slow-server notice
  (after 8 s, with Cancel) exists as a component but is not yet attached to a screen.
- "Online" in the banner means the device has a network transport, not that the
  backend answers; a lightweight health endpoint would let the banner say the latter.

## 17. Agent profile and suspend / reactivate (Figma AGT-04 / AGT-03)

Tapping an agent card now opens the profile (before: the fund sheet): card with
status, balance / credit limit / requests this month, **Fund · Edit limit · Suspend**
(or Reactivate), the agent's balance history and their requests. Fund and Edit limit
reuse the existing sheets; Suspend asks for a reason and names the requests still in
progress. Placeholders below; debug builds fall back to canned data, **release builds
call the real operations and fail until they exist**.

```graphql
query SubAgentProfile($subAgentId: ID!)
  -> { agent { id name code balanceAmount isActive marginPercent
               creditLimitAmount creditUsedAmount invitePending }
       city memberSince monthlyRequestCount inProgressRequestCount
       ledger { id title amount side(credit|debit) createdAt }      # newest first
       requests { id referenceId serviceName status submittedAt } }  # newest first
mutation SetSubAgentActive($subAgentId: ID!, $active: Boolean!, $reason: String)
  -> SubAgent
```

Needed from the backend / product:
- **Pagination:** `ledger` and `requests` come as plain lists; the screen shows all of
  them. Return only the latest N (e.g. 10) with a cursor or a "see all" screen.
- **Ledger titles** are server-written text ("Funding from the main agent",
  "SB-20484 · flight booking"), so they are localized and shaped there.
- **Suspension semantics** (the dialog promises them): requests already in progress
  continue until done, new requests are blocked, and a suspended agent is told. A
  reason is required to suspend (audit); reactivation takes none.
- **Permissions:** only the master agent may suspend / reactivate; the server must
  refuse suspending an agent that is not theirs.
- **Settings button:** Figma draws a settings button at the start of the profile
  header; nothing is specified for it (edit name / contact details?), so it is not
  built. Needs a design and an `updateSubAgent` mutation.
- **Request rows** are not tappable yet (no sub-agent-scoped request detail).

## 18. Sub-agent approvals, reject reasons, empty states, funding (Figma AGT-05 … 08)

Built: the approvals list (each request with value, Approve / Reject), the reject
reason sheet, the agents empty / no-result states, and the fund sheet restyle
(quick amounts 250 / 500 / 1,000, "From your main balance", success message with the
agent's new balance). These use the existing approve / reject / fund operations.

Product decisions taken (easy to move):
- **Entry point of the approvals list** (the designer left it open): a button with a
  count badge in the Agents header. The product decision earlier was that the Agents
  screen has **no approvals section**; a header button respects that. Alternatives:
  an Account menu row, or a badge on the Agents tab.
- **Reject reason:** the sheet offers three reasons ("value exceeds the agreed limit",
  "incomplete data", "another reason" which requires a note) plus a note. The mutation
  takes one `reason` string, so the app sends `"<reason> — <note>"`.

Needed from the backend:
- **Structured rejection:** accept `reasonCode` (enum) + `note` instead of one free
  string, so reasons can be localized, counted and shown to the agent in their language.
  The preset list is a product decision (confirm the three reasons).
- **Notify the sub-agent** on approve / reject (with the reason and note); the sheet's
  label says "Note for the agent".
- **Approvals count:** the badge counts `getPendingApprovalRequests`, loaded with the
  agents list; a lightweight count (or a push) would keep it fresh without a reload.
- **Request fields:** each approval shows sub-agent name, service, traveler count and
  value. The traveler names, documents and the request detail are not reachable from
  the card (no sub-agent request detail screen); decide whether the master can open the
  request before approving.
- **Fund response:** the success message reads the agent's balance from the updated list
  returned by the mutation; confirm the mutation returns the new balance atomically.
- **"Search / segment empty" copy** is local; nothing needed.

## 19. Booking drafts (Figma REQ-01 … 04)

Drafts are **local to the device**: leaving the traveler form with data entered
asks to save it; the Requests screen header shows a drafts button with a count;
the list resumes (Continue), deletes with confirmation and an Undo toast. Rules:
at most 10 drafts, deleted automatically 30 days after the last edit, sending a
resumed booking deletes its draft.

Storage: encrypted platform storage (Keystore / Keychain), one document per agent
(`booking_drafts_v1:<userId>`), because drafts hold passport data. Nothing is sent
to the backend.

Why this is a decision for backend / product, not just a client detail:
- **Not synced.** Drafts do not follow the agent to another device or survive an app
  reinstall / "clear data", and a sub-agent's drafts are invisible to the master. If
  they should, the backend needs `saveBookingDraft` / `bookingDrafts` /
  `deleteBookingDraft` (same 10 / 30-day rules, enforced server-side). The client
  already isolates storage behind `BookingDraftRepository`, so switching is one data
  source.
- **Session-expired drafts (AUTH-13).** The expiry dialog says nothing about saving
  (section 12): the booking form is not auto-saved when the session ends. With
  server drafts this could be done; locally it would need a save before the logout.
- **PII at rest.** Passport numbers are stored encrypted on the device; confirm this
  is acceptable for the product's data policy, and whether drafts must be wiped on
  sign-out (today they stay for that user id).
- **Uploaded documents are not part of a draft:** the booking form has no document
  upload yet (section 4), so the "uploaded documents (2)" row of Figma REQ-04 is not
  shown. When uploads exist, a draft must reference them (and they need retention).
- **Service withdrawn since saving:** the app says so and does not open the form.
- **Entry from Requests (06):** Figma lists drafts as "filter / section" there; the
  app adds a header button with a badge (the requests list itself is the server's
  list). Drafts are not mixed into it.
- Not built: the "Draft · 3" count chip variant of REQ-02 (no place uses it yet).

## 20. Request status screens (Figma REQ-06 / 07 / 08 / 09)

The request detail now has its own screen for: waiting on the main agent (06),
waiting on management (07), rejected (08), cancelled (09) and expired (09). The
other statuses keep the existing ticket + stages screen. The placeholders below are
queried with the request detail (`requestDetail` / `cancelRequest`); debug builds
fall back to canned data (SB-1007 rejected, SB-1008 / 1011 cancelled / expired,
SB-1009 / 1010 waiting for approval).

Added to the request detail (all optional; screens degrade when absent):
```graphql
approval { kind(MASTER_AGENT|MANAGEMENT) approverName typicalWaitMinutes thresholdAmount }
rejectionReason            # the authority's text
cancellation { cancelledBy cancelledAt reason code }   # code DEADLINE_EXPIRED = automatic
refundedAmount             # decimal string: what went back to the wallet
mutation RemindApprover($requestId: ID!) -> { success }      # new
```

Needed from the backend / product:
- **Approver and the reason approval is needed.** The banner texts ("exceeds your
  limit" / "exceeds 2,000 USD") are built from `approval.kind` and `thresholdAmount`;
  the typical wait comes from `typicalWaitMinutes` (measured, not guessed). Without
  them the screen shows the generic wording / omits the time.
- **Reminder rules:** `RemindApprover` should notify the approver (push / SMS / email),
  be rate limited (`RATE_LIMITED` with `retryAfterSeconds`; the app then says "you
  reminded them recently, again in mm:ss"), and refuse when the request is no longer
  waiting. Decide the cooldown (the app never invents one).
- **Rejection reason:** free text from the authority today. A code + text would let the
  app localize and offer the right fix. When no reason arrives the app says so and points
  to support.
- **Cancellation record:** who (name + role), when, reason; `code: DEADLINE_EXPIRED`
  marks the 72 h automatic cancellation, shown as "Expired". The app also treats an
  "info required" request whose deadline already passed as expired (client clock), until
  the server has cancelled it.
- **Refund amount** is shown only when `refundedAmount` is returned; the app never
  computes a refund. "The held amount was returned" is the server's promise: the amount
  and time must match the wallet ledger entry of the release / refund.
- **"Correct and resubmit" / "New request with the same data"** need the request's full
  form data to prefill the booking (service id and every traveler's fields). The detail
  only has names and passport numbers, so both buttons open the service catalog empty.
  Proposed: `requestAsDraft(requestId)` returning a draft payload (or the form values in
  the detail), which the app turns into a local draft (section 19) and opens.
- **Statuses with no screen of their own:** processing / completed / under review keep the
  old layout; Figma has nothing for them in this pass.

## 21. Cancel request (Figma REQ-10 / 10b)

The cancel confirmation is now a reason sheet (customer cancelled / data error / delay /
other) with a refund note, and a dialog explains when the request cannot be withdrawn.

- **`cancelRequest(requestId, reason)`**: `reason` is a new optional argument of the enum
  `CancelReason` = `CUSTOMER_CANCELLED | DATA_ERROR | DELAYED | OTHER` (placeholder,
  `TODO(backend-contract)`). Store it on the cancellation record so the cancelled screen
  (section 20, `cancellation.reason`) can show it; the app sends the code, not the label.
- **Not cancellable:** when a request is already with the authority the mutation must fail
  with `code: NOT_CANCELLABLE`. The app then shows "can't cancel now" with a support
  shortcut. The client only hides the cancel button for statuses it knows are final; the
  server stays the authority on what can be withdrawn (e.g. `processing` can be either).
- **Refund note:** "returned to your balance within minutes" shows the request's total
  price; it is a server promise. The refund amount / timing must match the wallet ledger
  entry written at cancellation, and the real amount should come back in `refundedAmount`.
- Debug builds: the sample request `SB-1012` (processing) answers `NOT_CANCELLABLE`.
