# Paste this into Claude Code (from the root of the Flutter project)

Put this folder at `design/gaps/` first. Start the session in Plan mode (Shift+Tab) so step 1 happens before any edits.

```
I want to build 7 missing features in the app ("Section · GAPS"):
SEC two-step verification, PRIV reveal masked values, ACC change email, REP reports,
PASS read passport from a photo, PROF profile photo, SUP support rating / categories / unread.

Everything is in design/gaps/:
- SPEC.md is the full spec. It covers the scope rules (§0), the design language (§1), the 4 new
  components (§3), every screen with its states, rules and copy (§4–§10), permissions (§11), the
  assumed backend contract (§12), accessibility (§13) and the acceptance checklist (§14).
- screenshots/frames/*.png has one image per state (97 frames, 390×844 @2×), and
  screenshots/INDEX.md maps each file to "ID · title — state". screenshots/boards/*.png shows every
  state of one screen side by side.
- preview/gaps-preview.html is the same thing as a static page you can open in a browser.
- copy/app_ar.arb and copy/app_en.arb contain every new string, with keys. The Arabic matches the
  designs exactly.
- tokens.json is the design language from the brief: colours, status pairs, gradients, sizes, type.
- reference/gaps_components.dart is reference code for the NEW components only (RatingStars,
  SuggestionRow, ReportTable, CountdownPill), plus RevealController, masking helpers and Arabic
  search normalisation. Read it, then copy or adapt it into our structure. Don't add it as a
  package, and replace its GapsTokens with our theme.
- assets/icons/*.svg are the icon shapes used in the designs. Use them ONLY where our icon set has
  no equivalent.

Hard rules:
1. The current code is the source of truth for every EXISTING screen. I have changed a lot of the
   UI recently. On existing screens, make only the exact additions in SPEC §0.2:
   - the 2FA entry and the change-email row in Settings;
   - the 2FA step in login;
   - masked values + eye on traveler details;
   - the scan button on the traveler form;
   - the camera badge on the account avatar;
   - the unread badge on Home;
   - the unread dots in the support list;
   - the category picker in new-ticket;
   - the rating card and the "new messages" divider in the chat;
   - the Reports entry.
   For every existing screen you touch, capture a golden of its loaded state BEFORE editing. After
   editing, it must be identical except for the added element.
2. The screenshots redraw some existing screens around the new element: Settings, Account, Home,
   traveler form, support list/chat. Those redraws are approximations. Take only the added
   element from them, never their layout or content.
3. For NEW screens and sheets, the screenshots + SPEC are the target. Build them with OUR existing
   widgets: button, text field, OTP input, status badge, sheet helper, list group, top bar,
   segmented chips, skeleton/loader. Only the 4 components in SPEC §3 are new.
4. Use our theme tokens. Map tokens.json to the closest existing token. Add a named constant only
   when nothing matches. Rules:
   - no dark backgrounds (the camera and crop screens are light);
   - green and red only via the status pairs;
   - small text uses the secondary colour (SPEC §0.3).
5. All strings go through our l10n. Merge the keys from copy/*.arb into our ARB files (rename the
   prefix if we use another convention) and run gen-l10n. No hard-coded Arabic.
6. Use our existing loading system for skeletons and busy buttons (design/loading if implemented).
   No raw CircularProgressIndicator.
7. Reuse our state management, routing, API client and error handling. For each backend call in
   SPEC §12, find the existing endpoint.
   - If one is missing, add a repository interface plus a fake implementation behind a
     feature flag.
   - List every fake in your report.
   - Never invent production URLs.
8. Security:
   - Revealed values live in memory only. One at a time. 30 s auto-hide. Hidden on background.
     FLAG_SECURE while visible.
   - Never log the TOTP secret, recovery codes or revealed values.
   - Delete temporary passport images after reading.

How to work:
1. Explore first and make NO edits. Then send me:
   (a) where each entry point in SPEC §0.2 lives in our code (file:line), and anything you
       couldn't find. Especially say where Reports should be linked from.
   (b) the widgets you'll reuse for each pattern in SPEC §1–§2, and which tokens.json values had
       no matching theme token;
   (c) for each SPEC §12 need: the existing endpoint or repository you'll use, or "missing — fake";
   (d) the permission source we use, and how SPEC §11 maps to it;
   (e) your file plan and the order you'll build in.
   Wait for my OK.
2. Build one feature at a time, in this order:
   - SEC, ACC, PRIV (these touch auth and settings);
   - then PROF, SUP;
   - then PASS;
   - then REP.
   After each feature:
   - run `flutter analyze` and the tests;
   - show me the screens, in every state, on a 390-wide RTL device or golden;
   - tell me which screenshot frames they match.
3. Add the tests from SPEC §14:
   - widget tests for the 4 new components, plus RevealController with fake async;
   - goldens for one frame per new screen in RTL;
   - a unit test for normalizeArabic;
   - before/after goldens for every touched existing screen.
4. Final report:
   - a feature × state table showing done or not done (use screenshots/INDEX.md);
   - every fake repository or feature flag you added;
   - anything you couldn't cover, and why;
   - confirmation that the loaded-state goldens of all touched existing screens are unchanged
     apart from the added element.
```
