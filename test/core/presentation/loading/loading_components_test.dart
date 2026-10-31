// Behaviour of the Seen loading system (SPEC section 12): the gate, the wait policy, the
// refresher, the blocking overlay and reduce motion.

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/presentation/widgets/svg_icon.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_blocking_overlay.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_loader.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_loading_gate.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_mark_draw.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_refresh.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_shimmer.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_wait_policy.dart';
import 'package:seen_booking/core/presentation/widgets/loading/seen_windows.dart';
import 'package:seen_booking/core/theme/app_theme.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
        child: child!,
      ),
      home: Scaffold(body: home),
    );

class _GateHost extends StatefulWidget {
  const _GateHost();

  @override
  State<_GateHost> createState() => _GateHostState();
}

class _GateHostState extends State<_GateHost> {
  bool loading = false;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          TextButton(onPressed: () => setState(() => loading = !loading), child: const Text('toggle')),
          Expanded(
            child: SeenLoadingGate(
              isLoading: loading,
              loading: const Text('SKELETON'),
              child: const Text('CONTENT'),
            ),
          ),
        ],
      );
}

void main() {
  group('SeenLoadingGate', () {
    testWidgets('shows nothing before 300 ms, then the loader, and keeps it at least 500 ms', (tester) async {
      await tester.pumpWidget(_app(const _GateHost()));
      expect(find.text('CONTENT'), findsOneWidget);

      await tester.tap(find.text('toggle')); // loading starts
      await tester.pump();
      expect(find.text('SKELETON'), findsNothing);
      expect(find.text('CONTENT'), findsNothing);

      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('SKELETON'), findsNothing);
      await tester.pump(const Duration(milliseconds: 60)); // 310 ms
      expect(find.text('SKELETON'), findsOneWidget);

      await tester.tap(find.text('toggle')); // answer arrives right away
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('SKELETON'), findsOneWidget, reason: 'kept for the minimum visible time');
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('SKELETON'), findsNothing);
      expect(find.text('CONTENT'), findsOneWidget);
    });

    testWidgets('a fast answer never flashes the skeleton', (tester) async {
      await tester.pumpWidget(_app(const _GateHost()));
      await tester.tap(find.text('toggle'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('toggle'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('SKELETON'), findsNothing);
      expect(find.text('CONTENT'), findsOneWidget);
    });
  });

  group('SeenWaitPolicy', () {
    Widget policy({VoidCallback? onRetry, VoidCallback? onCancel}) => _app(SeenWaitPolicy.loading(
          loading: const Text('SKELETON'),
          onRetry: onRetry ?? () {},
          onCancel: onCancel,
        ));

    testWidgets('slow banner at 10 s, timeout card at 30 s, retry restarts the clock', (tester) async {
      var retries = 0;
      await tester.pumpWidget(policy(onRetry: () => retries++));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('SKELETON'), findsOneWidget);
      expect(find.byType(SeenSlowBanner), findsNothing);

      await tester.pump(const Duration(seconds: 10));
      expect(find.byType(SeenSlowBanner), findsOneWidget);
      expect(find.text('SKELETON'), findsOneWidget, reason: 'the skeleton keeps running under the banner');
      expect(find.textContaining('الاتصال بطيء'), findsOneWidget);

      await tester.pump(const Duration(seconds: 20));
      expect(find.byType(SeenTimeoutState), findsOneWidget);
      expect(find.text('SKELETON'), findsNothing);
      expect(find.text('ERR_TIMEOUT'), findsOneWidget);

      await tester.tap(find.text('إعادة المحاولة'));
      await tester.pump();
      expect(retries, 1);
      expect(find.byType(SeenTimeoutState), findsNothing);
      // The next wait starts from zero.
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(SeenSlowBanner), findsNothing);
      // Leave the tree so no timer is pending.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('cancel on the slow banner goes to the timeout card', (tester) async {
      var cancelled = 0;
      await tester.pumpWidget(policy(onCancel: () => cancelled++));
      await tester.pump(const Duration(seconds: 11));
      await tester.tap(find.text('إلغاء'));
      await tester.pump();
      expect(cancelled, 1);
      expect(find.byType(SeenTimeoutState), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('SeenRefresh', () {
    testWidgets('keeps the old list visible while loading, and refreshes once', (tester) async {
      var calls = 0;
      var done = false;
      await tester.pumpWidget(_app(SeenRefresh(
        onRefresh: () async {
          calls++;
          await Future<void>.delayed(const Duration(seconds: 1));
          done = true;
        },
        child: ListView(children: [for (var i = 0; i < 20; i++) SizedBox(height: 60, child: Text('row $i'))]),
      )));
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 400));
      expect(calls, 1);
      expect(done, isFalse);
      expect(find.text('row 0'), findsOneWidget, reason: 'the old data stays while loading');
      expect(find.text('جاري التحديث…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      expect(done, isTrue);
      expect(find.text('row 0'), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('the bubble shows each stage', (tester) async {
      for (final stage in SeenRefreshStage.values) {
        await tester.pumpWidget(_app(Center(child: SeenRefreshBubble(stage: stage, pull: .5))));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.byType(SeenRefreshBubble), findsOneWidget);
        expect(find.byType(SeenCheckGlyph), stage == SeenRefreshStage.done ? findsOneWidget : findsNothing);
      }
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('SeenBlockingOverlay', () {
    testWidgets('while visible it blocks taps and the back button; when hidden it does neither', (tester) async {
      var taps = 0;
      Widget host(bool visible) => _app(SeenBlockingOverlay(
            visible: visible,
            title: 'جاري الإرسال…',
            child: Center(child: TextButton(onPressed: () => taps++, child: const Text('under'))),
          ));
      await tester.pumpWidget(host(false));
      await tester.tap(find.text('under'));
      expect(taps, 1);
      expect(tester.widget<PopScope>(find.byType(PopScope).first).canPop, isTrue);

      await tester.pumpWidget(host(true));
      await tester.pump();
      expect(find.text('جاري الإرسال…'), findsOneWidget);
      expect(find.textContaining('لا تغلق التطبيق'), findsOneWidget);
      await tester.tap(find.text('under'), warnIfMissed: false);
      expect(taps, 1, reason: 'the scrim swallows taps');
      expect(tester.widget<PopScope>(find.byType(PopScope).first).canPop, isFalse);

      await tester.pumpWidget(host(false));
      await tester.pump();
      expect(find.text('جاري الإرسال…'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('with a known progress it shows the percentage', (tester) async {
      await tester.pumpWidget(_app(const SeenBlockingOverlay(
        visible: true,
        title: 'جاري الرفع',
        progress: .58,
        child: SizedBox(),
      )));
      await tester.pump();
      expect(find.textContaining('٥٨%'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('reduce motion', () {
    testWidgets('the trace slows to 2600 ms; draw, windows and shimmer stop', (tester) async {
      await tester.pumpWidget(_app(
        const Column(children: [
          SeenLoader(size: 24),
          SeenMarkDraw(height: 60),
          SeenWindows(),
          SeenShimmer(child: SkeletonBox(height: 10)),
        ]),
        reduceMotion: true,
      ));
      // Only the trace keeps ticking (slowed): everything else is still.
      expect(tester.binding.transientCallbackCount, 1);
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets('with motion allowed every loop ticks', (tester) async {
      await tester.pumpWidget(_app(const Column(children: [
        SeenLoader(size: 24),
        SeenMarkDraw(height: 60),
        SeenWindows(),
        SeenShimmer(child: SkeletonBox(height: 10)),
      ])));
      expect(tester.binding.transientCallbackCount, 4);
      await tester.pumpWidget(const SizedBox());
      expect(tester.binding.transientCallbackCount, 0);
    });
  });
}
