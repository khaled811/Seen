# Seen loading system: loaders, loading states & refresher

This spec adds **behaviour only**: what the app shows while it waits. It must not change the design of any screen.

Every loader and the pull-to-refresh are drawn from the Seen logo. The logo has two parts:

- the **airplane window**, which is the frame;
- the letter **«س»** inside it, made of a **tooth** and a **smile**.

The app must not use any generic spinner.

Files in this folder:

| Path | What it is |
|---|---|
| `reference/seen_loader.dart` | Working reference code for every component below. Copy or adapt it into the app. Don't add it as a package. |
| `preview/seen-loading-preview.html` | Open it in a browser to see the real motion and timing. Fonts load from Google. |
| `screenshots/*.png` | Each state at 2×, divided by 2 = dp. **They are drawn on reference mock-ups, not on our current screens.** Use them for the loader, indicator and banner only. Never use them for layout. |
| `assets/*.svg` | The mark traced from the logo: full mark plus each stroke. Box 120 × 140. |

---

## 0. Ground rules

1. **No UI redesign.** Do not change any existing layout, spacing, colour, typography, icon, copy, navigation or widget. A screen's loaded state must render pixel-identical before and after this work. Prove it with a golden of the loaded state, captured before you edit and checked after.
2. **Allowed visual changes:**
   - skeletons while data loads;
   - a loader inside the control that is busy;
   - progress for uploads;
   - the refresher;
   - the slow-network and timeout states;
   - replacing existing spinners with the Seen components. That covers `CircularProgressIndicator`, `LinearProgressIndicator` (indeterminate), `RefreshIndicator`, shimmer packages, Lottie/GIF loaders, `CupertinoActivityIndicator` and text such as "Loading…".
3. **Skeletons mirror the screen as it is in our code today.** Build each skeleton from that screen's real widget tree, not from the screenshots.
4. **Colours come from the app's existing theme.** Map §2 to existing tokens. Add only the missing colours, as named constants in the existing theme (a `ThemeExtension` or colours file).
5. **Reuse the app's state management and loading flags** (`isLoading`, `AsyncValue`, `ConnectionState`, Bloc states…). If a screen has no loading or error state today, add the minimum to its existing state. Don't restructure data flow.

---

## 1. The mark

Box 120 × 140. Butt caps, miter joins. The paths are traced from the logo and verified by overlay.

| Stroke | Geometry | Stroke width |
|---|---|---|
| window | `RRect(11, 7, 99, 127, radius 31)` | 10 |
| tooth | `M36.6 67 L45.8 53.5 Q60.3 63.9 80.5 52` | 9.5 |
| smile | `M24.2 76.6 Q59 102.4 94.7 76.1` | 10 |

Rules that apply to every size:

- Strokes are never thinner than **2 physical px** at small sizes; scale stroke units up.
- The «س» glyph is drawn only when the mark is **36 px or taller**. Below that the window alone reads better.
- Width = height × 120/140.

All motion is built on `PathMetric.extractPath`.

---

## 2. Colours

| Role | Brand value | Map to the app's existing token |
|---|---|---|
| ink (loader colour) | `#7B52F6` | accent / primary purple |
| track | `#E6DEFD` | accent tint |
| window fill (sky background) | `#F5F2FE` | surface tint |
| sky gradient | `#A68BFF` → `#5A36D2` | add as constants |
| skeleton base | `#ECE7FA` | add if missing |
| skeleton highlight | white 75% | |
| on-dark ink / track | `#FFFFFF` / white 22% | for gradient, dark buttons and toasts |
| on-dark skeleton | white 16% base, white 28% highlight | on the gradient balance card |
| slow banner | bg `#FDEEDF`, fg `#9A4A0C` | warning pair |
| timeout / error | bg `#FBE7E9`, fg `#A3263A` | danger pair |
| done ✓ | `#2E9E6B` | success |
| scrim (blocking) | `#1B1530` @ 60% | ink |

---

## 3. Components

The reference names in this section match `reference/seen_loader.dart`.

### 3.1 `SeenLoader`: SeenMark.trace, the default spinner

- A light runs round the window, over a track.
- Tail = 34% of the perimeter at 38% opacity. Head = the front 14% at full ink.
- 1100 ms linear, infinite. With reduce-motion: 2600 ms. It is the only feedback, so it stays.

| Height | Use |
|---|---|
| 16–18 | Inside buttons, chips, the small refresh icon button |
| 20–24 | Fields (trailing slot), toasts, list rows |
| 40 | Cards |
| 64–96 | Full-screen or centred waits. The glyph shows. |

- **On dark** (`SeenLoader.onDark`): white ink, 22% white track.
- It replaces every `CircularProgressIndicator`.

### 3.2 `SeenMarkDraw`: SeenMark.draw, the mark writes itself

- 2800 ms loop with curve `Cubic(.65, 0, .35, 1)`.
- Each stroke draws, holds, then erases *forward*:

  | Stroke | Draws | Erases |
  |---|---|---|
  | window | 0–32% | 72–94% |
  | tooth | 22–42% | 76–95% |
  | smile | 36–58% | 80–97% |

- With reduce-motion: the complete mark, static.
- Use it for **boot** (96–124 px, on dark) and **indeterminate blocking waits** (72–96 px).

### 3.3 `SeenSkyProgress`: SeenMark.sky, determinate

- The window fills with sky from the bottom: the top edge of the sky is at `y = 129 − value × 117`.
- Two clouds drift right → left, with periods of 7 s and 10 s.
- The «س» is ink above the sky and **white** below it.
- Always show the % next to it, with Arabic-Indic digits, e.g. «٥٨٪».
- Animate value changes over 250 ms ease-out.
- Use it for uploads (passport, photos, receipt), submitting a request with attachments, and PDF export.
- For a single file row inside a list, keep a thin 4 px `LinearProgressIndicator`-style bar (ink on track). Use the sky for the main progress only.

### 3.4 `SeenWindows`: inline loader

- Three cabin windows, ratio 0.82 : 1, radius 36%. Border = max(1.2, size × 0.2).
- Each window lights up in turn (fills with ink, opacity .3 → 1 → .3). Order is start → end, so right → left in RTL.
- Stagger 180 ms, cycle 1200 ms.
- Sizes 6–10 inline, up to 18.
- Use it for:
  - the «جاري تحميل المزيد» row at the end of paginated lists;
  - «يكتب» in the support chat;
  - «جاري الحفظ» chips;
  - small inline status.

### 3.5 `SeenShimmer` + `SkeletonBox`: skeletons

- One shared sweep per screen region: a 50%-wide highlight band, 1400 ms linear, moving **right → left** (start → end in RTL).
- On the gradient balance card, use the on-dark colours.
- With reduce-motion: no sweep, static base colour.

### 3.6 `SeenRefreshBubble` + `SeenRefresh`: the refresher

As the user pulls, the logo draws itself.

| Stage | Bubble | Label under it |
|---|---|---|
| pull 0 → 55% | window frame draws round | «اسحب للتحديث» |
| pull 55 → 80% | tooth of «س» draws | «اسحب للتحديث» |
| pull 80 → 100% | smile draws; the mark is complete | «اسحب للتحديث» |
| armed (≥ 72 px) | bubble fills with ink, mark turns white, scale 1.08, `HapticFeedback.lightImpact()` once | «أفلت للتحديث» (w600, `#2C186A`) |
| loading | white bubble, SeenMark.trace; settles at 56 px; old data stays and the list still scrolls | «جاري التحديث…» |
| done | smile bounces (500 ms) + green ✓ badge at the top-end of the bubble; holds 900 ms, collapses in 250 ms | «تم التحديث» (`#17694A`) |

Bubble specs:

- 52 dp, white, shadow `0 12 32 -4 rgba(44,24,106,.16)`, mark 30 dp tall.
- Drag maps to indicator travel at 0.5×.

Implementation:

- The reference uses `custom_refresh_indicator`. If the app already uses another refresh package, adapt `SeenRefresh` to it and keep `SeenRefreshBubble` unchanged.
- After a successful refresh:
  - update the screen's existing «آخر تحديث» text if it has one;
  - if new items arrived while the user is scrolled down, show a small ink pill «٣ طلبات جديدة ↑» only if the screen already has a pattern for it. Don't invent new UI.
- If the refresh fails, keep the old data. Show the app's existing error snackbar or toast with «تعذّر التحديث — نعرض آخر بيانات محفوظة» and «إعادة».

---

## 4. Which loader where

| Situation | Show | Never |
|---|---|---|
| First load of a content screen | Skeleton of that screen (§6) | Full-screen spinner |
| Pull-to-refresh, or refresh after an action | Refresher; keep the data visible | Swap back to the skeleton |
| Silent or background refresh | Nothing (optionally the new-items pill) | The refresher |
| Button action (login, OTP, save, approve, send, reject) | Trace in the button (§7) | Blocking overlay |
| Field validation (e.g. passport number check) | `SeenLoader(20)` in the field's trailing slot + helper «جاري التحقق…» | |
| Upload with known size | `SeenSkyProgress` (main) / thin bar (per file) | Indeterminate trace |
| Money or irreversible action (submit request, top-up, approve top-up for a sub-agent, create sub-agent) | Blocking overlay (§8) | Leaving the UI interactive |
| Pagination | `SeenWindows` row at list end + 1 skeleton row | Centred spinner |
| App start / session restore | `SeenMarkDraw.onDark` on the existing splash (§10) | |
| Wait > 10 s | Slow banner (§9) | |
| Wait > 30 s | Timeout state (§9) | Infinite spinner |

---

## 5. Inventory: fill this table for OUR app before editing

List every screen and action that waits on the network. Use the app's actual screen names. These defaults show the expected answer:

| Screen / action | First load | Refresher | Actions → button trace | Uploads → sky | Blocking | Slow / timeout |
|---|---|---|---|---|---|---|
| Splash / session restore | SeenMarkDraw | — | — | — | — | ✓ |
| Login, OTP, sign-up, forgot / reset | — | — | submit buttons | sign-up docs | — | ✓ |
| Home | skeleton (balance card on-dark, tiles, recent list) | ✓ | — | — | — | ✓ |
| Requests list | skeleton (≤ 6 cards) | ✓ | — | — | — | ✓ |
| Request detail / tracking | skeleton | ✓ | upload missing docs, contact | ✓ | — | ✓ |
| New request → submit | — | — | step buttons | ✓ | ✓ submit | ✓ |
| Wallet / statement | skeleton | ✓ | export PDF | export | — | ✓ |
| Top-up | — | — | choose method | receipt | ✓ processing (§8) | ✓ |
| Network hub / sub-agents / agent detail | skeleton | ✓ | approve/reject top-up, toggle active | — | ✓ approve funds, create sub-agent | ✓ |
| Staff / add staff / create branch | skeleton | ✓ | save in sheet | — | — | ✓ |
| Notifications | skeleton | ✓ | mark read | — | — | ✓ |
| Support tickets / thread | skeleton | ✓ | send (button) + SeenWindows «يكتب» | attachments | — | ✓ |
| Document preview | trace 40 centred in the preview area | — | download / share | — | — | ✓ |

---

## 6. Building a skeleton from the real screen

1. Start from the screen's loaded widget tree in our code. Keep **static chrome** exactly as it is:
   - app bar, title, search, filters/tabs, section headers, bottom navigation;
   - any button that doesn't depend on data.
2. Replace data with shapes of the **same size, position and radius**:
   - text → a `SkeletonBox` line, height ≈ 0.7 × font size (8–14 dp), radius 6, widths varied 38–72%;
   - avatars, icons, images → boxes or circles of the same size;
   - chips / badges → boxes with radius 999;
   - numbers on the balance card → on-dark boxes.
3. Lists show at most 6 skeleton items.
4. Wrap each region in **one** `SeenShimmer` so the sweep is continuous. Never use a shimmer per item.
5. The skeleton must not shift layout when data arrives (same heights).
6. Accessibility: wrap the region in `Semantics(label: 'جاري التحميل', liveRegion: true)` once; skeleton shapes are excluded.

---

## 7. Buttons and controls

- **Keep the button's size and style.**
- While busy:
  - disable it;
  - replace the label with `[SeenLoader 18] + «جاري …»`, using the existing verb. For example «تسجيل الدخول» → «جاري الدخول», «إرسال» → «جاري الإرسال…»;
  - use `SeenLoader.onDark` on filled or dark buttons and ink on outline buttons.
- On success, follow the app's existing pattern. If there is none, show the label «تم ✓» for 1.2 s on success green, then continue.
- Icon buttons swap the icon for `SeenLoader(18–20)`.

---

## 8. Blocking overlay (money / irreversible only)

See `screenshots/41a-submit-sky-progress.png`, `41b-submit-done.png` and `42-topup-processing.png`.

- Blocking:
  - scrim `#1B1530` @ 60% over the current screen;
  - back is disabled (`PopScope(canPop: false)`) until it finishes or the user cancels.
- Centred card:
  - white, radius 28, inset 20, padding 26/22/20;
  - shadow `0 24 48 -12 rgba(27,21,48,.45)`.
- Card content:
  - a hero:
    - `SeenSkyProgress(92)` when progress is known, with % in the title;
    - otherwise `SeenMarkDraw(96)`;
    - for long server-side processing (top-up verification), `SeenLoader(96)` on a 132 dp tinted tile.
  - title «جاري …» 19/28 w700 and the context line (service · passengers);
  - an optional step list: done = green ✓, current = `SeenLoader(16)` + 4 dp bar, pending = dot;
  - the warning «لا تغلق التطبيق حتى يكتمل الإرسال» (`#9A4A0C`);
  - the text button «إلغاء الإرسال» (danger) when cancel is possible.
- Success replaces the card: 72 dp success circle, «تم إرسال الطلب», request ref (LTR), primary CTA + text link.
- Top-up verification can take long, so it is **not** blocking after the receipt upload. It shows a status screen with steps and «متابعة في الخلفية».

---

## 9. Timing policy (`SeenLoadingGate` and timers)

| Time since the wait started | Behaviour |
|---|---|
| 0–300 ms | Show nothing new; keep the previous content. This avoids flashes on fast responses. |
| ≥ 300 ms | Show the skeleton or loader. |
| Once shown | Keep it at least 500 ms (no flicker). |
| 10 s | Add the **slow banner** at the top of the content: bg `#FDEEDF`, fg `#9A4A0C`, radius 18, `SeenLoader(20)` in amber, text «**الاتصال بطيء** — ما زلنا نحاول (١٢ ث)» and an «إلغاء» text button. The skeleton keeps running underneath. |
| 30 s, or the user cancels | **Timeout state** (see below). |

The timeout state replaces the skeleton with a card:

- 84 dp danger tile with a clock icon;
- «تعذّر تحميل …», and the reason: «انتهت مهلة الاتصال بعد ٣٠ ثانية. بياناتك محفوظة…»;
- a gradient «إعادة المحاولة» button;
- the link «التحقق من حالة الاتصال», which goes to the existing offline screen if there is one;
- a small LTR error code.

Never lose form input on timeout.

Network timeouts in the HTTP client should match: connect 10 s, receive 30 s. Report the client's current values if they differ; don't change them silently.

---

## 10. Boot

Change only the splash's loading element. Keep its background, logo placement and copy.

- If the splash shows the logo + a spinner, replace the logo mark with `SeenMarkDraw.onDark(124)`. Keep the wordmark below it.
- Remove the spinner.
- Optional: a status line rotating every 1.4 s: «جاري التحقق من الجلسة…» → «مزامنة رصيد المحفظة…» → «تحميل الخدمات المتاحة…» → «لحظات ونكون جاهزين…»
- Optional: a 4 dp white bar at 16% white track.

If the splash is native-only (`flutter_native_splash`), apply this to the first Flutter route that waits for session restore.

---

## 11. Accessibility and reduce-motion

- Loaders are decorative (`ExcludeSemantics`). The waiting container announces «جاري التحميل» once (live region) and sets busy semantics on buttons.
- `MediaQuery.disableAnimationsOf(context)`:
  - draw → static complete mark;
  - trace → 2600 ms;
  - shimmer → static;
  - windows → hold (first lit);
  - clouds stop.
- Text stays Arabic RTL. Numbers follow the app's existing digit rules.

---

## 12. Acceptance checklist and tests

- [ ] No `CircularProgressIndicator`, `CupertinoActivityIndicator`, indeterminate `LinearProgressIndicator`, shimmer package or Lottie loader remains, except the 4 dp per-file upload bar.
- [ ] Every row of the §5 table is implemented, or listed with a reason it isn't.
- [ ] For every touched screen, the **loaded-state golden is identical** before and after.
- [ ] Goldens:
  - [ ] `SeenRefreshBubble`: pull 30%, 70%, 92%, armed, loading, done.
  - [ ] `SeenLoader`: 18, 24, 40, 96, plus on-dark 18.
  - [ ] `SeenSkyProgress`: 0, 0.58, 1.
  - [ ] `SeenWindows`: 8.
  - [ ] Skeleton of Home and Requests at 390 × 844.
- [ ] Widget tests with `fakeAsync`:
  - [ ] the gate shows nothing before 300 ms and keeps the loader ≥ 500 ms;
  - [ ] the slow banner at 10 s and the timeout at 30 s;
  - [ ] refresh keeps the old list visible while loading;
  - [ ] the blocking overlay disables back.
- [ ] Reduce-motion test: no ticking animations except the slowed trace.
- [ ] `flutter analyze` is clean.
