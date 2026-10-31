import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';

/// How the stars behave: tappable, shown as sent and no longer changeable, or just displayed.
enum RatingMode { input, locked, readonly }

/// `md` is the 40 px box with a 32 px star (the rating card); `sm` the 20 px box for lists.
enum RatingSize { md, sm }

/// Five stars for a 1-5 rating (design/gaps SPEC §3.1). They always run left to right (1 on the
/// left), also in Arabic. A screen reader hears one radio group, "3 of 5" for each star, and every
/// star keeps a 44 px tap area in [RatingMode.input].
class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.value,
    required this.groupLabel,
    required this.starLabel,
    this.mode = RatingMode.input,
    this.size = RatingSize.md,
    this.onChanged,
  }) : assert(value >= 0 && value <= 5);

  /// 0 = nothing chosen yet.
  final int value;
  final String groupLabel;
  final String Function(int value) starLabel;
  final RatingMode mode;
  final RatingSize size;

  /// Only used in [RatingMode.input].
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final md = size == RatingSize.md;
    final box = md ? 40.0 : 20.0;
    final star = md ? 32.0 : 16.0;
    final gap = md ? 10.0 : 2.0;
    final locked = mode == RatingMode.locked;
    final onFill = locked ? SeenBrand.violet60 : SeenBrand.violet;
    final offStroke = locked ? SeenBrand.violet40 : SeenBrand.violet60;
    final interactive = mode == RatingMode.input && onChanged != null;
    return Semantics(
      label: groupLabel,
      container: true,
      child: SizedBox(
        height: md ? 44 : 20,
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 5; i++) ...[
                if (i > 1) SizedBox(width: gap),
                Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: i == value,
                  button: interactive,
                  label: starLabel(i),
                  onTap: interactive ? () => onChanged!(i) : null,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: interactive ? () => onChanged!(i) : null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: md ? 2 : 0),
                      child: SizedBox.square(
                        dimension: box,
                        child: Center(
                          child: CustomPaint(
                            size: Size.square(star),
                            painter: _StarPainter(fill: i <= value ? onFill : null, stroke: i <= value ? onFill : offStroke),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.fill, required this.stroke});

  final Color? fill;
  final Color stroke;

  // The points of the 24 x 24 star used in the designs.
  static const _points = <Offset>[
    Offset(12, 3.6), Offset(14.5, 8.8), Offset(20.1, 9.6), Offset(16, 13.5), Offset(17, 19.1), //
    Offset(12, 16.4), Offset(7, 19.1), Offset(8, 13.5), Offset(3.9, 9.6), Offset(9.5, 8.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()..moveTo(_points.first.dx * s, _points.first.dy * s);
    for (final p in _points.skip(1)) {
      path.lineTo(p.dx * s, p.dy * s);
    }
    path.close();
    if (fill != null) {
      canvas.drawPath(path, Paint()..color = fill!);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * s
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.fill != fill || old.stroke != stroke;
}
