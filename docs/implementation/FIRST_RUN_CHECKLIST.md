# First run against the real server: checklist

Host the app talks to: `https://b2b.seenbooking.com/graphql/` (backend answer 2026-10-21: **production with a periodic reset**). Test only with test accounts the owner creates: no real money, no real WhatsApp, no real traveler data, no real agency account.

## Already observed from outside the app (2026-10-21, unauthenticated, read-only)
- TLS is valid; `POST /graphql/` answers `200` (`{ __typename }` -> `Query`).
- `POST /graphql` (no trailing slash) answers `405`: the app's endpoint keeps the slash.
- A GET carrying a query is refused (`400`), as the contract says.
- `health` answers `"ok"`; `legalPage(kind: "terms")` answers with the fields the app asks for (`titleAr`, `titleEn`, `bodyEn`, `version`).
- The host sits behind Cloudflare; no challenge was seen for a plain POST.
- Not observed yet: everything behind sign-in.

## Run order (stop at the first failure and send me the screen + the step number)
1. **Cold start.** Open the app: it should reach Welcome / Login, not an error.
2. **Legal texts.** Registration > terms: the text loads (Arabic and English).
3. **Sign in** with a test account (e-mail + password). Expected outcomes by account type: signed in; code screen (2FA); "finish setup with the e-mailed link" (enrollment required); pending / suspended messages.
4. **Home.** Balance, "needs attention" count, recent requests, service tiles (from the server), banner only if an ad exists.
5. **Stay in the app 15+ minutes**, moving between screens: no sign-in screen should appear (this is the token refresh via the `sb_refresh` cookie).
6. **Close and reopen the app**: the session should be restored without typing the password.
7. **Requests.** List, search, open one, (cancel a *draft* only).
8. **Booking** (use a test service; stop before the final submit unless the account is a test account): catalog, traveler form (conditional fields), uploads, review/quote.
9. **Wallet.** Balance, statement, top-up *form* (do not submit on production).
10. **Support.** Open a ticket with a file, reply to it.
11. **Account.** Agency name on the card, team list (owner), branches, margins (Main Agent: pick a sub-agency).
12. **Agents** (Main Agent): list, profile, approvals. Funding / reclaiming / approving a top-up only on staging.
13. **Sign out**, then sign in as another account: nothing of the first (branch, searches) is shown.

## New features to try once there is a test account (design/gaps, 2026-10-22)
14. **Settings > two-step verification:** turn it on (QR or the typed key), type the first code, save the recovery codes, finish. Then "Generate new codes" with a fresh code. Report if the card still says "off" afterwards (backend `otp_enabled`, Q37).
15. **Settings > change e-mail** (use a throwaway address): wrong password, then the right one; the screen says "check your e-mail". The link opens a web page.
16. **Request detail > a traveler's passport number:** hidden; tap the eye; the first time a notice shows; the value hides after 30 s, when you leave, and when the app goes to the background. A screenshot must be blocked while it shows (Android). Report if no sensitive value shows at all (Q36).
17. **Account > profile photo:** take or choose a photo, crop, upload; it shows on Account and Home; remove it.
18. **Support:** new ticket with a category; a closed ticket shows the rating card (rate once); Home's support button shows the unread count; an unread thread shows "new messages".
19. **Traveler form > scan the passport:** camera and gallery; review the suggestions; apply; nothing is saved until you press Next. The photo must not stay on the device.
20. **Reports:** not reachable yet (the builder waits for Q34).

## What to send back
- The step number, the screen, and the text of the error. If there is an "error reference" line, include it.
- For step 3: which kind of account it was.
- For steps 5-6: how many minutes passed before the sign-in screen appeared.
