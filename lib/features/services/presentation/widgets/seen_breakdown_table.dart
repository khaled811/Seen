// BreakdownTable — price breakdown: label · unit x qty · line total, then a
// total row on surfaceSunken. All figures LTR + tabular; the amount column
// has a fixed width so decimals align.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/chrome.dart' show SeenListGroup;
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenBreakdownRow {
  const SeenBreakdownRow({required this.label, this.caption, required this.unitPrice, required this.quantity});

  final String label;
  final String? caption;
  final num unitPrice;
  final int quantity;

  num get lineTotal => unitPrice * quantity;
}

class SeenBreakdownTable extends StatelessWidget {
  const SeenBreakdownTable({super.key, required this.rows, this.totalLabel});

  final List<SeenBreakdownRow> rows;

  /// Defaults to "Total to hold".
  final String? totalLabel;

  num get total => rows.fold<num>(0, (a, r) => a + r.lineTotal);

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final s = SeenStrings.of(context);
    final text = Theme.of(context).textTheme;
    final num13 = text.bodySmall!.copyWith(color: c.inkSecondary, fontFeatures: SeenFonts.tabular);
    final num14 = seenStyle(14, 22, FontWeight.w600, c.ink).copyWith(fontFeatures: SeenFonts.tabular);

    return SeenListGroup(children: [
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: SeenSpace.s3),
          child: Row(
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(r.label, style: text.bodyMedium),
                  if (r.caption != null) Text(r.caption!, style: text.labelSmall),
                ]),
              ),
              const SizedBox(width: SeenSpace.s3),
              Text('${SeenFormat.money(r.unitPrice)} × ${r.quantity}', textDirection: TextDirection.ltr, style: num13),
              const SizedBox(width: SeenSpace.s3),
              SizedBox(
                width: 80,
                child: Text(SeenFormat.money(r.lineTotal), textDirection: TextDirection.ltr, textAlign: TextAlign.right, style: num14),
              ),
            ],
          ),
        ),
      Container(
        color: c.surfaceSunken,
        padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: SeenSpace.s3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: Text(totalLabel ?? s.totalToHold, style: seenStyle(14, 22, FontWeight.w600, c.ink))),
            Text(SeenFormat.money(total),
                textDirection: TextDirection.ltr, style: seenStyle(20, 28, FontWeight.w600, c.ink).copyWith(fontFeatures: SeenFonts.tabular)),
            const SizedBox(width: 4),
            Text('USD', style: text.labelMedium!.copyWith(color: c.inkMuted)),
          ],
        ),
      ),
    ]);
  }
}
