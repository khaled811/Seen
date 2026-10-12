import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seen_booking/core/presentation/foundation/seen_status.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/requests/presentation/widgets/seen_request_card.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: AppTheme.light,
        home: Directionality(textDirection: TextDirection.rtl, child: Material(child: child)),
      );

  testWidgets('tapping the card invokes onTap once', (tester) async {
    var tapCount = 0;
    await tester.pumpWidget(wrap(SeenRequestCard(
      reference: 'EG-NS-2026-004718',
      service: 'Service',
      travelers: 1,
      date: '24/09/2026',
      status: SeenStatus.review,
      onTap: () => tapCount++,
    )));

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();

    expect(tapCount, 1);
  });

  testWidgets('with no onTap, the card renders but is not tappable', (tester) async {
    await tester.pumpWidget(wrap(const SeenRequestCard(
      reference: 'EG-NS-2026-004718',
      service: 'Service',
      travelers: 1,
      date: '24/09/2026',
      status: SeenStatus.completed,
    )));

    final inkWell = tester.widget<InkWell>(find.byType(InkWell));
    expect(inkWell.onTap, isNull);
  });
}
