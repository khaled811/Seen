// The bottom navigation icon hops when its tab is tapped, and stays still with "reduce motion".

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/presentation/widgets/chrome.dart';
import 'package:seen_booking/core/theme/app_theme.dart';

Widget _app({bool reduceMotion = false, required ValueChanged<int> onSelected}) => MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
      home: Scaffold(bottomNavigationBar: SeenBottomNav(selectedIndex: 0, onSelected: onSelected)),
    );

double _maxScale(WidgetTester tester) => tester
    .widgetList<Transform>(find.descendant(of: find.byType(NavigationBar), matching: find.byType(Transform)))
    .map((t) => t.transform.getMaxScaleOnAxis())
    .fold<double>(1, (a, b) => a > b ? a : b);

double _maxTilt(WidgetTester tester) => tester
    .widgetList<Transform>(find.descendant(of: find.byType(NavigationBar), matching: find.byType(Transform)))
    .map((t) => t.transform.entry(0, 1).abs())
    .fold<double>(0, (a, b) => a > b ? a : b);

void main() {
  testWidgets('tapping a tab scales its icon up and lets it settle, and still selects', (tester) async {
    int? picked;
    await tester.pumpWidget(_app(onSelected: (i) => picked = i));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(2));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170)); // the peak of the grow
    expect(_maxScale(tester), greaterThan(1.05));
    expect(_maxTilt(tester), greaterThan(.1), reason: 'the icon leans');
    await tester.pumpAndSettle();
    expect(picked, 2);
    expect(tester.binding.transientCallbackCount, 0, reason: 'the hop ends; nothing keeps ticking');
  });

  testWidgets('with reduce motion the icon does not move', (tester) async {
    await tester.pumpWidget(_app(reduceMotion: true, onSelected: (_) {}));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).at(3));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(_maxScale(tester), lessThanOrEqualTo(1.0 + 1e-6));
  });
}
