import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/features/spiritual/presentation/shell/flip_switcher.dart';

class _Counter extends StatefulWidget {
  const _Counter({required this.label});

  final String label;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: () => setState(() => taps++),
        child: Text('${widget.label}:$taps'),
      );
}

Widget _host({
  required bool flipped,
  TextDirection dir = TextDirection.rtl,
  bool reduce = false,
}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Directionality(
          textDirection: dir,
          child: Scaffold(
            body: FlipSwitcher(
              flipped: flipped,
              front: const _Counter(label: 'front'),
              back: const _Counter(label: 'back'),
            ),
          ),
        ),
      ),
    );

Transform _firstTransform(WidgetTester tester) => tester
    .widgetList<Transform>(find.descendant(
      of: find.byType(FlipSwitcher),
      matching: find.byType(Transform),
    ))
    .first;

void main() {
  testWidgets('shows only the front face at rest', (tester) async {
    await tester.pumpWidget(_host(flipped: false));
    expect(find.text('front:0'), findsOneWidget);
    expect(find.text('back:0'), findsNothing);
  });

  testWidgets('starts on the back face without animating when flipped',
      (tester) async {
    await tester.pumpWidget(_host(flipped: true));
    expect(find.text('back:0'), findsOneWidget);
    expect(find.text('front:0'), findsNothing);
  });

  testWidgets('swaps faces at the half-way point of the flip', (tester) async {
    await tester.pumpWidget(_host(flipped: false));
    await tester.pumpWidget(_host(flipped: true));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('front:0'), findsOneWidget, reason: 'first half');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('back:0'), findsOneWidget, reason: 'past half-way');
    expect(find.text('front:0'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('back:0'), findsOneWidget);
  });

  testWidgets('both faces keep their state across flips', (tester) async {
    await tester.pumpWidget(_host(flipped: false));
    await tester.tap(find.text('front:0'));
    await tester.pump();
    expect(find.text('front:1'), findsOneWidget);

    await tester.pumpWidget(_host(flipped: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('back:0'));
    await tester.pump();
    expect(find.text('back:1'), findsOneWidget);

    await tester.pumpWidget(_host(flipped: false));
    await tester.pumpAndSettle();
    expect(find.text('front:1'), findsOneWidget);
    await tester.pumpWidget(_host(flipped: true));
    await tester.pumpAndSettle();
    expect(find.text('back:1'), findsOneWidget);
  });

  testWidgets('applies a perspective Y rotation mid-flip', (tester) async {
    await tester.pumpWidget(_host(flipped: false));
    await tester.pumpWidget(_host(flipped: true));
    await tester.pump(const Duration(milliseconds: 150));
    final m = _firstTransform(tester).transform;
    expect(m.entry(3, 2), isNot(0), reason: 'perspective entry');
    expect(m.entry(0, 2), isNot(0), reason: 'Y-axis rotation');
    await tester.pumpAndSettle();
  });

  testWidgets('rotates the opposite way in LTR', (tester) async {
    Future<double> sample(TextDirection dir) async {
      await tester.pumpWidget(_host(flipped: false, dir: dir));
      await tester.pumpWidget(_host(flipped: true, dir: dir));
      await tester.pump(const Duration(milliseconds: 150));
      final v = _firstTransform(tester).transform.entry(0, 2);
      await tester.pumpAndSettle();
      return v;
    }

    final rtl = await sample(TextDirection.rtl);
    final ltr = await sample(TextDirection.ltr);
    expect(rtl.sign, -ltr.sign);
  });

  testWidgets('reduced motion swaps instantly', (tester) async {
    await tester.pumpWidget(_host(flipped: false, reduce: true));
    await tester.pumpWidget(_host(flipped: true, reduce: true));
    await tester.pump();
    expect(find.text('back:0'), findsOneWidget);
    expect(find.text('front:0'), findsNothing);
  });
}
