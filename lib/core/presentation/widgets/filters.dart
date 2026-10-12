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

  /// Count in the danger color (e.g. "Action required 3").
  final bool alert;
}

/// medium = Figma filter chip (36px, 13/20 label). small = compact variant
/// (28px, 12/20 label, matching the Figma status-chip S height); Figma does
/// not specify a small filter chip, so its metrics are derived, not exported.
enum SeenSegmentChipSize { small, medium }

/// Single-select filter chips with optional counts. Selected = CTA gradient +
/// on-brand text; unselected = card fill with a 1px line.
/// Sticks under the header while the list scrolls (wrap in a pinned sliver).
class SeenSegmentChips extends StatelessWidget {
  const SeenSegmentChips({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = SeenSpace.gutter,
    this.size = SeenSegmentChipSize.medium,
  });

  final List<SeenSegment> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;
  final SeenSegmentChipSize size;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final small = size == SeenSegmentChipSize.small;
    final height = small ? 28.0 : 36.0;
    final hPad = small ? 10.0 : 12.0;
    const shape = BorderRadius.all(SeenRadius.full);

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
              final Color countBg = on ? c.onPrimary.withAlpha(0x3D) : (it.alert ? c.dangerBg : c.primarySoft);
              final Color countFg = on ? c.onPrimary : (it.alert ? c.dangerFg : c.primary);
              final labelStyle = (small ? type.chipS : type.label).copyWith(color: on ? c.onPrimary : c.inkSecondary);
              return Semantics(
                selected: on,
                button: true,
                child: Material(
                  type: MaterialType.transparency,
                  child: Ink(
                    decoration: BoxDecoration(
                      gradient: on ? SeenBrand.gradientCta : null,
                      color: on ? null : c.card,
                      borderRadius: shape,
                      border: on ? null : Border.all(color: c.border),
                    ),
                    child: InkWell(
                      onTap: () => onSelected(i),
                      borderRadius: shape,
                      child: Container(
                        height: height,
                        padding: EdgeInsetsDirectional.symmetric(horizontal: hPad),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(it.label, style: labelStyle),
                          if (it.count != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(color: countBg, borderRadius: shape),
                              child: Text('${it.count}',
                                  textAlign: TextAlign.center,
                                  style: type.caption.copyWith(color: countFg, fontFeatures: SeenFonts.tabular)),
                            ),
                          ],
                        ]),
                      ),
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
