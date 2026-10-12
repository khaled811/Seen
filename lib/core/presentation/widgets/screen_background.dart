import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';

/// Figma screen backdrop: white page with the soft violet wash
/// ([SeenBrand.gradientScreen]) fading out over the top [washHeight] px.
class SeenScreenBackground extends StatelessWidget {
  const SeenScreenBackground({super.key, required this.child, this.washHeight = 340});

  final Widget child;
  final double washHeight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: washHeight,
          child: const DecoratedBox(decoration: BoxDecoration(gradient: SeenBrand.gradientScreen)),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
