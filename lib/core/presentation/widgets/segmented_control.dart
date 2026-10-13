// SegmentedControl — Figma "Segmented control": a violet-05 track with equal
// width pills; the selected pill is the CTA gradient. Single select.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';

class SeenSegmentedControl extends StatelessWidget {
  const SeenSegmentedControl({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    const shape = BorderRadius.all(SeenRadius.full);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SeenBrand.violet05,
        borderRadius: shape,
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: Semantics(
                  selected: i == selectedIndex,
                  button: true,
                  label: labels[i],
                  excludeSemantics: true,
                  child: Material(
                    type: MaterialType.transparency,
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: i == selectedIndex ? SeenBrand.gradientCta : null,
                        borderRadius: shape,
                      ),
                      child: InkWell(
                        onTap: () => onSelected(i),
                        borderRadius: shape,
                        child: SizedBox(
                          height: 34,
                          child: Center(
                            child: Text(
                              labels[i],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: type.label.copyWith(color: i == selectedIndex ? c.onPrimary : c.inkSecondary),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
