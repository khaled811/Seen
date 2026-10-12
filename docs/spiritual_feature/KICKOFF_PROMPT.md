# Kickoff prompt for Claude Code

Paste this as your first message to Claude Code, run from the folder that contains `CLAUDE.md`, `docs/` and `design/`:

---

Build the "Seen — Spiritual & Manasik Hub" Flutter app described in this folder.

1. Read `CLAUDE.md`, then every file in `docs/` in order, then skim all 8 files in `design/reference/` (they are the approved mockups; use them for exact spacing, sizes, colors and Arabic copy).
2. Propose a short implementation plan that follows `docs/06-build-plan.md` and list any questions or spec conflicts you find. Wait for my OK.
3. Then implement milestone by milestone (M0 → M8). After each milestone: run `flutter analyze` and `flutter test`, fix all issues, commit with a clear message, and give me a 3-line summary before continuing.

Hard rules: native RTL Arabic, tap targets ≥ 48 dp, tokens only (no hard-coded styles), every animation and haptic from `docs/04-motion-haptics.md`, respect reduce-motion, and never type Quranic text by hand — load it from the dataset described in `docs/05-content.md`.

---

Tips:
- For a faster first look, ask it to do M0–M3 first (design system + dashboard + Tawaf) and run it on a device before continuing.
- Put licensed assets you already have (fonts, Quran dataset, adhan/dua audio) in `assets/` before starting, or tell Claude Code where to get them.
