// Dropzone — Figma "Dropzone": a dashed violet panel with an upload tile,
// a title and a caption. Visual only; the caller decides what a tap does
// (open a picker, or explain that attachments are not available yet).
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';
import 'dashed_border.dart';

class SeenDropzone extends StatelessWidget {
  const SeenDropzone({super.key, required this.title, required this.caption, this.onTap});

  final String title;
  final String caption;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r18);
    return Semantics(
      button: true,
      label: '$title. $caption',
      excludeSemantics: true,
      child: SeenDashedBorder(
        color: SeenBrand.violet60,
        radius: SeenRadius.r18.x,
        child: Material(
          color: SeenBrand.violet05,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.card,
                      borderRadius: const BorderRadius.all(SeenRadius.r14),
                      boxShadow: SeenShadows.card,
                    ),
                    child: SizedBox(width: 44, height: 44, child: Icon(SeenIcons.upload, size: 22, color: c.primary)),
                  ),
                  const SizedBox(height: SeenSpace.s2),
                  Text(title, textAlign: TextAlign.center, style: type.bodyStrong),
                  const SizedBox(height: 2),
                  Text(caption, textAlign: TextAlign.center, style: type.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
