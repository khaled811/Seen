# Seen Booking — Agent App: Screen & Feature Spec (design handoff)

Source: current code under `lib/features/` (spiritual module excluded; it is behind `kEnableSpiritualHub = false`).
Languages: Arabic (default, RTL) + English. Light + dark theme. Currency: USD only. Amounts are always LTR + tabular figures.
Status vocabulary comes from `SeenStrings` (fixed: never invent synonyms).

---
## 0. Global frame

**Navigation (AgentShell)** — bottom bar, 5 tabs: `Home · Requests · Wallet · Agents (sub-agents) · Account`.
- Tabs 1–4 are pages inside the shell (bar stays). Tab 5 (Account) opens a bottom sheet, not a page.
- Pushed flows (booking, request detail, notifications, support) hide the bar; booking uses a sticky **ActionBar** instead.
- Top bars: `home` variant (org avatar-initial + company + agent id, language toggle, theme toggle, bell with unread badge) and `inner` variant (back, centered title + subtitle, trailing action).
- Every list screen has: skeleton/loader, error + Retry, empty state, pull-to-refresh.

---
## 1. Screen inventory

| # | Screen | Type | Entry |
|---|---|---|---|
| 1 | Splash | page | app start / auth loading |
| 2 | Login | page | unauthenticated |
| 3 | OTP Verification | page | after login |
| 4 | Home (Executive Dashboard) | tab 1 | after auth |
| 5 | Notifications | pushed | bell icon |
| 6 | Requests Dashboard | tab 2 / pushed | tab, "Requests" quick action, "See all" |
| 7 | Request Detail | pushed | request card, notification tap |
| 7a | Cancel-request confirm | bottom sheet | Detail → Cancel |
| 7b | Detail overflow menu | popup menu | Detail ⋯ |
| 8 | Wallet | tab 3 | tab |
| 8a | Top-up Request | bottom sheet | wallet card "Top up" (also on Home) |
| 9 | Sub-Agents | tab 4 | tab, quick action |
| 9a | Fund Sub-Agent | bottom sheet | tap a sub-agent row |
| 10 | Pending Approvals (sub-agent requests) | pushed | file icon (badge) in Sub-Agents bar |
| 10a | Reject-reason | bottom sheet | Reject on an approval card |
| 11 | Service Selection (Egypt Approvals) | pushed | Home primary quick action; empty-state "Book new" |
| 12 | Traveler Entry | pushed | pick a service |
| 13 | Booking Review | pushed | Continue |
| 14 | Booking Success | terminal (replace) | submit OK |
| 15 | Support Tickets list | pushed | Home "Support"; Detail ⋯ → Contact support |
| 15a | Create Ticket | pushed | "+" in tickets bar |
| 15b | Ticket Detail (chat thread) | pushed | ticket card / after create |
| 16 | Account sheet | bottom sheet | tab 5 / Home "Account" tile |

Not built (empty dirs): `profile/`, `tickets/`, `notifications/` feature folders. **Account = sign-out only today.** There is no profile screen, settings, or password change. Flag to designer as a gap (see §6).
Dev-only (ignore): Dynamic Form Gallery, "Bypass Auth" button (debug builds).

---
## 2. Data & actions per screen

### 2 Login
- Hero: flight-pattern header, org initial tile, app title, "Sign In".
- Fields: identifier (email/username), password (show/hide eye). Button **Submit** (loading state). Failure → snackbar.

### 3 OTP
- Title "Verify Code", instructions, segmented OTP input (auto-submits at full length), **Submit**, resend link with live countdown ("Resend code in 42s" → "Resend code"). Failure → snackbar.

### 4 Home
- Top bar (home variant): company, agent id, language, theme (system/light/dark cycle), bell + unread.
- **Wallet card** (primary-colour, flight pattern): Available balance (big, USD), **Top up** button; sub-cells: **On hold · Total · Credit limit**.
- **Quick actions** (5 tiles): Egypt Approvals (primary) · Requests Dashboard (count badge = # action-required) · Sub-Agents · Support · Account.
- **Recent Requests**: header with red urgent count + "See all"; up to 5 request cards (action-required first, then newest). Empty message. Per-section error + Retry.

### 5 Notifications
- Bar: title + **Mark all read** (disabled if none unread).
- Filter chips: All · Unread (count).
- Grouped list; tile = kind icon/tone, title, body, time, optional request reference, unread dot. Tap → marks read; opens Request Detail if linked.
- Kinds → tones: review, action, approved, sla, wallet, agent, system.

### 6 Requests Dashboard
- Title + search toggle → search field (client-side over reference + service name).
- Filter chips w/ counts: **All · Under Review (submitted/pending approvals/under review/processing) · Completed · Action Required** (red alert style).
- **Request card**: reference (mono, LTR), status badge, service name, travelers count, date, amount; footer = SLA countdown tag (live) or red note (what to fix) for action-required; action-required card has red border.
- Sort: action-required → SLA < 24h (most urgent) → newest.
- Empty states: no data vs no search match; CTA "Book new".

### 7 Request Detail
- Bar: "Request Details" + reference subtitle; ⋯ menu: **Copy reference**, **Contact support**.
- Summary card: SLA tag + progress bar (elapsed of 72h; turns urgent < 24h), status badge, service name, "N travelers · submitted <date time> · held <amount>".
- **Travelers** list: number avatar, name, passport no. (mono), per-traveler approval badge (pending/approved/rejected), per-traveler download icon when approved.
- **Timeline** stepper: Submitted & funds held → Verifying documents → Under review at authority → Approvals issued & final deduction (future step shown greyed if not reached); each step has note or timestamp; under-review step shows expected hours.
- Sticky bottom: **Download issued approvals (N)** / "Approvals will be available once issued" (disabled).
- **Cancel request** (red outline) only when cancellable → confirm sheet (No / Yes).
- Failure of cancel → snackbar.

### 8 Wallet
- Bar: "Wallet" + refresh. Same wallet card (Available, Top up, On hold, Total, Credit limit).
- "Transactions" with chips **All · Credits · Debits**.
- **Ledger row**: credit/debit icon, type title, reference (mono), date-time, signed amount (+green credit), status badge only when not approved (pending/rejected). Empty text.

### 8a Top-up sheet
- Amount (USD, decimal), **method selector** (radio cards): Bank transfer — "Posts in 1–4 business hours"; Cash — "Confirmed by your branch the same day"; Exchange house — "Posts once the receipt is verified".
- Reference number (required), Notes (multiline, optional), Receipt upload row (**disabled, "coming soon"**). Submit; success snackbar + close.

### 9 Sub-Agents
- Bar: title + file icon with pending-approvals badge.
- "Pending Approvals" section (count, up to 3 approval cards, "See all" if > 3).
- "Branches" directory (list group): square avatar, name, code, margin tag (e.g. 12% or "—"), "Suspended" tag, balance. Tap → Fund sheet.

### 9a Fund Sub-Agent sheet
- Title "Fund <name>", subtitle = master available balance. Amount (USD, must be > 0 and ≤ master available). CTA label morphs: "Fund $X to <name>". Success snackbar.

### 10 Pending Approvals / approval card
- Card (amber border): avatar, sub-agent name, reference · submitted time, "Awaiting approval" badge; fact grid: Service, Travelers, Amount (and Branch margin when available); buttons **Reject** (red outline) / **Approve**; both disabled while acting.
- Empty message. Reject → 10a: "Reject this request?" with required reason, No / Reject.

### 11 Service Selection
- Bar "Services". Cards: icon tile, name, description, radio dot; facts row: **Price per traveler · Processing · Documents**. Non-bookable cards at 55% opacity with "Coming soon" tag.

### 12 Traveler Entry
- Bar "Traveler details". Chips per traveler (states: empty / done / error) + "Add traveler".
- Fields per traveler (Egypt services): Full name* (2–100) · Passport number* (6–20) · Nationality* · Birth date* (not future) · Passport issue date* (not future) · Passport expiry date* (≥ 6 months ahead).
- **Validity hint** under expiry: track on 24-month scale with 6-month tick; <6 mo red "will be rejected", 6–9 amber "accepted, renewal advised", ≥9 green.
- Attachment row (disabled, "coming soon"). "Remove traveler" (red outline, when >1). ActionBar: **Continue to review**.

### 13 Booking Review
- Breakdown table: service · "N travelers" · unit × qty · line total; total row "Total to hold" (USD).
- **Balance banner**: sufficient ("Balance covers this booking": Available / After booking) or red insufficient (+ Top up link).
- ActionBar: **Submit hold · $X** (loading state). Failure → snackbar.

### 14 Booking Success
- Green check circle, "Booking submitted" title/message, reference (mono, tap to copy), **Back to home**.

### 15 Support
- Tickets list: "+" to create. Card: subject, status badge, reference (mono), category, linked-request ref, date. Empty message.
- Create ticket: Category chips (**General · Financial Correction**), Subject*, Message* (5 lines), Request reference (optional, mono), Submit.
- Ticket Detail: header (subject, reference, linked request, status badge), chat thread (support = left/grey bubble, agent = right/accent bubble; author, body, timestamp), reply composer with send icon.

### 16 Account sheet
- Only **Sign Out** (red outline).

---
## 3. Status enums & flows

### Request status (`RequestStatus`, backend values)
`draft · submitted · pending_agent_approval · pending_management_approval · under_review · info_required · processing · completed · rejected · cancelled`

Display mapping (design-system 8-word badge vocabulary):
| Backend | Badge | Tone |
|---|---|---|
| draft, submitted, pending_agent_approval, pending_management_approval, processing | Awaiting approval (pending) | amber |
| under_review | Under review | amber |
| info_required | **Action required** | red |
| completed | Completed | green |
| rejected, cancelled | Rejected | red |

Badge words available: Under review · Awaiting approval · On hold · Action required · Rejected · Completed · Approved · Posted. Exact labels (finer than badge) are used in timeline: e.g. "Pending Agent Approval" vs "Pending Management Approval".

Flow (inferred from code; transitions are enforced by the backend):
`draft → submitted (funds HELD) → [pending_agent_approval (sub-agent request awaiting master agent) → pending_management_approval] → under_review/processing → completed (approval docs issued, final deduction)`
Side branches: `→ info_required` (agent must fix; **72h SLA countdown**) → back into review; `→ rejected` (policy `no_refund_on_rejection`); `→ cancelled` (agent action; allowed from any non-terminal status: draft…processing; not from completed/rejected/cancelled).
Per-traveler status: `pending · approved · rejected` (a request can be partly approved; download enabled per approved traveler).

### Other enums
- **Transaction type**: top-up, hold, final deduction, release, refund, settlement. **Status**: pending, approved, rejected. **Side**: credit/debit.
- **Top-up method**: bank transfer, cash, exchange house.
- **Ticket status (UI)**: open (pending badge), in progress (review), resolved (approved), closed (completed). Category: general, financial correction. Priority (not shown in UI yet): low, normal, high, urgent.
- **Notification event types**: new request, status update, info required, rejected, SLA breach, top-up, new agent signup, ticket update.
- **Agent entity**: status pending/active/suspended; tier A/B/C; position owner/branch manager/staff (not surfaced in UI yet, except "Suspended" tag).
- **Auth state**: initial/loading → OTP required → authenticated | unauthenticated/failure.
- **Async sub-states used across sheets**: idle → submitting → success | failure (top-up, funding, approve/reject, cancel, booking submit, ticket create/reply).

Permission codes gate UI (hide/disable): request.view/submit/cancel/approve, wallet.view/topup.request/topup.sub_agents, agent.create_sub_agent, ticket.*.create, pricing.view, data.export, etc.

---
## 4. Services list (exact, from code)

Category enum + mock catalog (real catalog comes from backend `AvailableServices` query):

| Service | Category | Price / traveler | Processing | Documents | Availability |
|---|---|---|---|---|---|
| Egypt National Security Approval (الأمن الوطني) | egypt_national_security | $150 (placeholder) | 3–5 business days | Passport copy, photo | **Bookable** |
| Egypt Military Intelligence Approval (المخابرات الحربية) | egypt_military_intelligence | $200 (placeholder) | 5–7 business days | Passport copy, photo, itinerary | **Bookable** |
| Egypt Airline Circular | egypt_airline_circular | — | — | — | Coming soon |
| Jordan Approvals | jordan_approvals | — | — | — | Coming soon |

Other service-related facts: pricing = per-person × travelers; 6-month passport validity rule; provider channels in backend enum (portal manual/automated, whatsapp, api) are not shown in UI. **The code has NO visa / hotel / flight / insurance services** — only the four above. Home quick action label for the booking flow is "Egypt Approvals".

---
## 5. Reusable components to design (design-system kit already in code)
TopBar (home/inner) · BottomNav · ActionBar (summary + 1–2 buttons) · SectionHeader (+urgent count + link) · ListGroup · Request card · Wallet card · Ledger row · Service card · Method selector · Breakdown table · Balance banner · Validity hint · Traveler chips · Status badge (8 words) · SLA tag (live countdown) · Status stepper · Approval card · Sub-agent row · Notification tile · Segment chips (with count/alert) · Text field (mono/LTR variants) · OTP input · Buttons (primary, secondary, danger-outline, ghost, small) · Sheet · Avatar · Tag · Loader/skeleton · Snackbar. Tokens: see `design_system.md`.

---
## 6. Gaps / things the designer should know
1. **No profile/account screen** — only sign-out. Needs design if intended (profile, language/theme, password, agent info/tier, staff).
2. **Mocked / disabled features**: approval document downloads (buttons do nothing yet), top-up receipt upload, traveler attachment upload ("coming soon" rows).
3. Request dashboard top bar currently has **hardcoded demo identity** ("شركة الجباري للسفر", "AG-10427") and a hardcoded sample action note; Home shows `userId` instead of a real agent name.
4. Sub-agent row supports a **users count** but data isn't supplied; "city" slot currently shows the agent code.
5. Approval card shows the reference where "branch" label is designed; branch margin value not yet provided.
6. Tab label "Agents" = Sub-Agents. Home quick actions duplicate bottom-bar destinations.
7. No pagination/filters on tickets, sub-agents, notifications; no staff-management, reports, or pricing/margin screens even though permissions exist for them.
8. Two ticket status enums exist (core: open/closed; support: 4 values) — UI uses the 4-value one.
