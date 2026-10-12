# 05 · Content & Religious Text

## Rules

1. **Quran text is never typed by hand.** Load it from a verified dataset bundled in `assets/data/quran/`:
   - Preferred: King Fahd Glorious Quran Printing Complex (QPC) Hafs Uthmani text + page/juz mapping (Madinah Mushaf, 604 pages), rendered with the **KFGQPC Uthmanic Script HAFS** font.
   - Alternative: Tanzil "Uthmani" text (keep the Tanzil license notice, no modification).
   - Metadata needed per surah: number, Arabic name, transliteration, Makki/Madani, ayah count, start page. Per ayah: surah, number, page, juz, hizb.
2. **Translation**: Sahih International (English). **Tafsir**: التفسير الميسر (King Fahd Complex). Display the source name under the tafsir in the sheet. Respect each dataset's license; list them on an About/Credits screen.
3. **Duas** live in `assets/data/duas.json` (schema below). Every entry must carry a real source. The strings currently in the mockups (listed below) are a starting set and **must be reviewed by a qualified scholar** before release (`reviewed: false` until signed off; show nothing unreviewed in release builds).
4. The Tawaf screen intentionally does **not** show a "dua for each lap" — there is no authentic lap-specific dua. It shows the reported dua between the Yemeni Corner and the Black Stone; pilgrims may make any dua in the other parts.
5. The mockups' Quran verses (Al-Kahf 1–5), tafsir paraphrases ("[مصدر التفسير المعتمد]") and English lines are placeholders that show the layout. Replace them with dataset content.

## `duas.json` schema

```json
{
  "id": "safar",
  "category": "safar | hajj | adhkar | jawami",
  "title": "دعاء السفر",
  "text": "…",
  "isQuranic": false,
  "source": "صحيح مسلم",
  "note": "يُقال عند ركوب وسيلة السفر.",
  "repeat": 1,
  "audio": "audio/duas/safar.mp3",
  "durationSec": 48,
  "reviewed": false
}
```

## Starting dua set (from the mockups — to be reviewed)

| id | Title | Category | Source |
|---|---|---|---|
| safar | دعاء السفر | أدعية السفر | صحيح مسلم |
| talbiyah | التلبية | العمرة والحج | متفق عليه |
| rukn | بين الركن اليماني والحجر الأسود (رَبَّنَا آتِنَا…) | العمرة والحج | سنن أبي داود (الآية: البقرة ٢٠١) |
| manzil | عند النزول في مكان (أعوذ بكلمات الله التامات…) | أدعية السفر | صحيح مسلم |
| istighfar | سيد الاستغفار | أذكار الصباح والمساء | صحيح البخاري |
| afiyah | سؤال العفو والعافية | جوامع الدعاء | سنن ابن ماجه |
| thabat | يا مقلب القلوب ثبت قلبي على دينك | جوامع الدعاء | سنن الترمذي |
| safa-marwa | لا إله إلا الله وحده لا شريك له… (on Safa & Marwa) | العمرة والحج | صحيح مسلم |

Full texts are in `design/reference/Duas.dc.html` and `Tawaf.dc.html` (inside the `<script>` data). Copy them into `duas.json` verbatim, then send for review.

## Tasbeeh adhkar list

سبحان الله · الحمد لله · الله أكبر · لا إله إلا الله · سبحان الله وبحمده · أستغفر الله · لا حول ولا قوة إلا بالله · اللهم صلِّ على محمد

## Copy conventions

- Arabic-Indic digits everywhere, Arabic comma "،" in prose, "٬" or "," as thousands separator consistently ("٨,٣٢٥ كم" in the mockup).
- Time format 12 h with "ص / م" or a word ("ظهرًا") as in the dashboard.
- Hijri date first, Gregorian second.
- Placeholder data in mockups (city, distance 8,325 km, bearing 293°, prayer times) must come from live services.
