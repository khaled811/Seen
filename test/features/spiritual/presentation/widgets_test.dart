import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/presentation/gallery/spiritual_gallery_screen.dart';
import 'package:seen_booking/features/spiritual/presentation/theme/spiritual_theme.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/arabic_number.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/octagon_badge.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/segmented_ring.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/service_tile.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/spiritual_chip.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/spiritual_icon_button.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/spiritual_nav_item.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/spiritual_outlined_button.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/spiritual_primary_button.dart';
import 'package:seen_booking/features/spiritual/presentation/widgets/spiritual_segmented.dart';

Widget _hub(Widget child, {double textScale = 1}) => MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: SpiritualTheme(child: Scaffold(body: Center(child: child))),
      ),
    );

void main() {
  group('ringSegmentStates', () {
    test('marks done, current and future segments', () {
      expect(
        ringSegmentStates(segments: 7, completed: 2),
        [
          RingSegment.done,
          RingSegment.done,
          RingSegment.current,
          RingSegment.future,
          RingSegment.future,
          RingSegment.future,
          RingSegment.future,
        ],
      );
    });

    test('all done when complete, with no current segment', () {
      final s = ringSegmentStates(segments: 7, completed: 7, showCurrent: false);
      expect(s.every((e) => e == RingSegment.done), isTrue);
    });

    test('nothing done at the start', () {
      final s = ringSegmentStates(segments: 7, completed: 0);
      expect(s.first, RingSegment.current);
      expect(s.skip(1).every((e) => e == RingSegment.future), isTrue);
    });
  });

  group('tap targets are at least 48x48', () {
    final cases = <String, Widget Function()>{
      'icon button': () => SpiritualIconButton(
            icon: Icons.close,
            semanticLabel: 'x',
            onPressed: () {},
          ),
      'primary button': () => SpiritualPrimaryButton(label: 'ok', onPressed: () {}),
      'outlined button': () => SpiritualOutlinedButton(label: 'ok', onPressed: () {}),
      'chip': () => SpiritualChip(label: 'ok', selected: false, onTap: () {}),
      'service tile': () => ServiceTile(icon: Icons.home, label: 'ok', onTap: () {}),
      'nav item': () => SpiritualNavItem(
            icon: Icons.home,
            label: 'ok',
            selected: true,
            onTap: () {},
          ),
    };
    cases.forEach((name, build) {
      testWidgets(name, (tester) async {
        await tester.pumpWidget(_hub(build()));
        final size = tester.getSize(find.byType(build().runtimeType));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      });
    });
  });

  testWidgets('segmented control reports taps and selected semantics',
      (tester) async {
    String? picked;
    await tester.pumpWidget(_hub(
      SizedBox(
        width: 300,
        child: SpiritualSegmented<String>(
          options: const [
            SegmentOption(value: 'a', label: 'الطواف'),
            SegmentOption(value: 'b', label: 'السعي'),
          ],
          value: 'a',
          onChanged: (v) => picked = v,
        ),
      ),
    ));
    await tester.tap(find.text('السعي'));
    expect(picked, 'b');
  });

  testWidgets('disabled buttons ignore taps', (tester) async {
    await tester.pumpWidget(
      _hub(const SpiritualPrimaryButton(label: 'معطّل', onPressed: null)),
    );
    await tester.tap(find.text('معطّل'), warnIfMissed: false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ArabicNumber and OctagonBadge render Arabic-Indic digits',
      (tester) async {
    await tester.pumpWidget(_hub(const Column(
      mainAxisSize: MainAxisSize.min,
      children: [ArabicNumber(114), OctagonBadge(number: 18)],
    )));
    expect(find.text('١١٤'), findsOneWidget);
    expect(find.text('١٨'), findsOneWidget);
  });

  group('gallery lays out without overflow', () {
    for (final scale in [1.0, 2.0]) {
      testWidgets('text scale $scale', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              textScaler: TextScaler.linear(scale),
            ),
            child: const SpiritualGalleryScreen(),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
