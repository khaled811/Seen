import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';

/// Tiny Kaaba mark: ink square with a thin gold band 6 px from the top.
/// Decorative — excluded from semantics.
class KaabaGlyph extends StatelessWidget {
  const KaabaGlyph({super.key, this.size = 26});

  final double size;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final k = size / 26;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: t.inkPrimary,
            borderRadius: BorderRadius.circular(4 * k),
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: EdgeInsets.only(top: 6 * k),
              child: SizedBox(
                height: 3 * k,
                width: double.infinity,
                child: ColoredBox(color: t.kaabaBand),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
