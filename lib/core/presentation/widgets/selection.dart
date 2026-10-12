// RadioDot — generic selection indicator, shared across features (wallet's
// method selector and services' service card both use it).
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';

/// 20px radio indicator: 1.5px borderStrong ring, or a 6px accentInk ring when selected.
class SeenRadioDot extends StatelessWidget {
  const SeenRadioDot({super.key, required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? c.accentInk : c.borderStrong, width: selected ? 6 : 1.5),
      ),
    );
  }
}
