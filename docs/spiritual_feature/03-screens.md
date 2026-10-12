# 03 · Screens

Reference artboard for each screen is in `design/reference/`. Frame: 390 × 844 logical px (dashboard 1180 tall scroll, prayer 1000 tall scroll). Routes in brackets.

---

## 1 · Spiritual Dashboard — `Main.dc.html` [`/`]

Scrollable column, gutter 16, card gap 16, bottom nav fixed.

1. **Top bar** — location button (pin icon accent + city 18/700 + chevron, opens city picker sheet); Hijri date pill (white, border, 15/500, from `hijri` + device locale `ar`); profile 48 icon button.
2. **Next prayer card** — label "الصلاة القادمة" (caption muted), prayer name (h1), countdown pill accent ("متبقي ٠٠:٣٥", live, updates every 30 s), time in `display` + period word ("ظهرًا"). Below: 5-column timeline (الفجر…العشاء): 4 px bar per column — past = accentMid, next = accent, future = track; name 14, time 15. Tapping the card → Prayer screen.
3. **Today's rites card** — "مناسك اليوم" + "وضع الحاج" tag, title (h2) and step text "الشوط ٣ من ٧" from the active Tawaf session; 7-segment bar (done accent / current accentMid / future track); Umrah step row "✓ الإحرام · **الطواف** · السعي · التقصير"; primary button "متابعة النسك" → Tawaf. Hidden when no rite session is active (show a quieter "ابدأ العمرة" card instead).
4. **Daily reading card** — sage book icon tile, "وِردك اليومي", "سورة الكهف • صفحة ٢٩٣", percent in sage, sage progress bar, "٣ من ٥ صفحات" and link "إكمال القراءة" → Reader at last position.
5. **الخدمات grid** — 3 columns × 2 rows `ServiceTile`: المصحف الشريف → Quran index · رفيق الطواف والسعي → Tawaf · الأدعية المأثورة → Duas · اتجاه القبلة → Qibla · مواقيت الصلاة → Prayer · أذكار المسافر → Tasbeeh (or Duas filtered on travel — product decision, default Tasbeeh as in mockup).
6. **Bottom nav** — الرئيسية (active) · المناسك → Tawaf · المصحف → Quran index · حسابي.

## 2 · Tawaf & Sa'i Field Companion — `Tawaf.dc.html` [`/tawaf`]

Designed for one-handed use while walking in bright sun. Keep screen awake (`wakelock_plus`) while open.

- **Top bar**: back · title "طواف العمرة"/"سعي العمرة" · outlined "إنهاء النسك" (asks confirmation sheet before ending).
- **Mode segmented**: الطواف | السعي. Switching mode resets to lap 1 (confirm if current session has progress).
- **Counter**: 256 px `SegmentedRing` (7 segments, counter-clockwise like the Tawaf itself). Center: "الشوط" 18, number 112/800, "من ٧" 22 muted. Completed state: 72 px accent circle with white check + "اكتمل الطواف/السعي".
- **Guidance line** (17/700) under the ring: Tawaf lap 1 "ابدأ من الحجر الأسود، والكعبة عن يسارك", other laps "الكعبة عن يسارك • ينتهي الشوط عند الحجر الأسود"; Sa'i odd laps "من الصفا إلى المروة", even "من المروة إلى الصفا"; completed "تقبّل الله طوافك/سعيك".
- **Status + undo row**: status pill ("تم تسجيل الشوط ٢") — accent-tint flash for 1.2 s after an action, then neutral; outlined "إلغاء شوط" (disabled at lap 1 with 0.45 opacity). Undo is deliberately small and away from the main button.
- **Dua card**: label (Tawaf: "بين الركن اليماني والحجر الأسود", Sa'i: "عند الصعود على الصفا والمروة"), audio toggle pill "استماع/إيقاف" (just_audio, plays the recitation for the current dua), dua text 25 sp centered (Uthmani font for Quranic text, Amiri for hadith dhikr).
- **Primary button** (bottom, 96 tall, radius 26): "+ تسجيل الشوط التالي" / "تسجيل الشوط الأخير" (lap 7) / "الانتقال إلى السعي" (Tawaf done) / "تم بحمد الله" (Sa'i done), subtitle hint ("اضغط عند محاذاة الحجر الأسود" etc.). Ignore taps within 1.5 s of the previous one (debounce against accidental double-tap in a crowd).
- **Session model**: `{mode, currentLap 1..7, done, startedAt, lapTimestamps[]}` persisted on every change. Restoring the app returns to the same lap.
- Screen reader: announce "تم تسجيل الشوط ٣، الشوط الحالي ٤" after each action.

## 3 · Quran Reader — `Quran.dc.html` [`/quran/:surah?ayah=`]

- Background `bgReader`. Header: back · "سورة الكهف" (21/800) + "مكية · ١١٠ آيات · صفحة ٢٩٣" · bookmark button (toggles bookmark on the top visible ayah).
- Toolbar: font size control (A− · current size · A+, 6 steps 24→42, persisted) and translation toggle "En الترجمة" (filled accent when on).
- Body: single column, padding 22. Basmala centered 26 sp (not for At-Tawbah; for Al-Fatihah it is ayah 1). Each ayah: Uthmani text right-aligned, line-height 2.05, followed inline by a 32 px circular number emblem (1.5 stroke `#C9C7C0`, accent when its sheet is open). When translation is on, English (LTR, serif 16, inkBody) under each ayah. Under each ayah a text button "التفسير والترجمة ⌄" (48 tall) opens the tafsir sheet. Divider `#ECEBE7` between ayahs.
- Tafsir sheet: title "الآية ٣ · سورة الكهف", ayah text on `bgReader` box, "معنى الآية" (accent label) + tafsir text 18/1.75 + source line, "الترجمة الإنجليزية" + translation.
- Save last-read (surah, ayah, page) when the user stops scrolling for 2 s and on exit.
- Long verses wrap naturally; use `SelectableText.rich` disabled (no accidental selection) but long-press opens a copy/share menu.

## 4 · Quran Index & Search — `QuranIndex.dc.html` [`/quran`]

- Top bar: back · "المصحف الشريف".
- Search field: 52 tall, white, radius 16, search icon, placeholder "ابحث باسم السورة أو رقمها أو نص الآية", clear button appears when non-empty. Filters instantly (debounce 150 ms) by Arabic name (normalize: strip tashkeel, unify أ/إ/آ→ا, ة→ه, ى→ي), transliteration (case-insensitive), or number (Arabic or Latin digits). When the query is non-empty, show an accent-tint row "البحث في نص الآيات عن «…»" that opens a full-text ayah search results list.
- Tabs (`SeenSegmented`): السور · الأجزاء · الإشارات.
- Last-read card (hidden while searching): bookmark tile, "آخر قراءة", "سورة الكهف · الآية ٣", "صفحة ٢٩٣ · الجزء ١٥", accent button "متابعة" → reader.
- List (inside one card, dividers between rows, 76 min height): `OctagonBadge` number · Arabic name 19/800 + transliteration 14 muted (LTR) · line 2: Makki cube icon or Madani dome icon + "مكية · ١١٠ آية" · trailing column "صفحة" 12 + page 17/800. The last-read surah's badge is accent.
- Juz rows: "الجزء ٢" / "يبدأ من البقرة · الآية ١٤٢" / page. Bookmark rows: title / "البقرة · الآية ٢٥٥" / page; swipe to delete with undo snackbar.
- Empty state: "لا توجد نتائج مطابقة في هذه القائمة".
- Bottom nav with المصحف active.

## 5 · Prayer Times & Adhan — `Prayer.dc.html` [`/prayer`]

- Top bar: back · "مواقيت الصلاة" + "مكة المكرمة · تقويم أم القرى" · settings (calculation method, madhab for Asr, adhan voice, pre-alert minutes).
- Segmented: اليوم | الشهر. Date navigator: chevrons 48 + "السبت ١٤ ربيع الآخر" / "٣ أكتوبر ٢٠٢٦" (month view: "ربيع الآخر ١٤٤٨").
- **Day view — Daily Horizon card**: 342×120 canvas. Dotted night baseline; daylight arc from Sunrise to Maghrib peaking at Dhuhr (quadratic curve); elapsed part of the arc in accent; sun marker (7 px accent dot in 14 px tint halo) at *now*, moving in real time. Markers for الفجر، الشروق، الظهر، العصر، المغرب، العشاء، منتصف الليل positioned by time (time flows right→left, RTL). Each marker is a 40 px invisible tap target; tapping selects it (dot grows 12→16, fills accent) and the caption pill below shows "العصر · ٣:٣٧ م  بعد ٣ س ٥٧ د". Past markers use accentMid.
- **Prayer list card**: 7 rows (68 tall): name (18/700; next prayer = accent 800 with solid accent "بعد ٣٥ د" badge; past = muted), sub-line = alert mode text ("أذان كامل / اهتزاز فقط / صامت"; sunrise & midnight prefixed "تذكير ·"; midnight sub also shows "الثلث الأخير للقيام ١:٢٠ ص"), time 20/800, 48 alert button cycling sound → vibrate → silent (icons bell / phone-vibrate / bell-slash). The next prayer row has `accentTint` background. Footer hint "اضغط زر التنبيه للتبديل بين: أذان · اهتزاز · صامت".
- **Month view**: table card, 7 columns (اليوم، الفجر، الشروق، الظهر، العصر، المغرب، العشاء). Day cell: Hijri day 17/800 + Gregorian 12 muted. Today row tinted with accent day number; zebra `#FAFAFB`. Vertical scroll; auto-scroll to today.
- Data: `adhan` with Umm al-Qura; midnight = Maghrib + (Fajr_next − Maghrib)/2; last third = Maghrib + 2/3 of the night. Recompute at midnight and on location change. Schedule `flutter_local_notifications` for each prayer per its mode.

## 6 · Qibla Compass — `Qibla.dc.html` [`/qibla`]

- Top bar: back · "اتجاه القبلة".
- Status pill (48 tall, 18/800): searching = accent tint + rotate icon "استدر يمينًا ١٢°"/"استدر يسارًا ١٢°"; locked = sage tint + check "أنت تواجه القبلة".
- Fixed pointer (ink triangle, sage when locked) above a 300 px dial. The dial (white, 3 px ring `#E2E3E6`, sage when locked) rotates by −heading: 72 ticks every 5° (major/30° 16 long 3 wide ink, 10° 11 long, minor 7 long `#A3A5AA`), cardinal letters ش (accent) ق ج غ kept upright, `KaabaGlyph` placed at the Qibla bearing and kept upright. Center disk 156 px (`bg`): "زاوية القبلة", bearing 46/800 "٢٩٣°", "اتجاهك ٢٧٥°".
- Lock: enter when |diff| ≤ 2°, exit when > 4° (hysteresis, no flicker). On enter: sage pulse ring (see motion) + haptic pattern once.
- Cards: "المسافة إلى مكة" (haversine from device to 21.4225 N, 39.8262 E, formatted "٨,٣٢٥ كم"), "دقة البوصلة" (ممتازة/جيدة/ضعيفة from `flutter_compass` accuracy, 3 bars sage/amber/accent). Kaaba coordinates card "٢١٫٤٢٢٥° ش · ٣٩٫٨٢٦٢° ق" with "معايرة" button → calibration sheet (figure-8 animation + instructions). Footer tip about metal/electronics.
- No sensor → show static bearing + instruction to use the sun/map; permission denied → explain and offer Settings.

## 7 · Duas & Dhikr Library — `Duas.dc.html` [`/duas`]

- Top bar: back · "الأدعية والأذكار" · tasbeeh shortcut icon → Tasbeeh.
- Chips: الكل · العمرة والحج · أدعية السفر · أذكار الصباح والمساء · جوامع الدعاء (filters list; persist last chip).
- Dua card (expandable, one open at a time): header button = title 18/800 + source tag pill (book icon + "صحيح مسلم") + category text + 32 px chevron. Text below in Amiri 22 clamped to 2 lines when collapsed, 25 full when expanded. Expanded adds: usage note, audio row (52 accent play/pause, progress bar 6 px, elapsed/total), toolbar of three 52-tall buttons: مشاركة (share_plus, text + source) · نسخ (clipboard; label becomes "تم النسخ" for 1.6 s) · حفظ/محفوظ (favourite toggle, fills accent tint). Open card border = accentMid.
- Only one audio plays at a time app-wide (`AudioService` singleton).

## 8 · Digital Tasbeeh — `Tasbeeh.dc.html` [`/tasbeeh`]

- Full-screen, no bottom nav, screen kept awake. Top bar: close (X) · "المسبحة" · outlined "تصفير" (confirm if count > 0).
- Dhikr selector (64 tall card button): "الذكر الحالي" + dhikr 21/800 + chevron → bottom sheet list of 8 adhkar (56 rows, check on selected). Changing dhikr resets the current count.
- Target segmented: ٣٣ · ١٠٠ · مفتوح.
- **Tap surface**: the whole central card (flex-grow, radius 32) is one button. 272 px `ProgressRing` + count 96/800 + "/ ١٠٠" (or "بلا حد"). Hint pill "اضغط في أي مكان للعدّ". On reaching the target: ring + surface turn sage, hint "اكتملت الدورة — اضغط للبدء من جديد", rounds +1; next tap starts at 1. Open mode: ring shows progress within each 100.
- Stats row: "الدورات المكتملة", "مجموع اليوم" (per dhikr per day, persisted; resets at local midnight).
- Volume buttons (Android) count as taps when enabled in settings (optional, later).
