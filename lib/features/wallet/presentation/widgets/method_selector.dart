// MethodSelector — radio list of payment methods. Selected row: accentSoft
// fill + accentInk border.
import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/selection.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';

class SeenMethodOption<T> {
  const SeenMethodOption({required this.value, required this.icon, required this.label, required this.caption});

  final T value;
  final IconData icon;
  final String label;

  /// Timing note, e.g. "Posts in 1–4 business hours".
  final String caption;
}

class SeenMethodSelector<T> extends StatelessWidget {
  const SeenMethodSelector({super.key, required this.options, required this.value, required this.onChanged});

  final List<SeenMethodOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        for (var i = 0; i < options.length; i++) ...[
          if (i > 0) const SizedBox(height: SeenSpace.s2),
          Builder(builder: (context) {
            final o = options[i];
            final selected = o.value == value;
            return Semantics(
              inMutuallyExclusiveGroup: true,
              checked: selected,
              button: true,
              child: Material(
                color: selected ? c.accentSoft : c.card,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(SeenRadius.sm),
                  side: BorderSide(color: selected ? c.accentInk : c.border, width: selected ? 2 : 1),
                ),
                child: InkWell(
                  onTap: () => onChanged(o.value),
                  customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.sm)),
                  child: Padding(
                    padding: EdgeInsets.all(selected ? 11 : 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration:
                              BoxDecoration(color: c.primarySoft, borderRadius: const BorderRadius.all(SeenRadius.sm)),
                          child: Icon(o.icon, size: 22, color: c.primaryInk),
                        ),
                        const SizedBox(width: SeenSpace.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(o.label, style: text.bodyMedium),
                              Text(o.caption, style: text.labelSmall),
                            ],
                          ),
                        ),
                        SeenRadioDot(selected: selected),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }
}
