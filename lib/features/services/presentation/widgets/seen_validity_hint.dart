// ValidityHint — passport expiry against the 6-month rule. 4px track
// (24-month scale) with a tick at 6 months. < 6 months = danger (and blocks
// "Next"); 6-9 = pending; >= 9 = success.
//
// Presentational only — the actual pass/fail *business rule* stays owned by
// `features/dynamic_forms/domain/validators/passport_validators.dart`
// (Task 05); this widget just visualizes months-remaining, it doesn't
// re-implement or replace that validation.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenValidityHint extends StatelessWidget {
  const SeenValidityHint({super.key, required this.monthsLeft});

  /// Months of validity remaining after [travelDate].
  SeenValidityHint.fromDates({super.key, required DateTime expiry, required DateTime travelDate})
      : monthsLeft = SeenFormat.monthsBetween(travelDate, expiry);

  final int monthsLeft;

  bool get isBlocking => monthsLeft < 6;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final s = SeenStrings.of(context);
    final m = monthsLeft;
    final Color ink = m < 6 ? c.dangerFg : (m < 9 ? c.pendingFg : c.successFg);
    final msg = m < 6 ? s.validityBad : (m < 9 ? s.validityMid(m) : s.validityOk(m));
    final pct = (m / 24).clamp(0.04, 1.0);

    return Padding(
      padding: const EdgeInsets.only(top: SeenSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 10,
            child: LayoutBuilder(builder: (context, box) {
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  PositionedDirectional(
                    start: 0,
                    end: 0,
                    top: 3,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  PositionedDirectional(
                    start: 0,
                    top: 3,
                    width: box.maxWidth * pct,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  PositionedDirectional(
                    start: box.maxWidth * .25, // 6 of 24 months
                    top: 0,
                    child: Container(width: 1, height: 10, color: c.inkMuted),
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 6),
          Row(children: [
            Icon(m < 6 ? SeenIcons.alert : SeenIcons.check, size: 14, color: ink),
            const SizedBox(width: SeenSpace.s1),
            Expanded(child: Text(msg, style: seenStyle(12, 18, FontWeight.w500, ink))),
          ]),
        ],
      ),
    );
  }
}
