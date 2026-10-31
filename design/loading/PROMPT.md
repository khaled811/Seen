# Paste this into Claude Code (from the root of the Flutter project)

```
I want to add our new loading system to the app: the loaders, the loading states (skeletons,
slow/timeout) and the pull-to-refresh "refresher". All of them are drawn from the Seen logo.
This is BEHAVIOUR ONLY. Do not change the design of any existing screen. I have changed a lot of
the UI recently, and the current UI in the code is the source of truth.

Everything is in design/loading/:
- SPEC.md is the full spec: components, timings, colours, which loader goes where, skeleton rules,
  the blocking overlay, the slow/timeout policy, accessibility and the acceptance checklist.
- reference/seen_loader.dart is working reference code for every component (SeenLoader,
  SeenMarkDraw, SeenSkyProgress, SeenWindows, SeenShimmer/SkeletonBox, SeenRefreshBubble,
  SeenRefresh, SeenLoadingGate). Read it, then copy or adapt it into our own structure.
  Don't add it as a package.
- preview/seen-loading-preview.html: open it in a browser to see the real motion and timing.
- screenshots/*.png show each state at 2×. They are drawn on reference mock-ups, NOT on our
  current screens. Use them only for the loader, indicator, banner and overlay. Never use them
  for layout, spacing or content.
- assets/*.svg is the mark traced from the logo (box 120×140).

Hard rules:
1. Don't modify any existing layout, spacing, colour, typography, icon, copy, navigation or widget.
   For every screen you touch, its loaded (non-loading) state must render pixel-identical. Capture
   a golden of the loaded state BEFORE editing, and check it again after.
2. The only visual changes allowed are the ones in SPEC §0.2: skeletons, loaders in busy controls,
   upload progress, the refresher, slow/timeout states, and replacing existing spinners
   (CircularProgressIndicator, CupertinoActivityIndicator, RefreshIndicator, shimmer packages,
   Lottie/GIF loaders) with the Seen components.
3. Build each skeleton from that screen's CURRENT widget tree in our code: same sizes, radii and
   positions; static chrome stays as it is (SPEC §6).
4. Use our existing theme tokens. Only add missing colours from SPEC §2 as named constants in the
   existing theme.
5. Reuse our state management and existing loading/error flags. Don't restructure the data flow.
   Add only the minimum state a screen needs.

How to work:
1. Explore first and make no edits. Search for every current loading pattern:
   CircularProgressIndicator, LinearProgressIndicator, RefreshIndicator, CupertinoActivityIndicator,
   Shimmer, Lottie, isLoading, AsyncValue.loading, ConnectionState.waiting, and any HTTP timeouts.
   Then send me:
   (a) the SPEC §5 table filled in for OUR real screens and actions;
   (b) the list of existing loaders you'll replace, with file:line;
   (c) the refresh package we use, if any, and how you'll adapt SeenRefresh to it;
   (d) your file plan.
   Wait for my OK.
2. Add the components (for example under lib/core/widgets/loading/), then wire them in screen by
   screen, following the table.
3. Run `flutter analyze` and the tests. Add the goldens and widget tests from SPEC §12, including
   reduce-motion.
4. Report back with:
   - what changed on each screen;
   - anything you couldn't cover, and why;
   - confirmation that the before/after loaded-state goldens match for every touched screen.
```

Tip: start the session in Plan mode (Shift+Tab) so step 1 happens before any edits.
