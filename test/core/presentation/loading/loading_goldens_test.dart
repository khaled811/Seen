// Goldens of the Seen loading components (SPEC section 12). Time is pinned (a fixed pump) so the
// animated ones are deterministic. Update only deliberately, with --update-goldens on this file.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_loader.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_refresh.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_sky_progress.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_windows.dart';
import 'package:seen_booking/core/presentation/widgets/screen_background.dart';
import 'package:seen_booking/core/presentation/widgets/skeleton.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/theme/seen_colors.dart';

Widget _wrap(Widget child, {Color? background}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: Scaffold(backgroundColor: background ?? Colors.white, body: child),
    );

Widget _row(List<Widget> items) => Padding(
      padding: const EdgeInsets.all(24),
      child: Wrap(spacing: 28, runSpacing: 28, crossAxisAlignment: WrapCrossAlignment.center, children: items),
    );

void main() {
  setUpAll(loadAppFonts);

  Future<void> shot(WidgetTester tester, Widget child, String name, {Size size = const Size(390, 300), Color? bg}) async {
    await tester.pumpWidgetBuilder(child, wrapper: (c) => _wrap(c, background: bg), surfaceSize: size);
    // 275 ms into the loops: the trace is a quarter round, the sweep is a third across.
    await tester.pump(const Duration(milliseconds: 275));
    await screenMatchesGolden(tester, name, customPump: (t) => t.pump(Duration.zero));
  }

  testGoldens('SeenLoader 18, 24, 40, 96 and on-dark 18', (tester) async {
    await shot(
      tester,
      _row([
        const SeenLoader(size: 18),
        const SeenLoader(size: 24),
        const SeenLoader(size: 40),
        const SeenLoader(size: 96),
        const DecoratedBox(
          decoration: BoxDecoration(gradient: SeenBrand.gradientCta, borderRadius: BorderRadius.all(Radius.circular(16))),
          child: Padding(padding: EdgeInsets.all(18), child: SeenLoader.onDark(size: 18)),
        ),
      ]),
      'loader',
      size: const Size(390, 260),
    );
  });

  testGoldens('SeenSkyProgress 0, 58 %, 100 %', (tester) async {
    await shot(
      tester,
      _row([
        const SeenSkyProgress(value: 0, height: 92),
        const SeenSkyProgress(value: .58, height: 92),
        const SeenSkyProgress(value: 1, height: 92),
      ]),
      'sky_progress',
      size: const Size(390, 180),
    );
  });

  testGoldens('SeenWindows 8', (tester) async {
    await shot(tester, _row([const SeenWindows(size: 8), const SeenWindows(size: 14)]), 'windows', size: const Size(390, 90));
  });

  testGoldens('SeenRefreshBubble: pull 30 %, 70 %, 92 %, armed, loading, done', (tester) async {
    await shot(
      tester,
      _row([
        const SeenRefreshBubble(stage: SeenRefreshStage.pull, pull: .3),
        const SeenRefreshBubble(stage: SeenRefreshStage.pull, pull: .7),
        const SeenRefreshBubble(stage: SeenRefreshStage.pull, pull: .92),
        const SeenRefreshBubble(stage: SeenRefreshStage.armed),
        const SeenRefreshBubble(stage: SeenRefreshStage.loading),
        const SeenRefreshBubble(stage: SeenRefreshStage.done),
      ]),
      'refresh_bubble',
      size: const Size(390, 150),
      bg: SeenBrand.violet05,
    );
  });

  // The skeletons of the screens' own parts, at the phone size (the screens keep their static
  // chrome; these are the regions that swap while loading).
  testGoldens('Home skeleton (balance card + cards) 390 x 844', (tester) async {
    await shot(
      tester,
      const SeenScreenBackground(
        child: SafeArea(
          child: SeenSkeletonGroup(
            child: Padding(
              padding: EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Column(
                children: [
                  SeenBalanceSkeleton(),
                  SizedBox(height: 24),
                  SeenCardSkeleton(),
                  SizedBox(height: 14),
                  SeenCardSkeleton(),
                  SizedBox(height: 14),
                  SeenCardSkeleton(),
                ],
              ),
            ),
          ),
        ),
      ),
      'skeleton_home',
      size: const Size(390, 844),
    );
  });

  testGoldens('Requests skeleton (cards) 390 x 844', (tester) async {
    await shot(
      tester,
      const SeenScreenBackground(
        child: SafeArea(child: SeenCardsSkeleton(count: 4, padding: EdgeInsets.fromLTRB(14, 12, 14, 24))),
      ),
      'skeleton_requests',
      size: const Size(390, 844),
    );
  });
}
