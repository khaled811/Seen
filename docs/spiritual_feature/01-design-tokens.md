# 01 · Design Tokens

Implement as `SeenColors`, `SeenType`, `SeenSpace`, `SeenRadius`, `SeenShadow`, `SeenMotion` (const classes) and wire into a `ThemeData` extension (`ThemeExtension<SeenTokens>`) so the accent can be swapped.

## Color

| Token | Hex | Use |
|---|---|---|
| `bg` | `#F8F9FA` | App background |
| `bgReader` | `#FAF9F6` | Quran reader background (warmer paper) |
| `surface` | `#FFFFFF` | Cards, tiles, sheets |
| `surfaceMuted` | `#F6F7F8` | Inner chips, caption pills, icon buttons |
| `segmentTrack` | `#ECEDEF` | Segmented control track |
| `borderCard` | `#EEEFF1` | 1 px card border |
| `borderControl` | `#E7E8EA` | 1 px border on round icon buttons, nav top border |
| `borderStrong` | `#D5D7DB` | Outlined secondary buttons ("إنهاء النسك", "إلغاء شوط", "تصفير") |
| `track` | `#E4E5E8` | Empty ring segments / progress tracks |
| `inkPrimary` | `#1A1C1E` | Headers, key numbers |
| `inkBody` | `#44474E` | Body text, inactive icons |
| `inkMuted` | `#74777F` | Subtitles/captions — **only on white or `#F8F9FA`**, min 14 sp |
| `accent` | `#7B2D3B` | Deep muted burgundy — primary brand accent |
| `accentTint` | `#F6ECEE` | Soft accent fills (badges, icon circles, active row) |
| `accentMid` | `#DDB4BC` | In-progress segment, past-prayer line, active border |
| `sage` | `#3F6654` | Quran progress, success / Qibla lock / tasbeeh complete |
| `sageTint` | `#E9F1EC` / `#E3EFE7` | Success fills |
| `sageInk` | `#2F5442` | Text on sage tint |
| `kaabaBand` | `#C9A96E` | Only the thin band on the tiny Kaaba glyph in the compass |
| `scrim` | `#1A1C1E` @ 36 % | Bottom-sheet scrim |

Alternate accent themes (exposed in settings later, keep the mapping): `#3F6654` → tint `#E9F1EC`, mid `#B4CCBD`; `#1F4E5F` → tint `#E7F0F3`, mid `#AFC8D2`.

## Typography

- UI: **Tajawal**. Quran: **KFGQPC Uthmanic Script HAFS** (fallback Amiri Quran). Hadith duas/dhikr: **Amiri**. English translation: Georgia-like serif (`NotoSerif`) LTR.
- Never use Inter/Roboto/Arial for Arabic.

| Style | Size / Weight / Line height | Use |
|---|---|---|
| `display` | 56 / 800 / 1.0 | Next-prayer time |
| `counterXL` | 112 / 800 / 1.0 | Tawaf lap number |
| `counterL` | 96 / 800 / 1.0 | Tasbeeh count |
| `compassDeg` | 46 / 800 / 1.1 | Qibla angle |
| `h1` | 30 / 800 / 1.3 | Prayer name on dashboard |
| `h2` | 24 / 800 / 1.35 | Card titles ("طواف العمرة") |
| `title` | 21 / 800 | Screen titles in top bar |
| `section` | 20 / 800 | Section headers ("الخدمات") |
| `bodyStrong` | 18 / 700 | List primary lines |
| `body` | 17 / 500 | Body |
| `label` | 16 / 700 | Buttons, chips, tile labels |
| `caption` | 15 / 500 | Secondary lines |
| `micro` | 13–14 / 500–700 | Nav labels, tags (minimum) |
| `quran` | default 30 (steps 24·27·30·34·38·42) / 400 / **2.05** | Verses |
| `dua` | 25 / 400 / 1.9–2.0 | Duas (Amiri / Uthmani if Quranic) |

## Spacing, radius, elevation

- Spacing scale: 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 24, 28, 32. Screen side gutter **16**. Gap between cards **16** (12 inside grids).
- Radius: chips/pills 999; small controls 12–14; buttons 16; cards 20–22; big tap surfaces 26–32; sheets 28 (top corners).
- Card = `surface` + 1 px `borderCard` + shadow `0 2 12 rgba(26,28,30,0.04)`.
- Primary floating button shadow: `0 6 20 rgba(26,28,30,0.12)`.
- Segmented active pill shadow: `0 1 4 rgba(26,28,30,0.08)`.

## Iconography

Line icons, 24 grid, stroke 1.7–1.9, round caps/joins, single color. Icon on a 48–52 circle/rounded square of `accentTint` for service tiles. Build them as a small `SeenIcons` set of `CustomPainter`s or SVG assets (`flutter_svg`) — the exact paths are in the reference HTML `<svg>` elements. Directional icons (back, forward chevrons, undo) are mirrored for RTL; media play is **not**.
