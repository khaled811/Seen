import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';
import 'segmented_ring.dart';

/// Linear cousin of [SegmentedRing]: N 8 px bars (done = accent, current =
/// accentMid, future = track) with 6 px gaps. Colour changes tween.
class LapProgressBar extends StatelessWidget {
  const LapProgressBar({
    super.key,
    this.segments = 7,
    required this.completed,
    this.showCurrent = true,
    this.semanticLabel,
  });

  final int segments;
  final int completed;
  final bool showCurrent;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final states = ringSegmentStates(
      segments: segments,
      completed: completed,
      showCurrent: showCurrent,
    );
    final duration = SpiritualMotion.of(context, SpiritualMotion.slow);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          children: [
            for (var i = 0; i < states.length; i++) ...[
              if (i > 0) const SizedBox(width: SpiritualSpace.s6),
              Expanded(
                child: AnimatedContainer(
                  duration: duration,
                  height: 8,
                  decoration: BoxDecoration(
                    color: switch (states[i]) {
                      RingSegment.done => t.accent,
                      RingSegment.current => t.accentMid,
                      RingSegment.future => t.borderControl,
                    },
                    borderRadius: BorderRadius.circular(4),
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
