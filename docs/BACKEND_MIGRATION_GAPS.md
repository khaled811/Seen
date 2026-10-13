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
