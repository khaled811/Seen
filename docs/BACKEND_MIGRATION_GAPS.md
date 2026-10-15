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
