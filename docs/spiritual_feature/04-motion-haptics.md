# 04 · Motion & Haptics

Motion is calm and functional — it confirms an action or shows a change of state. No bouncy decoration, no parallax, no looping motion except the Qibla lock pulse.

## Tokens (`SeenMotion`)

| Token | Value |
|---|---|
| `press` | 100–140 ms, `Curves.easeOut` |
| `fast` | 150 ms |
| `base` | 220 ms, `Curves.easeOutCubic` |
| `slow` | 320 ms, `Curves.easeOutCubic` |
| `emphasis` | 360 ms, `Curves.easeOutBack` (only for completion check icons) |
| `sheet` | 280 ms in / 220 ms out |

**Reduce motion**: if `MediaQuery.of(context).disableAnimations` → all durations 0 except opacity cross-fades (100 ms); no pulse loop (show a static sage halo at 35 % instead); compass rotation still follows the sensor but without extra easing.

## Global

- Buttons/tiles: scale to 0.97 (icon buttons 0.94, tasbeeh surface 0.985) on pointer down, back on up, `press` duration.
- Segmented controls: the white active pill slides between options (`AnimatedAlign`/`AnimatedPositioned`, `base`); label colors cross-fade.
- Page transitions: platform default (Cupertino slide on iOS, fade-through on Android); RTL-aware.
- Bottom sheets: slide up `sheet`, scrim fades to 36 %.
- Dashboard first load: cards fade in + 8 px rise, staggered 40 ms, `slow`. Only on cold start.
- Countdown text changes: `AnimatedSwitcher` fade, `fast`.

## Screen-specific

| Screen | Interaction | Motion | Haptic |
|---|---|---|---|
| Tawaf | Record lap | Button press scale; ring segment color tween `slow`; lap number `AnimatedSwitcher` (new number slides up 12 px + fade, `base`); status pill flashes accent tint then returns to neutral after 1.2 s (`base`) | `HapticFeedback.mediumImpact` |
| Tawaf | Lap 7 recorded → completed | Number cross-fades to check circle scaling 0.6→1 (`emphasis`); all segments tween to accent | `vibration` pattern [0, 40, 60, 40] |
| Tawaf | Undo | Segment tweens back; number slides down | `lightImpact` |
| Tawaf | Audio on/off | Pill fill tween `base` | `selectionClick` |
| Tawaf | Mode switch | Segmented slide; ring resets with `slow` tween | `selectionClick` |
| Quran reader | A− / A+ | `AnimatedDefaultTextStyle` font-size `fast`; keep the top visible ayah anchored | `selectionClick` |
| Quran reader | Translation toggle | `AnimatedSize` + fade per ayah, `base` | — |
| Quran reader | Open tafsir | Sheet `sheet`; ayah emblem stroke → accent `fast` | — |
| Quran index | Type in search | List items filter with `AnimatedSwitcher` fade `fast` (no layout jump); clear button scales in | — |
| Quran index | Tab change | Segmented slide; list cross-fade `base` | `selectionClick` |
| Prayer | Tap horizon marker | Dot size 12→16 + color `fast`; caption `AnimatedSwitcher` | `selectionClick` |
| Prayer | Cycle alert mode | Icon `AnimatedSwitcher` (scale 0.8→1 + fade, `fast`); sub-line text cross-fade | vibrate mode → `vibration` 40 ms; others `selectionClick` |
| Prayer | Day ↔ Month | Content cross-fade + 8 px slide `base` | — |
| Prayer | Live sun marker | Moves once a minute with `slow` tween | — |
| Qibla | Heading changes | Low-pass filter heading (α = 0.15), interpolate along the shortest angle; repaint every frame via `Ticker`; no extra animation curve | — |
| Qibla | Lock achieved | Ring + pointer + pill colors tween to sage `base`; pulse ring: scale 1→1.16, opacity 0.6→0, 1600 ms, repeat while locked | `vibration` [0, 30, 50, 30] once per lock |
| Qibla | Calibrate | Sheet with looping figure-8 path animation (2 s) | — |
| Duas | Expand/collapse | `AnimatedSize` `base`; chevron rotates 180° `base`; border color tween | `selectionClick` |
| Duas | Play | Icon morph play↔pause (`AnimatedIcon` or cross-fade); progress bar linear with playback | `lightImpact` |
| Duas | Copy | Label swaps to "تم النسخ" for 1.6 s | `lightImpact` |
| Duas | Favourite | Bookmark fill + scale 1→1.15→1 (`emphasis`) | `lightImpact` |
| Tasbeeh | Tap | Surface scale 0.985 (100 ms); ring sweep tween 160 ms; count changes instantly (no switcher — must keep up with fast tapping) with a 1.0→1.04→1.0 scale pulse | `selectionClick` every tap |
| Tasbeeh | Target reached | Ring, surface bg/border, hint pill tween to sage `base` | `vibration` [0, 60, 80, 60] |
| Tasbeeh | Reset | Ring sweeps back to 0 `slow` | `mediumImpact` |

Put all haptics behind `core/utils/haptics.dart` (`SeenHaptics.lap()`, `.complete()`, `.select()` …) with a global on/off setting.
