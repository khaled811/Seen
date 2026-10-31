# Section · GAPS — implementation spec

Seen Business app · 7 missing features · 28 screens · 97 state frames.

| Code | Feature | Screens |
|---|---|---|
| SEC | Two-step verification (TOTP + recovery codes) | SEC-01 … SEC-05 |
| PRIV | Reveal masked values | PRIV-01 … PRIV-03 |
| ACC | Change email | ACC-08 … ACC-10 |
| REP | Reports (builder, table, export) | REP-01 … REP-06 |
| PASS | Read passport from a photo | PASS-01 … PASS-04 |
| PROF | Profile photo | PROF-01 … PROF-03 |
| SUP | Support: rating, categories, unread | SUP-06 … SUP-09 |

The package contains:

| Path | What it is |
|---|---|
| `SPEC.md` | This file. The behaviour, states, rules and copy for each screen. |
| `tokens.json` | The design language from the brief: colours, status pairs, gradients, sizes, type. |
| `copy/app_ar.arb`, `copy/app_en.arb` | Every new string, with keys. The Arabic matches the screens exactly. |
| `reference/gaps_components.dart` | Reference Flutter code for the new components and the reveal/countdown logic. |
| `screenshots/frames/*.png` | One state per image (390×844 @2×). `screenshots/INDEX.md` maps each file to its state. |
| `screenshots/boards/*.png` | One image per screen showing all its states side by side. |
| `preview/gaps-preview.html` | Static HTML of every board. Open it in a browser. |
| `assets/icons/*.svg` | The icon shapes used in the designs. Use them only where the project's icon set has no equivalent. |

---

## 0. Scope and rules

### 0.1 Source of truth

1. **The current code is the source of truth for every EXISTING screen.**
   - The screenshots redraw some existing screens around the new element: Settings, Account (14), Home, the traveler form (09), and support SUP-01/02/03.
   - Those redraws are approximations. Take only the added element from them (§0.2). Never take their layout, spacing or content.
2. **For NEW screens and sheets, the screenshots plus this spec are the target.** Build them with the project's own widgets and theme tokens, mapped to `tokens.json`.
3. **The designs were drawn with recreated components.** These are the button, field, chip, OTP, header, sheet and tab bar.
   - Use the project's existing widgets for these.
   - Only the 4 components in §3 are new.

### 0.2 Exact changes allowed on existing screens

Nothing else on these screens may change.

| Existing screen | Allowed change | Spec |
|---|---|---|
| Settings → Security / sign-in | Add the «التحقق بخطوتين» row, card or entry. Use the same row widget as its neighbours. | §4.1 |
| Settings → Security / sign-in | Add the «تغيير البريد الإلكتروني» row directly under «تغيير كلمة المرور». | §6.1 |
| Login flow (after a correct password) | Insert the 2FA step when the account has it on. Add the recovery-code path. | §4.5 |
| Traveler detail (any screen showing passport no., national ID, email or phone) | Replace the plain value with the masked value + eye control. | §5 |
| Traveler form (screen 09) | Add one small secondary button above the first field. Allow programmatic prefill of the fields. | §8.1 |
| Account (screen 14) | Add a camera badge on the avatar and make the avatar tappable. | §9.1 |
| Home header | Add an unread-count badge on the support icon. If there is no support icon, use the existing header icon button pattern. | §10.3 |
| Support list (SUP-01) | Unread rows get a violet dot and a Medium (500) title. | §10.3 |
| Support new ticket (SUP-02) | The category field opens the category sheet. | §10.2 |
| Support chat (SUP-03) | Show the rating card after the "ticket closed" system line. Show the «رسائل جديدة» divider. | §10.1, §10.4 |
| Wherever the app lists features (menu, account, home shortcuts) | Add the entry to Reports. Find the place where similar items live; if unclear, ask. | §7 |

### 0.3 Global rules

- RTL first. Latin codes, emails, phone numbers, passport numbers and recovery codes are rendered LTR (`Directionality(textDirection: TextDirection.ltr)` or `⁦…⁩`). They are right-aligned inside RTL rows.
- No dark backgrounds anywhere. That includes the camera and crop screens, which are light by design.
- Green and red only appear through the status pairs in `tokens.json`.
- One accent per card.
- Hero gradient: only on the existing wallet/balance hero. Never on new screens.
- Contrast rule: text at 11 and 13 px and all secondary copy use `secondary` #5B5280. `muted` #8A83A8 is only for placeholders, disabled content and decoration.
- Use the project's existing loading system: skeletons, button loaders, SeenLoader if `design/loading` is implemented. Never use a raw `CircularProgressIndicator`.
- Numbers: the designs show Arabic-Indic digits («٣٠ ث», «٢٤٨»). Follow the app's existing digit convention and number formatting. The ARB placeholders have no `format`, so add one if the project formats numbers through gen-l10n. Amounts, codes and IDs in tables stay Latin.
- Every screen that fetches data on open has these states: loading (skeleton), error (banner or inline state with «إعادة المحاولة»), empty (where a list can be empty), and no-permission (§11).

---

## 1. Design language

The values are in `tokens.json`. Map each one to the closest EXISTING theme token. Add a named constant to the theme only when nothing matches.

| Element | Spec |
|---|---|
| Screen | 390 wide, 20 side margin. Soft brand gradient at the top: 330 px, `rgba(123,82,245,.10)` → transparent. |
| Header | Starts 52 from the top and is 44 high. Round 44 back button on the right (white, 1px line, card shadow, icon brand). Title 16/24 Medium, centred. Optional sub 11/16 secondary. |
| Content | Starts at y≈116. 14 between major blocks. |
| Card | White, 1px `line`, radius 22, shadow `0 4 8 rgba(44,24,106,.06)`. 4 px vertical padding. Rows are padded 12/14 with 1px `line` dividers. |
| Field | 54 high, radius 16, 1.5px `lineStrong`, white. Read-only uses `violet05` with a `line` border. Focus border is `brand`; error border is `rejected.fg`. Label 13/20 Medium secondary, 6 px above the field. Helper 11/16. |
| Button | 52 / r16. Login is 58 / r20. Small is 40 / r14. Text 14/22 Medium. Primary uses the gradient `#7B52F5 → #9B7DF8`. Secondary is `violet10` with `link` text. Outline is white with 1.5 `lineStrong`. Destructive is `rejected` pair. Disabled is `violet10` with muted text. |
| Chip | Pill, height 26–28, 11/16 Medium, 6 px dot in the text colour. Uses the status pairs. |
| Filter chip | 28 high, `violet10` background, `processing.fg` text, optional × to remove. |
| Icon tile | 36–44, `violet10`, radius 11–14, line icon in `brand` at stroke 1.8. |
| Sticky actions | White. Padding 14/20/28. Top shadow `0 -12 16 rgba(44,24,106,.12)`. With two buttons, primary is on the right and secondary on the left, each half width with a gap of 10. |
| Bottom sheet | Top radius 30. Handle 40×4 in `lineStrong`. Title 18/28 Medium centred, with an optional 11/16 secondary sub. Scrim `#1B1530` at 32%. Padding 10/20/28. |
| Inline banner | Radius 16, padding 12/14, status pair colours, 18 icon. Optional 13 Medium title, 13/20 text. |
| Toast | White card, radius 22, toast shadow, 32 tile in the status pair, 14 Medium text. Sits above the sticky bar or tab bar. |
| Skeleton | `violet10` blocks with a white shimmer. |

---

## 2. Shared patterns

| Pattern | Used in | Build it as |
|---|---|---|
| Step progress (3 segments, 4 px, brand / line) | SEC-02…04 | The existing flow-progress widget if there is one (e.g. `SeenProgressRule`). |
| State block (72 tile r22, H2, body secondary max 300, optional small button) | REP-01 error, REP-04 empty/error, REP-06, PASS-02/04, SUP-07 | One shared widget. |
| No-permission block (SYS-03) | REP-06 (full screen), PRIV-02 (inline in card), REP-01 (locked source) | Use the existing SYS-03 widget. Add an inline variant if missing. |
| Toast | SEC-02 «نُسخ المفتاح السري», PROF-03 success | The existing snackbar/toast, styled per §1. |
| Sheet | PRIV-03, REP-05, PROF-02, SUP-07 | The existing sheet helper (e.g. `showSeenSheet`). |

---

## 3. New components

Reference code for all of these is in `reference/gaps_components.dart`. Put them next to the project's other shared widgets and use them as instances everywhere they appear.

### 3.1 `RatingStars`

| Prop | Values |
|---|---|
| `value` | 0–5 |
| `mode` | `input` (tappable) · `locked` (after submit) · `readonly` |
| `size` | `md`: 40 box, 32 star, gap 10, row height 44 · `sm`: 20 box, 16 star, gap 2 |
| `onChanged` | Only in `input` mode |

- **Colours:**
  - Selected star: filled `brand` with a `brand` stroke.
  - Unselected star: no fill, stroke `violet60` at 1.6.
  - In `locked` mode, selected uses `violet60` fill and unselected uses a `violet40` stroke.
- **Layout:** stars always run LTR (1 on the left, 5 on the right).
- **Semantics:** a radio group labelled «التقييم», each item «٣ من ٥». The tap target is at least 44.
- **Value words** under the stars once a value is chosen: 1 «سيئ»، 2 «مقبول»، 3 «جيد»، 4 «جيد جدًا»، 5 «ممتاز».

### 3.2 `SuggestionRow` (passport review)

| Prop | Values |
|---|---|
| `field` | Label text, 11/16 secondary |
| `value` | 14/22 Medium. LTR unless the value is Arabic. |
| `checked` | bool. Checkbox 22, r7. Checked = `brand` fill with a white tick. Unchecked = 1.5 `lineStrong`. |
| `confidence` | `high` · `low` |
| `applied` | bool |

- **Row:** min height 72, padding 12/14, divider on top except for the first row.
- **Low confidence (not applied):**
  - Row background is `violet05`.
  - Chip «ثقة منخفضة» uses the `action` pair.
  - The row defaults to **unchecked**.
- **Applied:** chip «طُبّق» in the `completed` pair, with a white background.

### 3.3 `ReportTable` / `TableCell`

- **Cell:** 44 high, padding 0 12.
- **Kinds:**

  | Kind | Background | Text | Top border |
  |---|---|---|---|
  | `header` | `violet05` | 11/16 Medium secondary | none |
  | `body` | white | 13/20 ink | 1 `line` |
  | `total` | `violet05` | 13/20 Medium | 1 `lineStrong` |

- **Numeric columns:** LTR, tabular figures, aligned to the end. Amounts use `#,##0.00`.
- **Table:**
  - Lives inside a card with no padding.
  - The first column («رقم الطلب», 104) is **sticky** with a 1px `line` divider on its left.
  - The other columns scroll horizontally, starting at the right edge (RTL).
  - A white→transparent fade of 28 px on the left edge shows when more content is hidden.
  - A 4 px scroll indicator sits under the table: track `line`, thumb `violet40`.
  - The last row is the totals row.
- Column widths in the design: 104 · 120 · 116 · 84 · 110.

### 3.4 `CountdownPill`

- **Look:** 28 high pill, padding 0 10 0 8. A 16 px ring icon shows the remaining time (track at 22% opacity, progress stroke 2.2, starting at 12 o'clock). Text is «٣٠ ث» in 11/16 Medium.
- **Tones:** `processing` pair by default. Switches to the `action` pair at ≤5 s.
- **Semantics:** `liveRegion` with the label «يُخفى بعد ٣٠ ثانية». Announce only at 10 s and at hide, not every second.

---

## 4. SEC — Two-step verification

### 4.1 SEC-01 · Settings entry

- **Entry:** Settings → «الأمان وتسجيل الدخول».
- **Layout:** a card with tile `shield`, title «التحقق بخطوتين», and sub «رمز من تطبيق المصادقة عند كل دخول». The chip on the leading side shows the status.

| State | What shows |
|---|---|
| Off | Chip `new` «غير مفعّل». Text «يحمي حسابك حتى لو عرف أحدٌ كلمة المرور.» Small primary button «تفعيل التحقق بخطوتين» goes to SEC-02. |
| On | Chip `completed` «مفعّل», followed by rows: |
| | • «رموز الاسترداد» — sub «٨ رموز استرداد متبقية» (live count). Opens a view of the remaining count and the regenerate option. Codes are never shown again. |
| | • «إنشاء رموز جديدة» — sub «تُلغى الرموز الحالية فور الإنشاء». Asks for confirmation, then shows SEC-04 with new codes. |
| | • «إيقاف التحقق بخطوتين» — destructive tile and text, no chevron. Requires a current TOTP code (SEC-03 layout) or the password, then confirmation. |
| Loading | Skeleton of the section labels and rows. |
| Error | Inside the 2FA card: `rejected` banner «تعذّر تحميل حالة التحقق بخطوتين. تحقق من اتصالك.» and a small outline button «إعادة المحاولة». The rest of the screen stays usable. |

### 4.2 SEC-02 · Step 1 — scan

- **Header:** «تفعيل التحقق بخطوتين», sub «الخطوة ١ من ٣».
- **Progress:** 1/3.
- **Copy:** H2 «امسح الرمز بتطبيق المصادقة». Body «افتح Google Authenticator أو أي تطبيق مصادقة، ثم امسح الرمز.»
- **QR card:**
  - QR 176 inside a 12 px padded white box with a 1px `line` border and r16. Generated from the `otpauth://` URI returned by the server.
  - Caption «أو أدخل المفتاح السري يدويًا».
  - Key field: read-only `violet05`, 54 high, monospace LTR, grouped in 4s (`JBSW Y3DP EHPK 3PXP`). A 40 copy button sits on the left.
- **Copy action:** copy to the clipboard, swap the icon to a tick in the `completed` pair for 2 s, and show the toast «نُسخ المفتاح السري».
- **Sticky:** «التالي» goes to SEC-03.
- **Loading:** QR and key skeleton. «التالي» disabled.
- **Error:** card with a 56 `rejected` alert tile, «تعذّر إنشاء رمز الإعداد», «تحقق من اتصالك ثم أعد المحاولة.», and outline «إعادة المحاولة». «التالي» disabled.
- **Rules:**
  - The secret is never logged or cached on disk.
  - Leaving the flow abandons the pending secret on the server.

### 4.3 SEC-03 · Step 2 — enter code

- **Header:** «تفعيل التحقق بخطوتين», sub «الخطوة ٢ من ٣».
- **Copy:** H2 «أدخل رمز التحقق». Body «اكتب الرمز المكوّن من ٦ أرقام الظاهر في تطبيق المصادقة.»
- **Input:** the project's OTP input (6 cells, LTR, `AutofillHints.oneTimeCode`). Auto-submit on the 6th digit.

| State | OTP | Under it | Sticky «تحقق» |
|---|---|---|---|
| Empty | Focused, empty | Caption with timer icon: «يتجدّد الرمز في التطبيق كل ٣٠ ثانية» | Disabled |
| Wrong code | Error, value kept | Error caption «الرمز غير صحيح. تبقّت محاولتان.» (live count) | Enabled |
| Expired (server says the code is outside the window) | Error | `action` banner. Title «انتهت صلاحية الرمز», text «أدخل الرمز الجديد الظاهر في التطبيق الآن.» | Enabled |
| Attempts exhausted (5 wrong) | Disabled, empty | `rejected` banner. Title «تجاوزت عدد المحاولات», text «أوقفنا الإدخال مؤقتًا لحماية حسابك. حاول مجددًا بعد ١٥ دقيقة.» | Disabled |
| Verifying | Disabled, filled | Same caption as Empty | Loading «جارٍ التحقق…» |

On success, go to SEC-04.

### 4.4 SEC-04 · Recovery codes

- **Header:** «رموز الاسترداد», sub «الخطوة ٣ من ٣».
- **Copy:** H2 «احفظ رموز الاسترداد». Body «استخدم أي رمز منها للدخول إذا فقدت هاتفك. كل رمز يُستخدم مرة واحدة.»
- **Banner:** `action`, «تظهر مرة واحدة — لن تتمكن من رؤيتها مجددًا بعد هذه الشاشة.»
- **Codes card:**
  - 8 codes in a 2-column LTR grid.
  - Each code is a 40-high `violet05` pill (r12) with an index `01` (muted) and the code in monospace, format `XXXX-XXXX`.
- **Actions:** two small secondary buttons.
  - «نسخ الكل» copies all codes, one per line.
  - «تنزيل» saves a `.txt` named `seen-recovery-codes.txt` via the share sheet or file save.
- **Confirmation:** checkbox «حفظت الرموز في مكان آمن».
- **Sticky «تم»:** disabled until the checkbox is on. Tapping it returns to SEC-01 in the On state.
- **Back gesture:** blocked until «تم», or confirm with a dialog.
- **Screenshot:** allowed on this screen only.
- **Loading:** grid skeleton.
- **Error:** `rejected` banner. Title «لم تُنشأ الرموز», text «تعذّر إنشاء رموز الاسترداد. التحقق بخطوتين مفعّل، ويمكنك إنشاء الرموز من الإعدادات لاحقًا.» Plus outline «إعادة المحاولة». «تم» disabled.

### 4.5 SEC-05 · Login with 2FA

This step is inserted after a correct password when the account has 2FA on.

- **Header:** «تسجيل الدخول» with back.
- **Code screen:**
  - Tile `shield` 56, H1 «رمز التحقق».
  - Body: «أدخل الرمز من تطبيق المصادقة لإكمال الدخول إلى» + the email (LTR).
  - OTP input.
  - Centred link «فقدت هاتفك؟ استخدم رمز استرداد».
  - Sticky login button (58/r20) «تسجيل الدخول», disabled until 6 digits are entered.
- **Recovery code screen:**
  - Tile `key`, H1 «رمز الاسترداد».
  - Body «أدخل أحد رموز الاسترداد التي حفظتها عند تفعيل التحقق بخطوتين.»
  - Field «رمز الاسترداد»: LTR, placeholder `XXXX-XXXX`, auto-inserts the hyphen and uppercases. Helper «كل رمز يُستخدم مرة واحدة فقط».
  - Link «استخدم تطبيق المصادقة بدلًا من ذلك».
- **Wrong recovery code:** error helper «الرمز غير صحيح أو سبق استخدامه.»
- **Locked:**
  - `rejected` banner. Title «أُقفل الدخول مؤقتًا», text «محاولات كثيرة غير صحيحة. حاول بعد ١٥ دقيقة أو تواصل مع الدعم.»
  - Field disabled, login disabled.
  - Link «تواصل مع الدعم» opens the support entry that is available before login, if one exists.
- **After a recovery code is used:** the server decrements the count. If ≤2 remain, show an `action` banner on Home or Settings suggesting new codes.

---

## 5. PRIV — Reveal masked values

- **Applies to:** passport number, national ID, traveler email and traveler phone, on every traveler detail surface.
- **Masking format:** keep the last 4 characters (`••••••4821`). For emails, keep the first 2 characters and the domain (`sa•••••@mail.com`). For phones, keep the country code and last 3 digits (`+966 5•• ••• 214`).
- **Masked text style:** `secondary` colour, letter-spacing .08em.
- Non-sensitive fields (birth date, nationality) stay plain.

### 5.1 PRIV-01 · States

| State | Row |
|---|---|
| Hidden | Masked value + 36 icon button `eye` (`violet10`, r12), labelled «إظهار». |
| Revealed | Full value (14 Medium ink, LTR) + `CountdownPill` (30 s) + small secondary button «إخفاء» (icon `eyeOff`, w≈92). |
| Loading (screen) | Skeleton. |
| Error (screen) | `rejected` banner. Title «لم تُحمَّل البيانات», text «تعذّر تحميل بيانات المسافر. تحقق من اتصالك ثم أعد المحاولة.» Plus outline retry. |

Under the identity card: caption with lock icon «القيم الحساسة مخفية افتراضيًا، وكل إظهار يُسجَّل باسمك.»

### 5.2 Reveal rules

1. Tap the eye to call the server reveal endpoint.
   - While waiting, the value becomes a 118×14 skeleton and the eye button shows the small loader (PRIV-02 «جارٍ الإظهار»).
2. Show the value and start the 30 s countdown. At 0, or on «إخفاء», the value is masked again.
3. Only **one** value can be revealed at a time. Revealing another hides the previous one.
4. Hide immediately when:
   - the app goes to the background;
   - the screen is left;
   - the screen locks.
5. Never cache the plain value (memory only). No copy, no long-press select. Exclude it from screenshots and recents where the platform allows (Android `FLAG_SECURE` while a value is visible).
6. **Rate limit:** the server returns 429 with `retryAfter`.
   - Show PRIV-02 «تجاوز حد الإظهار»: the eye buttons are disabled (`violet05` with a muted icon).
   - `action` banner «وصلت إلى حد الإظهار (١٠ مرات في الساعة). يمكنك المحاولة بعد ١٢ دقيقة.» (live minutes).
7. **No permission (server flag):**
   - Lock icon instead of the eye.
   - The card ends with an inline SYS-03 row: tile `lock` (`new` pair), «ليس لديك صلاحية لإظهار هذه القيم», «صلاحية «إظهار البيانات الحساسة» يمنحها مدير الحساب.», and link «اطلب الصلاحية».

### 5.3 PRIV-03 · First-use sheet

Shown once per user, before the first reveal. The flag is stored server-side or per account.

- **Sheet:** tile `eye`, title «قبل إظهار القيمة», sub «يظهر هذا التنبيه مرة واحدة».
- **Three lines**, each with a 36 tile:
  - `shield` — «الإظهار مسجّل ولا يُحفظ على جهازك» / «نسجّل من أظهر القيمة ومتى، ولا تُخزَّن في التطبيق.»
  - `timer` — «تختفي تلقائيًا بعد ٣٠ ثانية» / «ويمكنك إخفاؤها قبل ذلك بزر «إخفاء».»
  - `lock` — «النسخ غير متاح» / «لحماية بيانات المسافر لا تُنسخ القيم الحساسة.»
- **Actions:** primary «إظهار» (continues the reveal) and secondary «إلغاء».

---

## 6. ACC — Change email

### 6.1 ACC-08 · Settings row

- **Row:** directly under «تغيير كلمة المرور». Tile `mail`, title «تغيير البريد الإلكتروني», sub = the current email (LTR).
- **Pending state** (a change was requested and not confirmed):
  - Sub «بانتظار تأكيد» + the new email.
  - Chip `action` «بانتظار التأكيد».
  - Caption under the card: «يبقى بريدك الحالي فعّالًا حتى تؤكد البريد الجديد.»
  - Tapping the row opens ACC-10 for the pending email.
- Loading and error follow the existing settings screen.

### 6.2 ACC-09 · Form

- **Header:** «تغيير البريد الإلكتروني».
- **Intro:** «سنرسل رابط تأكيد إلى بريدك الجديد، ويبقى بريدك الحالي فعّالًا حتى تؤكد.»
- **Fields:**
  1. «البريد الحالي» — read-only (`violet05`, lock icon, LTR).
  2. «البريد الجديد» — LTR, email keyboard, placeholder `name@mail.com`.
  3. «كلمة المرور الحالية» — obscured with an eye toggle.
- **Sticky:** «إرسال رابط التأكيد».

| State | Behaviour |
|---|---|
| Default | Sticky disabled until both editable fields are filled. |
| Invalid email (validate on blur and on submit) | Error «أدخل بريدًا إلكترونيًا صحيحًا، مثل name@mail.com». |
| Same as current | Error «هذا هو بريدك الحالي». |
| Email already used (server) | Error «هذا البريد مستخدم في حساب آخر». |
| Wrong password (server) | Error on the password field «كلمة المرور غير صحيحة. تبقّت ٣ محاولات.» |
| Too many attempts (server 429) | `rejected` banner. Title «أوقفنا التغيير مؤقتًا», text «محاولات كثيرة. حاول مجددًا بعد ١٠ دقائق.» Fields and sticky disabled. |
| Sending | Sticky loading «جارٍ الإرسال…». |
| Success | Replace with ACC-10. |

### 6.3 ACC-10 · Check your email

- **Header:** «تغيير البريد الإلكتروني» with a **close** button, not back.
- **Centred content:**
  - Tile `mail` 72 r22.
  - H1 «تحقق من بريدك».
  - «أرسلنا رابط التأكيد إلى» + the new email (14 Medium LTR).
  - Caption «افتح الرابط خلال ٢٤ ساعة لإكمال التغيير. يبقى بريدك الحالي فعّالًا حتى ذلك.»
  - Link «تعديل البريد المُدخل», which goes back to ACC-09 with the value filled.
- **Sticky:**
  - Primary «فتح البريد» (icon `mail`) opens the default mail app (`mailto:` or the platform intent).
  - Secondary «إعادة الإرسال».
- **Resent:** `completed` banner «أعدنا إرسال الرابط. تحقق أيضًا من مجلد الرسائل غير المرغوب فيها.» The secondary button is disabled with a countdown «إعادة الإرسال ٠:٤٥» (60 s cooldown).
- **Failed:** `rejected` banner «تعذّر إرسال الرابط. تحقق من اتصالك ثم أعد المحاولة.» The secondary button is re-enabled.
- **After confirmation** (deep link from the email, or a refreshed profile):
  - Settings shows the new email.
  - Toast «تم تغيير البريد الإلكتروني».
  - The server notifies the old email.

---

## 7. REP — Reports

- **Entry:** add «التقارير» where account-level tools live (§0.2).
- **Visibility:** depends on the `reports` permission. Without it, show REP-06.

### 7.1 REP-01 · Sources

- **Header:** «التقارير».
- **Intro:** «اختر مصدر البيانات لإنشاء تقرير مخصص وتصديره.»
- **Two source cards** side by side (equal width, 132 high, the project's service-card style):
  - tile 44, chevron, title 16 Medium, sub 11.
  - «الحجوزات» — «الطلبات والمسافرون والحالات».
  - «المحفظة» — «العمليات والرسوم والتسويات».
- **Without the `wallet` permission:** the wallet card shows tile `lock` (`new` pair), sub «تحتاج صلاحية «المحفظة»» and chip `new` «بلا صلاحية». It is not tappable.
- **«تقارير سريعة»:** rows open REP-03 directly with presets.
  - «حجوزات هذا الشهر» — «كل الحالات · ١–٣٠ سبتمبر» (dynamic).
  - «الطلبات المكتملة» — «آخر ٣٠ يومًا».
  - «عمليات المحفظة» — «آخر ٣٠ يومًا». Hidden without the wallet permission.
- **«آخر الملفات المصدّرة»:**
  - Rows with tile `table`, the file name (LTR) and «٢١ أكتوبر · ٢٤٨ صفًا», plus a download icon button.
  - Files are kept 7 days. The section is hidden when empty.
- **Loading:** skeleton. **Error:** state block «تعذّر تحميل التقارير» / «تحقق من اتصالك ثم أعد المحاولة.» with retry.

### 7.2 REP-02 · Builder

- **Header:** title «تقرير الحجوزات» (or «تقرير المحفظة»), sub «منشئ التقرير».
- **«الفترة»:** segmented control «٧ أيام · ٣٠ يومًا · هذا الشهر · مخصص». Default «٣٠ يومًا».
  - «مخصص» reveals two date fields side by side: «من» and «إلى» with a calendar icon. They open the existing date picker.
  - **Invalid range:** error under «إلى»: «قبل تاريخ البداية». «عرض التقرير» disabled.
  - Max range 12 months. Error «أقصى فترة ١٢ شهرًا».
- **«الأعمدة»:** the label shows a counter on the left («٥ من ٦»). Checkbox rows in a card.
  - Bookings columns: رقم الطلب, المسافر, الخدمة, الحالة, المبلغ (all on), الوكيل الفرعي (off).
  - «رقم الطلب» is always on and disabled.
  - At least 2 columns must be on.
- **«التصفية»:**
  - Removable filter chips («الحالة: مكتملة ×», «الفرع: الرياض ×»).
  - A dashed outline chip «+ إضافة تصفية» opens a sheet listing the filters: الحالة, الخدمة, الفرع, الوكيل الفرعي.
- **Sticky:** primary «عرض التقرير», secondary «إعادة ضبط» (resets to the defaults).
- **Loading:** skeleton, both buttons disabled.

### 7.3 REP-03 · Result

- **Header:** report title, sub = the period («١–٣٠ سبتمبر ٢٠٢٦»), trail `more` (share settings or a save-as-quick-report option, if supported).
- **Top:** the applied filter chips (not removable) and a link «تعديل» on the left that returns to REP-02.
- **KPI cards:** two equal cards: «عدد الطلبات» «٢٤٨» and «الإجمالي» «٤٨٬٩٦٠ ر.س». Values are H2.
- **Table:** `ReportTable` (§3.3). Pagination or lazy loading for long results. The totals row is always last.
- **Sticky:** primary «تصدير» (icon `download`) opens REP-05. Secondary «تعديل» (icon `filter`).
- **Loading:** chips, KPI and row skeletons. «تصدير» disabled.

### 7.4 REP-04 · States

| State | What shows |
|---|---|
| No results | State block: tile `search`, «لا توجد نتائج», «لا حجوزات تطابق الفترة والتصفية المختارة. جرّب توسيع الفترة أو إزالة بعض عوامل التصفية.», and small secondary «تعديل التصفية». |
| More than 5000 rows | `action` banner. Title «النتيجة تتجاوز ٥٠٠٠ صف», text «يعرض التطبيق أول ٥٠٠٠ صف فقط. ضيّق الفترة، أو صدّر الملف ليصلك كاملًا.» The table shows the first 5000 rows. Sticky primary «تصدير الكل», secondary «تضييق الفترة». |
| Generating (server job) | Centred loader (SeenLoader 56), «جارٍ إنشاء التقرير…», «قد يستغرق ذلك بضع ثوانٍ للفترات الطويلة.», and small secondary «إلغاء». Poll or stream the job. |
| Error | State block `rejected`: «تعذّر إنشاء التقرير», «حدث خطأ أثناء تجهيز البيانات. حاول مجددًا بعد قليل.», and outline «إعادة المحاولة». |

### 7.5 REP-05 · Export sheet

- **Sheet:** title «تصدير التقرير», sub «٢٤٨ صفًا · ٥ أعمدة».
- **Format rows** with a 36 tile and a radio:
  - PDF — «مناسب للطباعة والمشاركة».
  - Excel · XLSX — «للتحليل والتعديل». This is the default.
  - CSV — «لاستيراده في أنظمة أخرى».
- **Toggle:** «تضمين صف الإجماليات» (on).
- **Actions:** primary «تصدير» (icon `download`) and secondary «إلغاء».
- **Exporting:** the format rows are disabled (muted text) and the primary shows a loader «جارٍ التصدير…».
- **Ready:**
  - Tile `checkCircle` (`completed`), title «الملف جاهز», sub «يُحفظ في «آخر الملفات المصدّرة» لمدة ٧ أيام».
  - A file row: name (LTR), «٨٤ ك.ب · ٢٤٨ صفًا».
  - Actions: primary «مشاركة» (system share) and secondary «تنزيل».
- **Failed:** `rejected` banner «تعذّر تجهيز الملف. تحقق من اتصالك ثم أعد المحاولة.» above the options. Actions: «إعادة المحاولة» and «إلغاء».
- **File name pattern:** `bookings-<yyyy-mm>.xlsx` or `wallet-<from>_<to>.csv` (LTR, latin).

### 7.6 REP-06 · No permission

- **Header:** «التقارير».
- **State block:** tile `lock` (`new` pair), «ليس لديك صلاحية», «التقارير متاحة لمدير الحساب ولمن يملك صلاحية «التقارير». اطلبها من مدير حسابك.», and small secondary «العودة إلى الرئيسية».

---

## 8. PASS — Read passport from a photo

### 8.1 PASS-01 · Entry in the traveler form (screen 09)

- **Button:** above the first field of the existing form. Full-width small secondary button (40/r14) «صوّر الجواز لقراءة البيانات» with icon `scan`.
- **Caption under it:** «أو أدخل البيانات يدويًا كما تظهر في الجواز». Centred, 11 secondary.
- **After applying suggestions:**
  - The caption is replaced by a `completed` banner «عبّأنا ٥ حقول من الجواز. أكمل تاريخ الميلاد وراجع البيانات قبل الحفظ.» (live count and the names of skipped fields).
  - Applied fields show the field's valid state.
  - The first unfilled field is focused.
- Hide the button if the feature flag is off or the service is reported unavailable. The form must work exactly as before.

### 8.2 PASS-02 · Capture (LIGHT)

- **Header:** «تصوير الجواز» with **close**, trail `help` (opens tips).
- **Camera area:**
  - Full width, 420 high, r22.
  - Over the preview: a 300×212 guide with a 2px dashed `lineStrong` border (r16) and four 28 px `brand` corner brackets (3px, r16).
  - Inside the guide, while empty: icon `passport`, «ضع صفحة البيانات داخل الإطار», «بحيث يظهر السطران السفليان كاملين».
  - The area outside the guide is a light veil (white at ~55%), **not** a dark scrim.
- **Tips row:** three tiles — «إضاءة جيدة» (sun), «دون انعكاس» (scan), «الصفحة كاملة» (passport).
- **Sticky:** primary «التقاط» (camera), secondary «من الصور» (image picker).
- **Low light** (luminance check or platform exposure): `action` banner «الإضاءة ضعيفة. اقترب من مصدر ضوء وتجنّب الظل على الصفحة.» above the area. The area shrinks to 356.
- **Camera denied:** card state block, tile `camera` (`rejected`), «لا يمكن الوصول إلى الكاميرا», «اسمح لسين باستخدام الكاميرا من إعدادات الجهاز، أو اختر صورة الجواز من الصور.» Sticky: «فتح الإعدادات» (app settings) and «من الصور».
- **Image constraints:**
  - JPG/PNG/HEIC.
  - Downscale to ≤2000 px long side and ≤2 MB before upload.
  - Strip EXIF location.
  - Delete the local temp file after reading.

### 8.3 PASS-04 · Reading states

| State | What shows |
|---|---|
| Reading | Captured image area (420) with a solid `violet40` guide. Centre: SeenLoader 44, «جارٍ قراءة البيانات…», «يستغرق ذلك بضع ثوانٍ». Sticky: secondary «إلغاء». |
| Failed | `rejected` banner. Title «تعذّرت قراءة الجواز», text «تأكد من وضوح الصورة وظهور صفحة البيانات كاملة، ثم صوّرها مجددًا.» Small preview. Sticky: «إعادة التصوير» and «إدخال يدوي» (back to the form). |
| Service unavailable | State block: tile `scan` (`new`), «القراءة الآلية غير متاحة الآن», «يمكنك إكمال بيانات المسافر يدويًا، وستعود القراءة قريبًا.» Sticky primary «متابعة بالإدخال اليدوي». |
| Not an image | `action` banner «الملف المختار ليس صورة. اختر صورة بصيغة JPG أو PNG.» above the capture area. |

### 8.4 PASS-03 · Review

- **Header:** «مراجعة البيانات», sub «من صورة الجواز».
- **Summary card:** thumbnail 64×44, «قرأنا ٦ حقول من الجواز», «حدّد ما تريد تطبيقه على النموذج».
- **Suggestions card:** one `SuggestionRow` per field returned. The order follows the form: الاسم الأول, اسم العائلة, رقم الجواز, تاريخ الميلاد, الجنسية, تاريخ انتهاء الجواز.
- **Defaults:** high confidence is checked. Low confidence (score < 0.80, or the server flag) is unchecked.
- **Caption:** «الحقول منخفضة الثقة غير محددة افتراضيًا — راجعها قبل تطبيقها.»
- **Sticky:**
  - Primary «تطبيق N حقول» (N = checked count; disabled at 0).
  - Secondary «إعادة التصوير».
- **Apply:** fill **only empty or unchanged** form fields. If a field already has a different user-typed value, overwrite it only when its row is checked. Then return to the form (PASS-01 after-apply state).
- **Formats:** names in uppercase Latin, dates normalised to the form's format, nationality mapped to the form's country list.

---

## 9. PROF — Profile photo

### 9.1 PROF-01 · Account (screen 14)

- Avatar 88 with a camera badge.
  - **Badge:** a 32 white circle at the bottom-left corner (trailing side in RTL), 1px `line` border, card shadow, camera icon in `brand`.
  - The whole avatar is tappable and labelled «تغيير الصورة».
- With no photo, the avatar shows the initial on `violet10`.

### 9.2 PROF-02 · Options sheet and crop

- **Options sheet:** title «الصورة الشخصية», sub «JPG أو PNG بحجم أقصى ٥ م.ب».
  - Rows: «التقاط صورة» (camera), «اختيار من الصور» (image), and «حذف الصورة» (trash, destructive text, only when a photo exists).
  - Secondary «إلغاء».
- **Crop:**
  - Header «معاينة الصورة» with close.
  - 350 square area (r22) showing the image, a light veil outside a 280 circle, and a 2px `brand` circle outline.
  - Pan and pinch to zoom. Slider under it from the small image icon to the large image icon (track `line`, fill `brand`, 22 white knob).
  - Caption «حرّك الصورة وكبّرها لضبطها داخل الدائرة».
  - Sticky: primary «استخدام», secondary «إعادة» (re-pick).
- **Output:** square 1:1, 512×512 JPEG at quality 0.85.

### 9.3 PROF-03 · Upload states

| State | What shows |
|---|---|
| Uploading | Avatar shows the new image with a progress ring (stroke 6, `brand` over white 70%). Upload card: tile `image`, «profile.jpg», «١٫٢ م.ب · ٦٤٪», 6 px progress bar, and a cancel icon button. Navigation stays possible. |
| Too large (client check before upload) | Avatar unchanged. `rejected` banner. Title «لم تُرفع الصورة», text «حجم الصورة ٧٫٨ م.ب والحد الأقصى ٥ م.ب. اختر صورة أصغر.» |
| Wrong type | Same banner with «الصيغة غير مدعومة. اختر صورة JPG أو PNG.» |
| Network failure | Upload card in the `rejected` tile, «تعذّر الرفع — تحقق من اتصالك», bar in `rejected.fg`, and small outline «إعادة». |
| Success | Avatar updated. Toast «تم تحديث الصورة». Refresh the avatar everywhere: header, home. |
| Deleted | Initial avatar. Toast «حُذفت الصورة الشخصية». |

---

## 10. SUP — Support

### 10.1 SUP-06 · Rating card (end of SUP-03 when the ticket is closed)

- **Placement:** after the system line «أُغلقت التذكرة · <date time>» (centred pill, `new` pair, with hairlines on both sides).
- **Card:** title «كيف كانت تجربتك مع الدعم؟», sub «تقييمك يساعدنا على تحسين الخدمة», then `RatingStars` input, value 0.
- **After choosing stars:**
  - The value word («جيد جدًا»).
  - Optional comment field (64 high, placeholder «أضف تعليقًا (اختياري)», max 500).
  - Small primary «إرسال التقييم».
- **Sending:** stars become read-only and the button shows a loader «جارٍ الإرسال…».
- **Error:** `rejected` banner «تعذّر إرسال التقييم. حاول مجددًا.» The button becomes «إعادة المحاولة» (refresh icon). The value and comment are kept.
- **Done:**
  - Title changes to «تقييمك للمحادثة».
  - Stars `locked`.
  - Success line (tick icon, `completed.fg`) «شكرًا لتقييمك» and caption «لا يمكن تعديل التقييم بعد إرساله.»
  - Re-opening the ticket shows this state.
- **Closed ticket bar** replaces the composer: caption «هذه التذكرة مغلقة، ويمكنك فتح تذكرة جديدة في أي وقت.» and secondary «فتح تذكرة جديدة».

### 10.2 SUP-07 · Category picker (from SUP-02)

- The «التصنيف» field becomes a picker: chevron, placeholder «اختر التصنيف». Tapping opens a sheet.
- **Sheet:** title «تصنيف التذكرة», sub «اختر الأقرب لمشكلتك».
  - Search field (54, `search` icon, clear ×, placeholder «ابحث في التصنيفات»).
  - Then a card of rows: 36 tile, title, sub, and a radio. Selecting a row closes the sheet and fills the field.
- **Categories** come from the server, with icon, title, description and an optional explanation. Example data:
  - الحجوزات والتذاكر — تعديل، إلغاء، تأكيد.
  - المدفوعات والمحفظة — شحن، رسوم، فواتير.
  - تصحيح مالي — طلب تعديل مبلغ أو استرداد فرق.
  - الحساب والصلاحيات — الموظفون والأدوار.
  - المسافرون والوثائق — الجوازات والتأشيرات.
  - أخرى — لم أجد التصنيف المناسب.
- **«أخرى»:** always present and always last. It is a local fallback when the request fails.
- **Search:**
  - Filters on the client by title and description.
  - Arabic normalisation: ignore diacritics and tatweel; treat أ/إ/آ = ا, ة = ه, ى = ي.
  - Highlight the match with a `violet10` background and `processing.fg` text. Normalisation can change the string length, so map the match range back to the original text before highlighting. Matching character by character over the normalised form is enough.
  - When the category has an explanation, show it under the result as a `processing` banner. Example — title «ما هو التصحيح المالي؟», text «لطلب تعديل مبلغ عملية أو استرداد فرق سعر. أرفق رقم العملية إن وُجد لنسرّع المراجعة.»
- **No results:** tile `search` (`new`), «لا توجد تصنيفات مطابقة», «اختر «أخرى» واكتب مشكلتك بالتفصيل.», then the «أخرى» row.
- **Loading:** search disabled + 5 row skeletons.
- **Error:** `rejected` banner. Title «حدث خطأ», text «تعذّر تحميل التصنيفات. أعد المحاولة أو اختر «أخرى».» Outline retry, then the «أخرى» row.

### 10.3 SUP-08 · Unread

- **Home header badge:** on the support icon button (44 round).
  - Pill min 20×20, `brand` background, 2px white ring, white 11/16 Medium count, offset −4/−4 at the top-left corner (trailing side in RTL).
  - Shows up to «٩+». Hidden when 0.
  - Semantics «٣ رسائل غير مقروءة».
- **Support list (SUP-01):**
  - Unread ticket rows get an 8 px `brand` dot at the start, aligned to the title.
  - Unread titles are 14 Medium (500). Read titles are 14 Regular. Both are ink.
  - Sub: last message preview + time, one line with ellipsis.
  - Status chip at the end.
  - Above the list: «٣ تذاكر بردود جديدة» and a link «تعليم الكل كمقروء».
- **Source:** the unread count comes from the server and updates on push or when the app resumes.
- **Marking read:** opening a ticket marks it read. The badge updates without a reload.
- **Loading:** segmented + 5 row skeletons.

### 10.4 SUP-09 · No unread and the divider

- **No unread:** no badge. The list caption reads «لا توجد ردود جديدة» and no row has a dot.
- **Chat:** when opening a ticket with unread messages:
  - Insert a divider before the first unread message: a `processing` pill «رسائل جديدة (٢)» with `violet40` hairlines.
  - Scroll so the divider is near the top.
  - The divider stays until the screen is left.

---

## 11. Permissions (the 8th gap — documentation)

- Every action, source and value is shown according to **server permissions**. Never hide something only in the UI, and never trust a client flag.
- Every screen has a no-permission state in the SYS-03 pattern.
  - **Full screen** (REP-06): tile `lock` (`new` pair), title, explanation, and a way back.
  - **Inline in a card** (PRIV-02): a lock instead of the action, plus a row with the explanation and «اطلب الصلاحية».
  - **Locked entry** (REP-01 wallet source): `lock` tile, chip «بلا صلاحية», not tappable.
- **Permissions used:**
  - `reports`
  - `wallet`
  - `reveal_sensitive`
  - `travelers.write` (passport reading)
  - `support`
- If a permission is revoked mid-session, the next server 403 must switch the screen to its no-permission state. It must not show a generic error.

---

## 12. Backend contract (assumed)

**Map these to the project's existing API layer.** If an endpoint doesn't exist:

- create the repository interface and a fake implementation behind a flag;
- list it in your report.

Don't invent production URLs.

| Feature | Need | Notes |
|---|---|---|
| SEC | `GET 2fa/status` → `{enabled, recoveryCodesLeft}` | |
| | `POST 2fa/setup` → `{otpauthUri, secret}` | |
| | `POST 2fa/verify {code}` → `{recoveryCodes[8]}` | Errors: `invalid_code{attemptsLeft}`, `expired_code`, `locked{retryAfter}` |
| | `POST 2fa/recovery-codes/regenerate` | |
| | `POST 2fa/disable {code or password}` | |
| | Login: `POST auth/2fa {challengeId, code \| recoveryCode}` | |
| PRIV | `POST travelers/{id}/reveal {field}` → `{value}` | Errors: `429{retryAfter}`, `403`. Audit logged server-side. |
| | `GET me/flags.revealIntroSeen`, `POST …` | |
| ACC | `POST me/email-change {newEmail, password}` | Errors: `invalid_password{attemptsLeft}`, `email_taken`, `429{retryAfter}` |
| | `POST me/email-change/resend`, `GET me` → `pendingEmail` | |
| REP | `GET reports/sources`, `POST reports/query {source, period, columns, filters}` | → `{rows, totals, total, truncated}` or `{jobId}` |
| | `GET reports/jobs/{id}`, `POST reports/export {…, format, includeTotals}` → `{fileId}` | |
| | `GET reports/files` | Kept 7 days |
| PASS | `POST travelers/passport-read (multipart image)` | → `{fields:[{key, value, confidence}]}` or `503 unavailable` / `422 unreadable` / `415 not_image` |
| PROF | `PUT me/avatar (multipart, progress)`, `DELETE me/avatar` | `413` too large, `415` type |
| SUP | `POST tickets/{id}/rating {stars, comment}` (once) | |
| | `GET support/categories` | |
| | `GET support/unread-count`, `POST tickets/{id}/read` | |
| | Ticket messages include `isUnread` | |

Numbers in the designs are examples until the server confirms them:

- 5 attempts and a 15-minute lock;
- 10 reveals per hour;
- 5000 preview rows;
- 5 MB per photo;
- 24-hour email link and 60-second resend.

---

## 13. Accessibility and RTL

- Minimum tap target 44.
- Every icon-only button has a semantic label: «إظهار», «إخفاء», «نسخ المفتاح», «تنزيل», «إلغاء الرفع», «تغيير الصورة».
- OTP and recovery fields are LTR. The cursor starts at the left.
- Countdowns and progress use live regions, throttled (§3.4).
- Reduce motion: no shimmer sweep and no ring animation. Values just update.
- Large text: cards grow vertically and nothing is clipped. The report table keeps a fixed row height and gets wider.

---

## 14. Acceptance checklist

- [ ] Every frame in `screenshots/frames` has a matching state in code (see `screenshots/INDEX.md`).
- [ ] Existing screens: only the changes in §0.2. Loaded-state goldens before and after are identical everywhere else.
- [ ] No raw `CircularProgressIndicator`. Loading uses the project's loading system.
- [ ] No dark surfaces. Green and red only through status pairs. Small text uses `secondary`.
- [ ] All strings come from l10n using `copy/app_ar.arb` and `copy/app_en.arb`. No hard-coded Arabic.
- [ ] PRIV: one value at a time; 30 s auto-hide; hides on background; never persisted; `FLAG_SECURE` while visible.
- [ ] SEC: secret and codes never logged; «تم» gated by the checkbox; locked state honours `retryAfter`.
- [ ] REP: sticky first column, totals row, horizontal scroll, truncation banner over 5000 rows, export ready/fail.
- [ ] PASS: low confidence unchecked by default; the manual path always works; temp image deleted.
- [ ] PROF: client-side size/type check before upload; progress; avatar refreshed app-wide.
- [ ] SUP: rating once and locked; «أخرى» always available; unread badge and dots update after opening a ticket.
- [ ] Tests:
  - widget tests for `RatingStars`, `SuggestionRow`, `ReportTable` (sticky and totals), and `CountdownPill`;
  - `RevealController` with fake async: 30 s auto-hide, one value at a time, hide on background, 429 and 403 handling, no notify after dispose;
  - goldens for one frame per screen in RTL;
  - unit test for the Arabic search normalisation.
