// SegmentChips — single-select filter row, domain-agnostic (label/count/alert
// only), reusable across any list screen (requests, tickets, approvals, …).
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';

class SeenSegment {
  const SeenSegment({required this.label, this.count, this.alert = false});

  final String label;
  final int? count;

  /// Count in terracotta (e.g. "Action required 3").
  final bool alert;
}

/// Single-select filter chips with optional counts. Selected = accent fill + onPrimary text.
/// Sticks under the header while the list scrolls (wrap in a pinned sliver).
class SeenSegmentChips extends StatelessWidget {
  const SeenSegmentChips({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = SeenSpace.gutter,
  });

  final List<SeenSegment> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: SeenSpace.s2),
            Builder(builder: (context) {
              final it = items[i];
              final on = i == selectedIndex;
              final Color countBg = on ? c.onPrimary.withAlpha(0x33) : (it.alert ? c.dangerBg : c.surfaceSunken);
              final Color countFg = on ? c.onPrimary : (it.alert ? c.dangerFg : c.inkSecondary);
              return Semantics(
                selected: on,
                button: true,
                child: Material(
                  color: on ? c.accent : c.card,
                  shape: StadiumBorder(side: BorderSide(color: on ? c.accent : c.border)),
                  child: InkWell(
                    onTap: () => onSelected(i),
                    customBorder: const StadiumBorder(),
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(it.label,
                            style: seenStyle(13, 20, on ? FontWeight.w600 : FontWeight.w500, on ? c.onPrimary : c.inkSecondary)),
                        if (it.count != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            constraints: const BoxConstraints(minWidth: 18),
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(color: countBg, borderRadius: const BorderRadius.all(SeenRadius.full)),
                            child: Text('${it.count}',
                                textAlign: TextAlign.center,
                                style: seenStyle(11, 18, FontWeight.w600, countFg).copyWith(fontFeatures: SeenFonts.tabular)),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
