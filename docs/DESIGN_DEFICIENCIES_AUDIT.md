# Design Deficiencies Audit: Figma file vs. the implemented app

**File:** `PB4FpTNBHkNZzIYknxA5Tp` (pages: 00 Screens, 01 Foundations, 02 Components)
**Scope:** the 18 mobile frames (01–18), the component page, and the Flutter app
as of commit `648b3fc` (Auth, Home, Requests, Catalog / Booking, Wallet,
Sub-agents, Account, Support / Notifications).
**Method:** every frame and the whole components page were read through the Figma
connector; they were then cross-checked against the code (screens, sheets, error
types, flows). No production code was changed for this audit.

How to read it: each item says **what is missing or wrong**, **where the app
stands in the meantime**, and **what the designer should deliver**. Items are
grouped by priority:

- **P0, Critical blockers:** a business flow or a safety state has no design, so the
  app either ships a stopgap or cannot ship the feature.
- **P1, UX / flow gaps:** the feature works, but the design is incomplete or
  ambiguous.
- **P2, Visual polish / edge cases.**

---

## 0. Executive summary

1. **The 18 frames are the happy path only.** There is no error, offline, session
   expiry, loading (skeleton) or most empty state in any frame.
2. **Several flows the app already has are undesigned:** booking success, document
   viewer, support tickets (list / create / detail), sub-agent approvals and reject
   sheet, fund-agent sheet, logout confirmation, statement export. Their current
   look is improvised by engineering.
3. **Several buttons in the frames lead nowhere:** "View documents" (07), "Add agent"
   (13), "Agency details / Profit margin / Users & permissions / Settings / Help"
   (14), "Statement" (11), "Forgot password" (03), "Transfer to agent" (11), the
   pending top-up card (11), every ledger row (11).
4. **The most important missing flow:** a request that is *awaiting a document*
   (the amber state on 05, 06 and 07) has no screen to upload that document.
5. **The mocks contradict each other and the backend in places:** wallet numbers do
   not reconcile between 10 and 11, the same request is "processing" and "with the
   authority" at once, counts of the same thing differ on one screen (3 / 3 / "two"),
   the stepper on 09 labels the current form as a completed step, and a static IBAN,
   "monthly profits" and a "minimum 50 USD" have no source.
6. **The component library covers about a third of what the frames need.** Buttons
   and inputs have states; sheets, dialogs, toasts, banners, skeletons, toggles,
   checkboxes, list rows, pickers and tabs-with-badge do not exist as components.
7. **Frames are fixed 390 × 844 absolute layouts** with iOS-only assumptions (44 px
   status bar, 28 px home-indicator padding), hard spacers (90 / 120 / 160 px) and
   `nowrap` text. They say nothing about tall Android screens (20:9), small phones,
   the keyboard, large text, English / LTR or dark mode.
8. **Accessibility:** the muted text colour (`#8A83A8`) and white-on-light-violet
   text fail WCAG AA at the sizes used, and many tap targets are 28–36 px.

---

## 1. Missing core screens and flows

### P0, Critical blockers

| # | Missing | Why it blocks | In the app today | Designer should deliver |
|---|---|---|---|---|
| 1.1 | **Upload a missing document** for a request in "awaiting document" (amber chip, 72 h banner on 06, deadline card on 07) | This is the main reason agents open the app urgently, and the 72 h countdown has nothing to act on | The banner and the amber cards are display-only | Flow from the card / banner: which document is missing and why (rejection note), capture or pick, preview, upload progress, success, retry, "deadline passed" state |
| 1.2 | **Booking success / receipt / confirmation** | End of the main money flow (a wallet hold was just made) | `BookingSuccessScreen` exists, designed by engineering | Success frame: request number (copyable), held amount, balance after, ETA, "track request" and "new request" actions, share / download receipt |
| 1.3 | **Password recovery** (03 "Forgot password?") | Login without recovery locks users out | The link shows "coming soon" | Request (phone / email), OTP, new password with rules, success, expired / wrong code, rate-limit |
| 1.4 | **Document viewer** (07 "View documents", issued visa / approval files) | The deliverable of the whole product is a document | A bottom sheet with no files | List of documents per traveler, in-app PDF / image viewer (zoom, pages), download, share, "not ready" and "failed to load" states |
| 1.5 | **Sub-agent creation and limit management** (13 "Add agent", "Edit limit") | The FAB on 13 and the planned "Edit limit" action have no destination | FAB says "coming soon"; only a fund sheet exists | Create form (fields, validation, credentials / invite), edit credit limit, suspend / reactivate with confirmation, success and error states |
| 1.6 | **Registration completeness** (15 → 16) | 15 has no password, no phone verification, no terms consent; "Step 1 of 2" has no step 2 other than the waiting screen | Form goes straight to the pending screen | Password creation, OTP for the phone given (the helper text promises it), terms checkbox with links, and what "Step 2" is |
| 1.7 | **Error, offline and session-expired surfaces** (see 2.2) | Every network call can fail | Snackbars and per-screen text | See 2.2 |

### P1, UX / flow gaps

| # | Missing | In the app today | Designer should deliver |
|---|---|---|---|
| 1.8 | **Dynamic-form pickers** used on 09: nationality picker, date picker sheet, select sheet, **document attachment sheet** (camera / gallery / files) | Generic bottom sheets and the platform date picker | Each picker as a frame: search, long list, selected state, empty search. For attachments: camera capture + crop, gallery, file, size / type errors. The dropzone on 09 says "drag", which is not a mobile gesture |
| 1.9 | **Support** (14 "Help & support", Home chat button, 07 "Support"): ticket list, create ticket, ticket detail / thread, attachments | Three screens exist (`support_tickets`, `create_ticket`, `ticket_detail`) without frames | Full support cluster, including empty list and closed ticket |
| 1.10 | **Sub-agent approvals** (pending requests from agents) and the **reject reason sheet** | `SubAgentApprovalScreen` exists but is no longer linked from 13 | Where it lives (Account? a tab badge?), the list, approve / reject confirmation, reason sheet |
| 1.11 | **Fund sub-agent sheet** | Exists in code | Amount, balance check, confirm, success, insufficient master balance |
| 1.12 | **Account rows without destinations** (14): Agency details, Profit margin, Users & permissions, Settings, Notifications preferences | Info sheet / "coming soon" / a sheet with language and theme | Agency & commercial-register details, margin screen, users and roles (invite, edit role, deactivate), settings (language, appearance, notification toggles) |
| 1.13 | **Logout confirmation** | A dialog designed by engineering | Dialog component |
| 1.14 | **Wallet drill-downs:** transaction detail (tap on a ledger row), top-up detail / status (tap on the pending card), **statement export** (period picker, format, result) | Rows are not tappable; statement is an info sheet | Frames for each |
| 1.15 | **Top-up confirmation** after "Send top-up request" | A snackbar and pop | Confirmation frame with reference, expected review time, link to the pending item |
| 1.16 | **Request detail variants:** rejected (reason, resubmit), cancelled, completed (download), cancel-request confirmation with reason | One variant (processing) | One frame per terminal status (the status chip set has 12; the frames use 4) |
| 1.17 | **Search and filter results** (Home search pill, 06 search) | 06's search UI was removed to match the frame | Search frame: field, recent searches, results, no results |
| 1.18 | **Terms & Privacy** pages (02, 15 consent) | Plain text | Reader screen |
| 1.19 | **Hotels "Soon"** tile (05, 08): what happens on tap | Does nothing | "Notify me" or an info sheet |
| 1.20 | **Add / remove / switch travelers** on 09 (the frame says "Traveler 1 of 3" with no control) | Chips row added by engineering | Traveler switcher, add, remove, per-traveler validity |
| 1.21 | **Permission prompts and rationale** (notifications, camera, photos), **force-update** and **maintenance** screens | None | Frames |

### P2

- 1.22 First-run onboarding / language choice (the app supports Arabic and English).
- 1.23 Biometric unlock, if planned.
- 1.24 "Rate / feedback" after a completed request, if planned.

---

## 2. Missing component and state variations (state matrix)

### 2.1 What the component page contains

| Component | States present | States missing |
|---|---|---|
| Button | **M**: Default, Pressed, Disabled, Loading for Primary / Secondary / Outline / Dark / Destructive | **L, S, XS exist only as Default**: no pressed / disabled / loading (L is used on 02, 03, 04 and has a loading state in the app); no icon-only, no icon + label |
| Input | Default, Focused, Valid, Error, Disabled | Multi-line, search field, password with toggle, phone with prefix (used), dropdown / picker field, read-only, field with trailing action, counter |
| OTP box | Empty, Filled, Active | **Error** (wrong code), Disabled / verifying, filled-and-masked |
| Status chip | 12 statuses × S / M | Frames use only 4 of the 12 (`new`, `processing`, `action`, `completed`) plus `review`; the `authority`, `urgent`, `submitted`, `confirmed`, `rejected`, `cancelled`, `expired` chips are never placed on a card or screen |
| Countdown pill | Warm, Urgent, Expired | Only Warm is used in frames |
| Request card | processing, action, completed, new | rejected, cancelled, expired, authority, urgent; loading skeleton |
| Service tile | Default, Soon | Pressed, Disabled, long-name (2 lines) |
| Balance card | one state | **Hidden balance** (the eye toggle exists but no hidden state is drawn), loading, error, zero balance, negative / over-limit balance |
| Tab item / Tab bar | Default, Active | **Badge** (pending approvals, unread), disabled |
| Segmented control, tab chips | selected / unselected only | Disabled, with counts, scrollable overflow (06 chips are cut off at the screen edge in the frame) |
| Icons | 33 icons | Used in frames but absent from the set: copy, filter, download, edit, globe, moon / sun, lock, share, trash, info, chevron (the 14 menu chevron is a loose vector). In the set but unused: umrah, ticket, calendar |

**No components exist for:** bottom sheet, dialog / alert, toast / snackbar,
inline banner (offline, error, info), list row / menu row, skeleton, empty state
(drawn only as one-off art on 18), checkbox, radio, switch, date picker, progress
bar (drawn ad hoc on 05, 07, 11, 12), stepper (drawn ad hoc on 07, 09, 16),
avatar, badge / dot, pull-to-refresh, search field.

### 2.2 Error and network states (P0)

None of the 18 frames has any of these. The app currently improvises each as text
or a snackbar.

- **Offline:** persistent banner and the behaviour of cached data (stale marker).
- **Request failed / server error:** inline error with retry, full-screen error,
  error sheet for failed mutations (top-up, booking submit, funding, cancel).
- **Timeout** and **slow network** (long loading).
- **401, session expired:** the app signs the user out silently (`AuthSessionInvalidated`
  → Welcome). Design a dialog or screen that says why, and where the user lands.
- **403, not allowed:** per-action "you don't have permission" (the code treats 403
  as a denial, not a logout).
- **Maintenance / force update.**
- **Partial failure:** one section of Home fails while the others load (Home has
  four independent sections: balance, greeting counts, services, recent requests).

### 2.3 Empty states (P1)

Only **18 (requests, none yet)** is drawn. Missing:

| Screen | Empty case |
|---|---|
| 05 Home | No requests ("recent requests"), zero balance / first-time user |
| 06 Requests | A filter that matches nothing; search with no results |
| 11 Wallet | **Ledger with 0 transactions**; a segment (Debits / Credits) with 0 rows |
| 13 Sub-agents | **No agents yet**; search with 0 results; the Suspended segment with 0 |
| 17 Notifications | **No notifications** (engineering reused the 18 art) |
| 08 Catalog | Search with no results; catalog failed to load; no bookable service |
| 09 / 10 | Review with zero travelers (should be impossible; define the guard) |
| Support | No tickets |
| 07 | No documents yet; no timeline entries |

### 2.4 Loading states (P1)

No skeletons for: balance card, request cards, ledger rows, agent cards, stats,
notification cards, ticket, catalog tiles. Also missing: pull-to-refresh
indicator, button loading for L / S / XS, "uploading" for the dropzone (only one
static 68 % frame on 12), full-screen first load.

### 2.5 Form validation and edge cases (P1)

The Input component has an Error state, but **no frame uses it**. Needed, per form:

- **03 Login:** invalid phone format, empty password, wrong credentials, account
  suspended / pending, too many attempts (lock timer).
- **04 OTP:** wrong code (error boxes + message), expired code, resend cooldown
  finished, too many attempts.
- **12 Top-up:** amount empty / zero / below minimum / above limit, missing
  reference, missing receipt, file too large / wrong type.
- **09 Form:** passport number format, expiry too soon (the app has a "valid for at
  least 6 months" rule that the frame never shows), duplicate passport, date in the
  future for birth date, missing required file. The frame shows "٨ خانات" as helper
  text with no rule behind it.
- **15 Create agency:** duplicate phone / email / license, invalid email, invalid
  license number, password rules (if added), missing consent.
- **Field-level success** (the Valid state) is only drawn on the name field of 09 and
  15 and means "verified", which the backend cannot do today.
- **Mismatched passwords** and **password strength** (no password-creation frame
  exists at all).
- **Keyboard behaviour:** sticky action bars on 09, 12, 15 collide with the keyboard.
  Specify: bar rides above the keyboard, or hides.

### 2.6 Interactive states (P2)

- Pressed / hover / focus-visible for: cards (request, service tile, notification),
  list rows, chips, segmented control, text links, icon buttons, tab items.
- Disabled for: chips, segmented control, links, icon buttons, tiles.
- Focus ring for keyboard / switch-access users.
- Selected + disabled combinations (method cards on 12).
- Long-press, swipe (notification swipe to read, row actions), pull-to-refresh.

---

## 3. Data and schema inconsistencies

Where the mocks demand data that contradicts itself, realistic business rules or
the backend schema. Each needs a **designer or product decision**; the backend
list is in `BACKEND_MIGRATION_GAPS.md`.

### P0

| # | Inconsistency | Frames | Decision needed |
|---|---|---|---|
| 3.1 | **Wallet numbers do not reconcile.** 11 shows balance 1,532.00 with held 210.00 and "available 1,322.00" (so 1,532 is the *total*). 10 shows "available after hold 1,382.00" = 1,532 − 150 (so 1,532 is treated as the *available* amount, ignoring the 210 already held). | 10, 11 | Define: is the big number total or available? After a 150 hold with 210 already held the available figure is 1,172, not 1,382 |
| 3.2 | **Balance caption "رصيد دائن" (credit balance)** sits next to "credit limit 2,000". A credit balance and a credit limit are different concepts (prepaid vs. credit line). The model (available / held / credit limit) is unclear: can the balance go negative up to the limit? | 05, 11 | Name and formula for each number |
| 3.3 | **Static bank details** (bank "الكريمي", IBAN, beneficiary) with no bank entity, per-currency or per-method variants. 12 also shows the **"Electronic wallet"** method, which has no data model, and "Minimum 50.00 USD" with no rule. | 12 | Where the account comes from; which methods exist; real minimum |
| 3.4 | **One request, two phases.** 07 shows chip "processing" while the stepper's current stage is "with the authority" and the deadline card says "remaining time for the authority's reply". The chip set has an `authority` chip that is never used. On 06 / 05 the same request ("with the authority · 3 of 5") also wears the "processing" chip. | 05, 06, 07 | Status ↔ stage mapping table |
| 3.5 | **Stage names disagree.** Cards: "Issued · 5 of 5". Tracking: stage 4 "Issuing approval", stage 5 "Delivery". The card calls the last stage "issued", the stepper calls it "delivery". | 06, 07 | One vocabulary for the five stages |
| 3.6 | **Counts disagree.** 06: "awaiting action 3" (stat), "3" (chip), "two requests awaiting documents" (banner), and only one action card visible. 05 greets "3 requests need follow-up" with one action card. Stats 8 + 3 + 12 = 23 ≠ 24. | 05, 06 | Define each count's rule (what counts as "needs follow-up") |
| 3.7 | **"Monthly profits / أرباح الشهر 1,240.00 USD"** as the lead metric of Sub-agents: there is no profit ledger, no commission model, and the card shows agent *balances*, not earnings. | 13 | Does profit exist? From what rule? |
| 3.8 | **Registration vs. login identity.** 15 asks for phone + email, 03 logs in with phone (the backend also accepts email), and 03 promises an OTP after the password (two factors). 15 has no password. | 03, 04, 15 | One identity and credential model |

### P1

| # | Inconsistency | Frames |
|---|---|---|
| 3.9 | **Stepper mislabels the step** on 09: header says "Step 2 of 3", the stepper shows "Traveler data" as done and "Documents" as current, but the form on screen *is* the traveler data (with the passport upload). The catalog (service choice) is not counted as a step. | 09 |
| 3.10 | **"Traveler 1 of 3"** implies a known traveler count, but the previous step (catalog) never asks for it. | 08, 09 |
| 3.11 | **Fees:** 10 shows "authority fee 0.00" as a row; the API exposes one price per traveler. "Deducted permanently when the visa is issued" states a refund policy (what happens on rejection or cancellation?) that appears nowhere else. | 10 |
| 3.12 | **Sub-agent card** shows "Aden · 34 requests" (city and request count) which the agent model does not have; "Edit limit" is not on the card. The stat "12 active agents" sits above a list of 4 agents (pagination, or a count from elsewhere?). | 13 |
| 3.13 | **Agency name varies:** "جُباري للسفر" (05 greeting), "جُباري للسياحة والسفر" (12, 14, 15), "Jubari Travel" (01). Beneficiary of the top-up is the *platform* ("جُباري للسياحة والسفر") while the same name is the *agent's agency* on 14. | 01, 05, 12, 14, 15 |
| 3.14 | **Notification examples contradict statuses:** "Your request is with the authority · SB-20481" (read, yesterday) while 05 / 07 show the same request as processing today; "Visa issued, Ahmed Saleh Alawlaqi · SB-20470" is `completed` on 06 with "issued · 5 of 5". Fine, but the times ("10 minutes ago") are static; the date format is not defined. | 06, 17 |
| 3.15 | **Account "verified" chip** ("مؤكدة") implies an agency verification status that the session does not carry; 16 implies pending → active, with no "rejected / suspended" counterpart. | 14, 16 |
| 3.16 | **Upload semantics:** 12 shows an upload at 68 % with the submit button already enabled; 09 shows "ready" file `photo_mohammed.jpg · 1.2MB` beside a dropzone that still invites another upload. Max size / types differ ("PDF or JPG · up to 5MB" vs "PDF or image · up to 5MB"). | 09, 12, 15 |
| 3.17 | **Currency:** USD is hardcoded everywhere ("USD" after the number, "$" never). The preset chips show bare numbers (100 / 250 / 500 / 1,000) while the field shows "500.00 USD". Single-currency assumption is never stated. | 10, 11, 12, 13 |

### P2

- 3.18 **Numerals policy is not documented.** The frames mix Arabic-Indic digits (counts,
  dates: "١٢ نوفمبر") with Latin digits (money, references, clock times, the date in
  the date field "2029 / 04 / 18"). The app follows a rule (counts and dates Arabic-Indic,
  money / references / phone / times Latin); the designer should confirm or change it.
- 3.19 **Headline kashida:** the Welcome title is drawn with literal tatweel
  characters (`أهـلًا بـك في سيــــن أعمـــال`). In code this breaks search,
  copy / paste and screen readers and depends on the font. Deliver it as a typographic
  rule (font feature) or as artwork.
- 3.20 **Date format:** "١٢ نوفمبر · 09:14" (day + month name) on 07 / 11 / 17 vs "dd/MM/yyyy"
  numeric dates elsewhere; relative time ("قبل ٣ ساعات") thresholds are undefined.
- 3.21 **Seen "Umrah" tile / icon** exists in the icon set but no service uses it, while 07 / 10
  show "عمرة · دخول واحد · ٩٠ يومًا" as a service detail with no schema.

---

## 4. Design-to-code responsive inconsistencies

### P0

| # | Defect | Where | What to specify |
|---|---|---|---|
| 4.1 | **Fixed 390 × 844 frames built with absolute positions and hard spacers** (`90`, `120`, `160`, `152` px). A tall Android phone (412 × 915 dp, 20:9) has 70+ px more height, a small phone (360 × 640) has 200 px less. | 02, 03, 04 | Say what flexes: pin the CTA to the bottom and let the space between grow; define minimum heights and when the page scrolls |
| 4.2 | **02 Welcome has zero slack:** 80 + 300 hero + 40 + copy + 152 + 58 + 16 + 52 + 16 + terms ≈ 844. Any text scaling, a taller status bar or a shorter screen forces scrolling with the buttons off screen. | 02 | Hero-card height rule (aspect ratio, max / min), minimum bottom margin |
| 4.3 | **Sticky action bars assume iOS** (28 px bottom padding for the home indicator). Android gesture / 3-button navigation, display cutouts and the keyboard are not addressed. | 09, 10, 12, 15, 16, 07 | Bar anatomy: content padding, safe-area handling, keyboard behaviour (rides above or hides), scroll content padding so the last field is not hidden under the bar |
| 4.4 | **Status bar and top offsets:** frames put content at 52–80 px assuming a 44 px iOS bar. Android bars are 24 dp; iOS with a Dynamic Island is 54–59 pt. "80 px from the top" (02, 03, 04) is ambiguous: from the screen edge or below the safe area? | all | Define top offsets relative to the safe area |
| 4.5 | **Frames have different heights** (844, 950, ~1020, taller scrolling ones) with the tab bar drawn at the bottom of each. It is unclear which content scrolls and which is pinned (06 / 05 / 13 / 14 show content past the viewport). | 05, 06, 11, 13, 14 | Mark scroll regions; pinned header / tab bar; where the extended FAB floats (13: 18 px above the bar) |

### P1

| # | Defect |
|---|---|
| 4.6 | **`nowrap` text everywhere** in the frames: long Arabic names, agency names, service names ("موافقة الأمن الوطني المصري"), notification titles and amounts have no wrapping, truncation or two-line rule. Three service tiles per row leave about 96 px for a 13 px label; some real names wrap to two lines. |
| 4.7 | **Large text / display scaling:** no frame at 130 % or 200 %. Fixed heights (button 52, input 54, chips 36, tiles 104) clip. |
| 4.8 | **English / LTR** is not drawn although the app ships an English locale: mirrored order, icon directions (chevrons, back, progress), number placement. Every frame is RTL Arabic only. |
| 4.9 | **Two gutters:** tab screens (05, 06, 11, 13, 14) use 14 px side margins with a start-aligned H1; flow screens (08–10, 12, 15–17) use 20 px with a centred title. 14 px is below the 16 px minimum most guidelines use. State it as intentional or unify. |
| 4.10 | **Tablet / landscape / foldables:** no layout. The app caps content at 440 px on wide screens. |
| 4.11 | **Chips row on 06 is clipped at the edge** in the frame (the "completed" chip is cut). Define horizontal scroll, fade edge and the selected chip auto-scroll. |
| 4.12 | **Hero / illustration scale:** 02's hero is 350 × 300 at a fixed ratio; on a 360 dp-wide phone it shrinks, and on a tablet it should stop growing. |

### P2

- 4.13 **Dark mode:** not designed (the code ships a legacy dark theme that matches nothing).
- 4.14 **Status colours** in dark mode and the glow / gradient behaviour on OLED.
- 4.15 **Motion:** transitions between steps (09 → 10), the splash exit, countdown tick, pull-to-refresh, skeleton pulse. No motion spec beyond the two icon animations already bundled.
- 4.16 **Gradient and shadow tokens** are used in 20+ places with slightly different stops (`#c3b0fc` vs `#9b7df8` ends); consolidate in the foundations page.

---

## 5. Accessibility (P1)

| # | Finding | Evidence |
|---|---|---|
| 5.1 | **Muted text fails contrast.** `#8A83A8` on white is about 3.5 : 1; used for 11 px captions, placeholders, ledger dates, notification meta. AA needs 4.5 : 1 at that size. | 05–18 |
| 5.2 | **White text on the light end of the CTA gradient** (`#9B7DF8`, about 3.2 : 1) for 15–18 px button labels; **white on `#C3B0FC`** at the light end of the balance / bank cards is about 1.9 : 1 (the 11 px meta chips and the bank-details labels sit there). | 02–04, 10, 11, 12 |
| 5.3 | **Small touch targets:** status chips (28), XS buttons (32), segmented pills (34), filter chips (36), text links without padding (13 px "عرض الكل", "تعديل", "كشف الحساب"), the IBAN "نسخ" pill (~28), stepper dots. Recommended: 44 pt (iOS) / 48 dp (Android). | 05, 06, 10–13 |
| 5.4 | **Colour as the only signal:** debit / credit (red / green) with a sign, good; progress bars (amber / violet) and chips rely on colour plus text, good; the unread dot on 17 is colour only. | 17 |
| 5.5 | **No focus order / semantics notes** (which element reads first in RTL; grouping of the amount + currency; the OTP boxes as one field). | all |
| 5.6 | **Text alternatives for illustration and the logo** are not specified. | 01, 02, 16, 18 |
| 5.7 | **Reduced motion:** nothing defined for the splash, skeleton pulse and countdown. | 01, 06 |

---

## 6. Suggested hand-off checklist for the designer

**P0 deliverables (blocks release)**
- [ ] Upload-missing-document flow for "awaiting document" requests
- [ ] Booking success / receipt
- [ ] Password recovery (4 frames)
- [ ] Document viewer and the documents list
- [ ] Sub-agent create, edit limit, suspend / reactivate
- [ ] Registration: password, phone OTP, terms, the real "Step 2"
- [ ] Error / offline / 401 / 403 / maintenance patterns (banner, inline, sheet, dialog, screen)
- [ ] Decision sheet resolving 3.1 – 3.8 (wallet maths, status ↔ stage, counts, profit, identity)
- [ ] Responsive rules for 02 – 04 and every sticky bar (4.1 – 4.5)

**P1 deliverables**
- [ ] Empty and loading states for every list (2.3, 2.4)
- [ ] Validation / error states for every form (2.5)
- [ ] Picker set (nationality, date, select, attachment) and support cluster
- [ ] Wallet drill-downs, top-up confirmation, statement export
- [ ] Request detail for all terminal statuses, cancel with reason
- [ ] Components: sheet, dialog, toast, banner, skeleton, list row, checkbox, switch, avatar
- [ ] State matrices for Button L / S / XS, OTP error, Balance card, Tab badge
- [ ] Accessibility fixes: contrast tokens and 44 / 48 targets
- [ ] LTR / English frames and a text-scaling pass

**P2**
- [ ] Dark mode, motion spec, tablet layout, numerals / date-format policy, tidy gradient tokens

---

## 7. What engineering did meanwhile (so the designer knows what to replace)

- Every undesigned state uses the existing tokens and components, with plain
  snackbars, centred text and generic bottom sheets.
- Unavailable actions say "coming soon" or explain the missing capability; nothing
  is faked (see `BACKEND_MIGRATION_GAPS.md`).
- Where a frame contradicts the data model, the app shows the real data and not the
  mock (for example total agent balances instead of "monthly profits", no fabricated
  IBAN in release builds).
- The 18 frames were implemented as drawn. Three product decisions then overrode
  the frames, and the designer should draw them:
  1. **06 Requests:** the debounced reference / traveler search is kept (a search
     button next to the plus button opens a search field).
  2. **17 Notifications:** "Mark all as read" is kept in the header.
  3. **02 Welcome:** the headline and subtitle are centred (the frame aligns them to
     the start edge).
