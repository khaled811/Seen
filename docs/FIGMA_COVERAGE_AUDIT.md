# Figma coverage audit — page "07 App · Report fixes"

Method: the 96 frames of the page were read from Figma (their text layers), each frame's Arabic
strings were looked up in the app's source and `app_ar.arb`, and the code was read where the strings
gave no clear answer. A low text match with real feature strings missing means "not built"; sample data
in the design (names, amounts, dates) never matches and is ignored. It is a string-level audit, not a
pixel comparison, and nothing was run on a device.

## Built to the design (57 frames)

AGT-01, 01b, 02, 03, 04, 05, 06, 07, 08 · AUTH-01, 01b, 02, 02b, 03, 04, 05, 06, 07, 13 · BOOK-01 ·
REQ-01 … 13 (incl. 05b, 10b, 11b) · SUP-01 … 05 · SYS-01, 02, 02b · WAL-01 … 11 (incl. 07b, 07c).

Known limits inside these (not gaps in the frames): PDF preview needs a PDF plugin; receipts and ticket
attachments have no upload API; the contact numbers come from build settings; every backend call uses
a placeholder contract (`docs/BACKEND_MIGRATION_GAPS.md`, sections 1–33).

## Not built to the design (39 frames)

Frames that exist in Figma but were never done on this page. "Partly" = the app has an older screen for
the same thing that does not follow the frame.

### Auth (7)
| Frame | Priority | What is missing |
|---|---|---|
| AUTH-08 Registration field errors | P1 | **Done** except the file-too-large error (no CR upload yet). See gaps section 30. |
| AUTH-09 Terms of use | P1 | Long-text screen with the update date, language switch, offline state. |
| AUTH-10 Privacy policy | P1 | Same as AUTH-09. |
| AUTH-11 Login failure states | P1 | **Done.** |
| AUTH-14 Logout confirmation | P1 | **Done.** |
| AUTH-15 Change password | P2 | Whole screen. |
| AUTH-16 Change phone number | P2 | Whole flow (OTP on the new number). |

### Booking (9, + BOOK-10 with no tracker row)
| Frame | Priority | What is missing |
|---|---|---|
| BOOK-02 Traveler switcher | P1 | **Done.** Switcher, limit 9, issue banner. See gaps section 31. |
| BOOK-03 Nationality picker | P1 | **Done.** Searchable sheet, recents (session), no-match. List is bundled (section 31). |
| BOOK-04 Date picker sheet | P1 | **Done.** Calendar sheet with the field range and the 6-month rule. |
| BOOK-05 Select options sheet | P1 | **Done.** Shared options sheet with search above 7 options. |
| BOOK-06 Attachment source sheet | P1 | **Done** on the device only: the file is not sent (no upload API, section 31). |
| BOOK-07 Field types | P1 | **Partly.** Select uses the sheet; counter, phone country code and read-only look are not built. |
| BOOK-08 Review: insufficient balance | P1 | **Done.** Shortfall card, top-up shortcut, blocked submit. |
| BOOK-09 Service coming soon | P2 | "Notify me" screen. |
| BOOK-10 Hospital quota & availability | — | Whole screen (medical service). |

### Requests (4, no tracker rows)
REQ-14 / 14b Group manifest (build, then summary with per-traveler status) · REQ-15 / 15b Airline circular
(pick an approved security request, then auto-filled). Whole flows; each needs new backend contracts.

### Account (7)
| Frame | Priority | What is missing |
|---|---|---|
| ACC-01 Agency details & commercial register | P1 | **Done** except edit and renew, which point to support (no contract). See gaps section 33. |
| ACC-02 Profit margin | P1 | **Done.** Per-service margins, read-only rows, change log (section 33). |
| ACC-03 Users and permissions | P1 | **Done.** Team list, roles, invite, change role, disable; owner only (section 33). |
| ACC-04 Settings | P1 | Language and theme exist as a sheet; missing biometric login, hide balance by default, notification toggles, change phone. Partly. |
| ACC-05 Language switch confirmation | P2 | The RTL → LTR confirmation dialog. |
| ACC-06 About / legal | P2 | Version, licences, rate the app, legal links. |
| ACC-07 Branch management & hierarchy | — | Whole screen (no tracker row). |

### Notifications (4)
| Frame | Priority | What is missing |
|---|---|---|
| NOTIF-01 Empty | P1 | "Unread" filter and its empty state; the screen has a plain empty state. Partly. |
| NOTIF-02 Event types | P1 | The 8 event kinds with their icon tones and deep links. Partly (feed exists). |
| NOTIF-03 Push permission prompt | P1 | Pre-permission screen and the denied state. |
| NOTIF-04 Preferences | P2 | Per-event toggles, quiet hours. |

### System (7)
| Frame | Priority | What is missing |
|---|---|---|
| SYS-03 Forbidden (403) | P1 | **Done** for the wallet (the screen, request access, the rule note). Other sections follow with ROLE-01. See gaps section 32. |
| SYS-04 Maintenance mode | P1 | **Done.** Full screen with ETA and retry, driven by `appStatus` (section 32). |
| SYS-05 Force / optional update | P1 | **Done.** Blocking screen and optional card, store link (section 32). |
| SYS-06 Loading skeletons | P1 | Shared pulse, respecting reduced motion (some screens have their own skeletons). Partly. |
| SYS-07 Camera / photos permission | P1 | Pre-permission and permanently-denied screens. |
| SYS-08 Missing components | P1 | Sheet, dialog, toast, banner, list row, checkbox, switch, avatar, badge, progress in all states (many exist ad hoc). Partly. |
| SYS-09 Passport expiry rule (blocking) | — | The blocking state on the passport step (no tracker row; the validator exists). Partly. |

### Roles (1)
ROLE-01 Role-based views (staff, branch manager): hidden tabs, disabled actions, per-role home. Whole. It
depends on the session carrying a role the app can use (today it has `positionRaw`).

## Tracker
`docs/DESIGN_DELIVERABLES_TRACKER.csv` said "Pending Design" for 32 of these; they are designed, just not
built, so they now read "Designed - Not implemented". The 7 frames that had no row (REQ-14, 14b, 15, 15b,
SYS-09, ACC-07, BOOK-10) were added. ROLE-02 (English / LTR versions) and ROLE-03 (dark theme) are still
"Pending Design": the page has no frames for them.

## Suggested order
1. P1 that blocks real use: AUTH-11, AUTH-08, BOOK-02 … 08, SYS-03, SYS-05, SYS-04.
2. P1 account and notifications: ACC-01 … 04, ROLE-01, NOTIF-01 … 03, AUTH-09 / 10 / 14, SYS-06 … 08.
3. The new flows needing backend contracts: REQ-14 / 15, BOOK-10, ACC-07.
4. P2: AUTH-15 / 16, BOOK-09, ACC-05 / 06, NOTIF-04.
