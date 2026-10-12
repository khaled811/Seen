import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';

class SegmentOption<T> {
  const SegmentOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Segmented control: the white active pill slides under the labels.
class SpiritualSegmented<T> extends StatelessWidget {
  const SpiritualSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  }) : assert(options.length >= 2);

  final List<SegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final n = options.length;
    final selected = options.indexWhere((o) => o.value == value);
    final duration = SpiritualMotion.of(context, SpiritualMotion.base);
    return Container(
      padding: const EdgeInsets.all(SpiritualSpace.s4),
      decoration: BoxDecoration(
        color: t.segmentTrack,
        borderRadius: BorderRadius.circular(SpiritualRadius.button),
      ),
      child: SizedBox(
        height: SpiritualSpace.minTap,
        child: Stack(
          children: [
            AnimatedAlign(
              alignment: AlignmentDirectional(
                selected < 0 ? -1 : -1 + 2 * selected / (n - 1),
                0,
              ),
              duration: duration,
              curve: SpiritualMotion.baseCurve,
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: SpiritualTokens.pillShadow,
                  ),
                ),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: i == selected,
                      inMutuallyExclusiveGroup: true,
                      label: options[i].label,
                      child: ExcludeSemantics(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(options[i].value),
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: SpiritualSpace.s8,
                              ),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: AnimatedDefaultTextStyle(
                                  duration: duration,
                                  style: SpiritualType.label.copyWith(
                                    color: i == selected
                                        ? t.inkPrimary
                                        : t.inkBody,
                                    fontWeight: i == selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                  child: Text(options[i].label, maxLines: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
