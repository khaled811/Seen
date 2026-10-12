import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
