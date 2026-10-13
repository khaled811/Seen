// Top-up widgets (Figma 12, node 18:619): the three payment-method cards and
// the amount chips.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenMethodCardOption<T> {
  const SeenMethodCardOption({required this.value, required this.iconAsset, required this.label});

  final T value;
  final String iconAsset;
  final String label;
}

/// A row of equal-width method cards. Selected: violet-05 fill, 1.5 px violet
/// border, white icon tile, violet label and a check badge in the top-left.
class SeenMethodCards<T> extends StatelessWidget {
  const SeenMethodCards({super.key, required this.options, required this.value, required this.onChanged});

  final List<SeenMethodCardOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    // IntrinsicHeight lets the cards stretch to the tallest label.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: _MethodCard(
                option: options[i],
                selected: options[i].value == value,
                onTap: () => onChanged(options[i].value),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MethodCard<T> extends StatelessWidget {
  const _MethodCard({required this.option, required this.selected, required this.onTap});

  final SeenMethodCardOption<T> option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r18);
    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: option.label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: radius, boxShadow: selected ? null : SeenShadows.card),
        child: Material(
          color: selected ? SeenBrand.violet05 : c.card,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: selected ? c.primary : c.border, width: selected ? 1.5 : 1),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 8, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected ? c.card : SeenBrand.violet10,
                          borderRadius: const BorderRadius.all(SeenRadius.r14),
                        ),
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: Center(child: SeenSvgIcon(option.iconAsset, size: 22, color: c.primary)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        option.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: t.label.copyWith(color: selected ? c.primary : c.inkSecondary),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Positioned(
                    left: 5,
                    top: 5,
                    child: SvgPicture.asset(SeenVectors.walletCheck, width: 20, height: 20, excludeFromSemantics: true),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Four equal pills (38 px). The pill matching [selected] is violet-10 with a
/// violet border.
class SeenAmountChips extends StatelessWidget {
  const SeenAmountChips({super.key, required this.labels, required this.selectedIndex, required this.onSelected});

  final List<String> labels;

  /// -1 when the typed amount matches no preset.
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: i == selectedIndex,
              label: labels[i],
              excludeSemantics: true,
              child: Material(
                color: i == selectedIndex ? SeenBrand.violet10 : c.card,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: i == selectedIndex ? c.primary : c.border,
                    width: i == selectedIndex ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () => onSelected(i),
                  customBorder: const StadiumBorder(),
                  child: SizedBox(
                    height: 38,
                    child: Center(
                      child: Text(
                        labels[i],
                        textDirection: TextDirection.ltr,
                        style: t.label.copyWith(color: i == selectedIndex ? c.primary : c.inkSecondary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
