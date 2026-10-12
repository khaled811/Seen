// ServiceCard — selectable service: price per traveler, processing time and
// required documents. Behaves as a radio; selected = 2px accentInk border
// (no layout shift) + filled radio.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/selection.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenServiceCard extends StatelessWidget {
  const SeenServiceCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.pricePerTraveler,
    required this.processing,
    required this.documents,
    this.selected = false,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final num pricePerTraveler;
  final String processing;
  final String documents;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final s = SeenStrings.of(context);
    final text = Theme.of(context).textTheme;

    Widget fact(String label, Widget value, {int flex = 10}) => Expanded(
          flex: flex,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text(label, style: text.labelSmall), value],
          ),
        );

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SeenRadius.md),
          side: BorderSide(color: selected ? c.accentInk : c.border, width: selected ? 2 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.md)),
          child: Padding(
            padding: EdgeInsets.all(selected ? 15 : 16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration:
                          BoxDecoration(color: c.primarySoft, borderRadius: const BorderRadius.all(SeenRadius.sm)),
                      child: Icon(icon, size: 24, color: c.primaryInk),
                    ),
                    const SizedBox(width: SeenSpace.s3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: text.titleMedium),
                          Text(subtitle, style: text.bodySmall!.copyWith(color: c.inkMuted)),
                        ],
                      ),
                    ),
                    SeenRadioDot(selected: selected),
                  ],
                ),
                const SizedBox(height: SeenSpace.s4),
                Divider(height: 1, color: c.border),
                const SizedBox(height: SeenSpace.s3),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    fact(
                      s.pricePerTraveler,
                      Text(SeenFormat.usd(pricePerTraveler),
                          maxLines: 1,
                          style: seenStyle(17, 24, FontWeight.w600, c.ink).copyWith(fontFeatures: SeenFonts.tabular)),
                      flex: 13,
                    ),
                    const SizedBox(width: SeenSpace.s4),
                    fact(s.processing, Text(processing, style: text.bodyMedium)),
                    const SizedBox(width: SeenSpace.s4),
                    fact(s.documents, Text(documents, style: text.bodyMedium)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
