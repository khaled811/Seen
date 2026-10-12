# 06 · Build Plan & Acceptance Criteria

Work milestone by milestone. At the end of each: `flutter analyze` clean, `flutter test` green, short summary of what was built and any spec conflicts.

## M0 — Scaffold
- `flutter create seen_manasik --org net.jubari --platforms ios,android`.
- Add packages from CLAUDE.md, bundle fonts, set `locale: Locale('ar')`, `supportedLocales`, localization delegates, RTL verified.
- `go_router` with a shell route (bottom nav) for `/`, `/tawaf`, `/quran`, `/account`; full-screen routes `/quran/:surah`, `/prayer`, `/qibla`, `/duas`, `/tasbeeh`.
- **Done when** the app launches RTL with placeholder screens and working navigation.

## M1 — Design system
- Tokens (`docs/01`), theme extension, all components (`docs/02`), `SeenHaptics`, `toArabicDigits`.
- A hidden `/_gallery` route showing every component in every state.
- Golden tests for each component (normal + text scale 2.0).

## M2 — Dashboard (Screen 1) with mocked providers
- Pixel-match `Main.dc.html` at 390 px width. Golden test.

## M3 — Tawaf & Sa'i (Screen 2)
- Full state machine + persistence + debounce + wakelock + audio + all motion/haptics.
- Unit tests: record, undo, complete, mode switch, restore after restart, debounce.

## M4 — Quran data, Index (4) and Reader (3)
- Import dataset, repository, search normalization (unit-tested with tashkeel/hamza variants), last read, bookmarks, font size, translation, tafsir sheet.

## M5 — Prayer times (5)
- `adhan` + location + Hijri; day horizon painter; list with alert modes; month table; notification scheduling. Unit-test the horizon positioning and midnight/last-third math.

## M6 — Qibla (6)
- Compass service with low-pass filter, shortest-angle interpolation, lock hysteresis, pulse, haptic-once, accuracy, calibration sheet, no-sensor & permission states. Unit-test angle math (wrap-around at 0/360).

## M7 — Duas (7) & Tasbeeh (8)
- duas.json loader (+ `reviewed` gate), chips, expandable cards, single-audio service, share/copy/favourite. Tasbeeh state, targets, rounds, daily totals, picker sheet.

## M8 — Polish & QA
- Reduce-motion pass, TalkBack/VoiceOver pass (every control labelled, lap/count announcements), text scale 2.0 pass, contrast check, dark-sunlight check (max brightness), performance (60 fps on compass and tasbeeh rapid taps), app-kill restore for Tawaf/Tasbeeh.

## Definition of done (whole hub)
- All 8 screens match the reference artboards in layout, color, type and copy.
- Every interaction in `docs/03` works; every row in `docs/04` is implemented.
- No hard-coded colors/sizes/durations in feature code.
- All tap targets ≥ 48 dp; all text ≥ 4.5:1.
- No Quran text in source code; duas gated by `reviewed`.
