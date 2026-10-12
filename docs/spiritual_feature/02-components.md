# 02 · Shared Components (`lib/core/widgets/`)

Build and golden-test these before any screen. Each takes tokens from the theme extension.

| Widget | Spec |
|---|---|
| `SeenScaffold` | `bg` background, SafeArea, 16 gutter, optional `SeenTopBar` and `SeenBottomNav`. |
| `SeenTopBar` | Row: leading `SeenIconButton` (back, routes pop), centered title (`title` style) with optional subtitle (`caption`, `inkMuted`), trailing slot (icon button or outlined text button). Height 64. |
| `SeenIconButton` | 48×48 circle, `surface`, 1 px `borderControl`, 22 icon. Requires `semanticLabel`. Press: scale 0.94, 100 ms. |
| `SeenCard` | Card recipe from tokens; padding 20 (16 for compact); radius 22. |
| `SeenPrimaryButton` | Filled `accent`, white `label`/19 sp text, height 58 (or `large`: 96 with subtitle line), radius 16/26, optional trailing icon. Press scale 0.97 + haptic (see motion). |
| `SeenOutlinedButton` | Height 48, 1 px `borderStrong`, `inkBody` 15/700. For destructive/rare actions. |
| `SeenSegmented<T>` | Track `segmentTrack`, 4 padding, radius 16; options 48 tall, radius 12; active = white pill with shadow sliding under the labels (animated, see motion). Semantics: tabs/radio. |
| `SeenChip` | Height 48, radius 24, selected = `accent` fill + white text, else white + `borderControl`. Horizontal scroll row with 16 edge padding. |
| `SeenPill` | Non-interactive status pill (36–40 tall). Variants: neutral, accent (tint bg + accent text), success (sageTint + sageInk), solid. Optional leading dot/check. |
| `SeenProgressBar` | 8 px (6 in audio), radius 4, track/fill colors configurable, animated value. |
| `SegmentedRing` | CustomPainter: N arc segments (Tawaf = 7) around a circle, gap 10 px, stroke 16, butt caps, starts at 12 o'clock and fills **counter-clockwise**. Per-segment colors: done = accent, current = accentMid, future = track. Animates segment color changes. |
| `ProgressRing` | Single continuous arc (tasbeeh), stroke 14, round cap, counter-clockwise, animated sweep. |
| `OctagonBadge` | 44×44: two 31×31 squares, radius 7, 1.5 stroke, one rotated 45°, number centered (15/800). Stroke `#C9C7C0`, or `accent` when highlighted. |
| `ServiceTile` | Min height 132, card recipe radius 20, 52 icon circle (`accentTint`) + label 16/700 centered, max 2 lines. Whole tile is the tap target. |
| `SeenBottomNav` | 4 items (الرئيسية، المناسك، المصحف، حسابي), 56 min height each, icon 24 + label 13; active = accent + 700. White, top border `borderControl`, bottom padding for home indicator. |
| `SeenBottomSheet` | Radius 28 top, grab handle 40×5, title row with 48 close button, scrim 36 %. Use `showModalBottomSheet` with custom transition per motion spec. |
| `ArabicNumber` | Text widget that converts digits via `toArabicDigits`. |
| `KaabaGlyph` | 26×26 ink `#1A1C1E` square radius 4 with 3 px `kaabaBand` stripe 6 px from top. |

All interactive components: `Semantics(button: true, label: …)`, visible focus ring for keyboard/switch access, `MaterialTapTargetSize.padded`.
