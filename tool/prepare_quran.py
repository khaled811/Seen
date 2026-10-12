"""Builds assets/data/quran.json from the Tanzil Uthmani text.

Usage:
    python tool/prepare_quran.py [path/to/raw.json]

Without an argument the raw corpus is downloaded from
https://api.alquran.cloud/v1/quran/quran-uthmani (a mirror of the Tanzil
"Uthmani" text, which docs/spiritual_feature/05-content.md names as the
approved alternative to the QPC text).

The Quranic text is copied byte-for-byte from the source: this script only
re-shapes the JSON and verifies it. It never edits, normalises or "fixes" a
single character of an ayah.

Verification (the script exits non-zero and writes nothing if any fails):
  * 114 surahs numbered 1..114, 6236 ayahs in total
  * every surah's ayah list matches its declared length and is numbered 1..n
  * global ayah numbers run 1..6236 without gaps
  * mushaf pages (Madinah, 604 pages) are 1..604 and never decrease
  * juz is 1..30 and never decreases
  * no empty ayah text
Also prints a SHA-256 of the output for the credits/audit trail.
"""
import hashlib
import json
import sys
import urllib.request
from pathlib import Path

SOURCE_URL = "https://api.alquran.cloud/v1/quran/quran-uthmani"
OUT = Path(__file__).resolve().parent.parent / "assets" / "data" / "quran.json"

EXPECTED_SURAHS = 114
EXPECTED_AYAHS = 6236
EXPECTED_PAGES = 604
EXPECTED_JUZ = 30


def load_raw(arg):
    if arg:
        return json.loads(Path(arg).read_text(encoding="utf-8"))
    with urllib.request.urlopen(SOURCE_URL, timeout=120) as r:
        return json.loads(r.read().decode("utf-8"))


def build(raw):
    surahs = []
    for s in raw["data"]["surahs"]:
        surahs.append(
            {
                "number": s["number"],
                "name": s["name"],
                "englishName": s["englishName"],
                "englishNameTranslation": s["englishNameTranslation"],
                "revelationType": s["revelationType"],
                "numberOfAyahs": len(s["ayahs"]),
                "ayahs": [
                    {
                        "n": a["numberInSurah"],
                        "g": a["number"],
                        "text": a["text"],
                        "page": a["page"],
                        "juz": a["juz"],
                        "hizbQuarter": a["hizbQuarter"],
                        **({"sajda": True} if a.get("sajda") else {}),
                    }
                    for a in s["ayahs"]
                ],
            }
        )
    return {
        "edition": "quran-uthmani",
        "source": SOURCE_URL,
        "license": (
            "Tanzil Quran Text (Uthmani), (c) Tanzil Project, "
            "CC BY 3.0 - https://tanzil.net/docs/text_license. "
            "The text must not be modified; keep this notice."
        ),
        "surahs": surahs,
    }


def verify(data):
    errors = []
    surahs = data["surahs"]
    if len(surahs) != EXPECTED_SURAHS:
        errors.append(f"expected {EXPECTED_SURAHS} surahs, got {len(surahs)}")
    total = 0
    last_page = 0
    last_juz = 0
    next_global = 1
    for i, s in enumerate(surahs, start=1):
        if s["number"] != i:
            errors.append(f"surah #{i} has number {s['number']}")
        if s["revelationType"] not in ("Meccan", "Medinan"):
            errors.append(f"surah {i}: bad revelationType {s['revelationType']}")
        if s["numberOfAyahs"] != len(s["ayahs"]):
            errors.append(f"surah {i}: count mismatch")
        for j, a in enumerate(s["ayahs"], start=1):
            total += 1
            if a["n"] != j:
                errors.append(f"surah {i}: ayah {j} numbered {a['n']}")
            if a["g"] != next_global:
                errors.append(f"surah {i}:{j}: global number {a['g']} != {next_global}")
            next_global += 1
            if not a["text"].strip():
                errors.append(f"surah {i}:{j}: empty text")
            if a["page"] < last_page:
                errors.append(f"surah {i}:{j}: page goes backwards")
            if a["juz"] < last_juz:
                errors.append(f"surah {i}:{j}: juz goes backwards")
            last_page, last_juz = a["page"], a["juz"]
    if total != EXPECTED_AYAHS:
        errors.append(f"expected {EXPECTED_AYAHS} ayahs, got {total}")
    if last_page != EXPECTED_PAGES:
        errors.append(f"last page {last_page} != {EXPECTED_PAGES}")
    if last_juz != EXPECTED_JUZ:
        errors.append(f"last juz {last_juz} != {EXPECTED_JUZ}")
    pages = {a["page"] for s in surahs for a in s["ayahs"]}
    if pages != set(range(1, EXPECTED_PAGES + 1)):
        errors.append("some mushaf pages have no ayah")
    return errors, total


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    raw = load_raw(sys.argv[1] if len(sys.argv) > 1 else None)
    data = build(raw)
    errors, total = verify(data)
    if errors:
        print("VERIFICATION FAILED:")
        for e in errors[:30]:
            print(" -", e)
        sys.exit(1)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    payload = json.dumps(data, ensure_ascii=False, separators=(",", ":"))
    OUT.write_text(payload, encoding="utf-8")
    digest = hashlib.sha256(payload.encode("utf-8")).hexdigest()
    print(
        f"OK: {len(data['surahs'])} surahs, {total} ayahs, "
        f"{EXPECTED_PAGES} pages, {EXPECTED_JUZ} juz"
    )
    print(f"wrote {OUT} ({len(payload.encode('utf-8')) / 1024:.0f} KiB)")
    print(f"sha256 {digest}")


if __name__ == "__main__":
    main()
