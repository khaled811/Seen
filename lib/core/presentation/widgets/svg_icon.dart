import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../foundation/seen_vectors.dart';

/// A bundled single-color SVG glyph (Figma icon set) tinted with [color].
/// Decorative by default: give the parent a label.
class SeenSvgIcon extends StatelessWidget {
  const SeenSvgIcon(this.asset, {super.key, this.size = 22, this.color});

  final String asset;
  final double size;

  /// null keeps the SVG's own colors.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      asset,
      width: size,
      height: size,
      excludeFromSemantics: true,
      colorFilter: color == null ? null : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}

/// The back icon of the Figma header (`Icon/back`): a violet rounded square with a chevron
/// pointing right, the back direction in RTL; mirrored in LTR. Keeps its own colour.
class SeenBackGlyph extends StatelessWidget {
  const SeenBackGlyph({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = SeenSvgIcon(SeenVectors.iconBack, size: size);
    return Directionality.of(context) == TextDirection.rtl ? glyph : Transform.scale(scaleX: -1, child: glyph);
  }
}

/// The tick of the Figma "Icon/check", tinted with [color]: the small "done" mark of
/// checkboxes, steps, chips and valid fields. [size] is the box; the tick fills it.
class SeenCheckGlyph extends StatelessWidget {
  const SeenCheckGlyph({super.key, this.size = 16, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SeenSvgIcon(SeenVectors.iconCheck, size: size, color: color);
}
