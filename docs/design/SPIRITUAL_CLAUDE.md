# Seen — Spiritual & Manasik Hub (Flutter)

You are implementing the **Spiritual & Manasik Hub** of the *Seen* travel-companion app, in Flutter, pixel-faithful to the approved design, including every interaction, animation and haptic described in `docs/`.

Read these before writing code, in order:

1. `docs/01-design-tokens.md` — colors, type, spacing, radii, shadows (single source of truth)
2. `docs/02-components.md` — shared widgets to build first
3. `docs/03-screens.md` — the 8 screens, their layout, states and behaviour
4. `docs/04-motion-haptics.md` — every animation (duration, curve) and haptic
5. `docs/05-content.md` — Arabic copy, Quran/dua text sources and review rules
6. `design/reference/*.dc.html` — the approved mockups as HTML. They are the **visual reference** (exact paddings, sizes, colors, copy). They are not runnable code; read them, don't port their JS literally.

## Product principles (non-negotiable)

- **Minimal, reverent, breathable.** No ornate gold textures, arches, 3D, gradient washes, emoji or decorative clutter. White space is a feature.
- **Built for elderly pilgrims in sunlight and crowds.** Every tappable target ≥ 48×48 dp. Body text ≥ 15 sp, primary content ≥ 17 sp. No text below 4.5:1 contrast (use the ink tokens only).
- **Native RTL.** The app locale is `ar`. Use `Directionality`/`EdgeInsetsDirectional`/`AlignmentDirectional` everywhere — never hard-code left/right except where the spec says the element is direction-independent (media play icon, LTR English translation, compass math).
- **Arabic-Indic digits** (٠١٢٣٤٥٦٧٨٩) for all numbers shown to the user. Use one helper `toArabicDigits()` in `core/utils`.
- **Must scale.** Layouts must survive system text scale up to 2.0 without clipping (use `Flexible`, wrap, scroll). Respect `MediaQuery.disableAnimations` (reduce motion).

## Stack

| Concern | Package |
|---|---|
| State | `flutter_riverpod` (+ `riverpod_annotation` optional) |
| Routing | `go_router` (shell route for bottom nav) |
| Fonts | Bundle **Tajawal** (400/500/700/800) and **KFGQPC Uthmanic Script HAFS** as assets (fallback: `Amiri Quran`, `Amiri`). Do not fetch fonts at runtime. |
| Localization / RTL | `flutter_localizations`, `intl` |
| Prayer times | `adhan` (method: `CalculationMethod.umm_al_qura`) |
| Hijri date | `hijri` |
| Location | `geolocator`, `geocoding` |
| Compass | `flutter_compass` (heading) + Qibla bearing from `adhan`'s `Qibla` |
| Audio | `just_audio` |
| Haptics | `HapticFeedback` (built-in) + `vibration` for patterns |
| Persistence | `hive_ce` / `hive_flutter` (sessions, counters, bookmarks, settings) |
| Notifications | `flutter_local_notifications` + `timezone` (adhan alerts) |
| Keep screen on | `wakelock_plus` (Tawaf & Tasbeeh screens only) |
| Share / clipboard | `share_plus`, `Clipboard` |
| Tests | `flutter_test`, golden tests (`alchemist` or `golden_toolkit`) |

## Project structure

```
lib/
  main.dart
  app/                 router.dart, app.dart (MaterialApp, theme, locale ar, RTL)
  core/
    theme/             seen_colors.dart, seen_typography.dart, seen_theme.dart, seen_spacing.dart
    widgets/           (see docs/02-components.md)
    utils/             arabic_digits.dart, haptics.dart, time_format.dart
    services/          location_service.dart, prayer_service.dart, compass_service.dart, audio_service.dart, storage.dart
  features/
    home/              (Screen 1)
    tawaf/             (Screen 2)
    quran/             reader (Screen 3) + index (Screen 4) + data/
    prayer/            (Screen 5)
    qibla/             (Screen 6)
    duas/              (Screen 7)
    tasbeeh/           (Screen 8)
assets/
  fonts/  audio/  data/quran/  data/duas.json
```

Each feature: `presentation/` (screen + local widgets), `application/` (Riverpod notifiers), `domain/` (models), `data/` (repositories).

## Working rules

- Build in the milestone order of `docs/06-build-plan.md`. After each milestone run `flutter analyze` and `flutter test`; fix everything before moving on.
- Never hard-code a color, radius, font size or duration inside a screen — use the tokens.
- All user-facing strings go in `lib/l10n/app_ar.arb` (Arabic is the only locale for now; keep keys English).
- Religious text (Quran, duas, sources) comes **only** from the data files described in `docs/05-content.md`. Never type, edit or "fix" Quranic text by hand.
- State that must survive an app kill (active Tawaf/Sa'i session, tasbeeh counts, bookmarks, last read, alert modes, font size) is persisted immediately on change.
- Keep widgets small and composable; one public widget per file.
- When the spec and the HTML reference disagree, the spec wins; mention the conflict in your summary.
