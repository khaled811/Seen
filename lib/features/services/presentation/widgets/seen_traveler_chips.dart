// TravelerChips — horizontal traveler chips + "Add traveler" (dashed).
// Active = accent; done = sage check; error = terracotta "!". Auto-scrolls
// to the active chip.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';

enum SeenTravelerState { empty, done, error }

class SeenTravelerChipData {
  const SeenTravelerChipData({this.label, this.state = SeenTravelerState.empty});

  final String? label;
  final SeenTravelerState state;
}

class SeenTravelerChips extends StatefulWidget {
  const SeenTravelerChips({
    super.key,
    required this.travelers,
    required this.activeIndex,
    required this.onSelected,
    this.onAdd,
    this.padding = SeenSpace.gutter,
  });

  final List<SeenTravelerChipData> travelers;
  final int activeIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onAdd;

  /// Lets the row bleed to the screen edge while aligning with the gutter.
  final EdgeInsetsGeometry padding;

  @override
  State<SeenTravelerChips> createState() => _SeenTravelerChipsState();
}

class _SeenTravelerChipsState extends State<SeenTravelerChips> {
  final _keys = <int, GlobalKey>{};

  @override
  void didUpdateWidget(covariant SeenTravelerChips oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[widget.activeIndex]?.currentContext;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, alignment: .5, duration: const Duration(milliseconds: 200));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final s = SeenStrings.of(context);
    final text = Theme.of(context).textTheme;

    Widget chip(int i) {
      final d = widget.travelers[i];
      final active = i == widget.activeIndex;
      final (Color nBg, Color nFg) = switch (d.state) {
        _ when active => (c.accent, c.onPrimary),
        SeenTravelerState.done => (c.successBg, c.successFg),
        SeenTravelerState.error => (c.dangerBg, c.dangerFg),
        SeenTravelerState.empty => (c.surfaceSunken, c.inkSecondary),
      };
      final Widget number = switch (d.state) {
        SeenTravelerState.done when !active => SeenCheckGlyph(size: 12, color: nFg),
        SeenTravelerState.error when !active =>
          Text('!', style: text.labelSmall!.copyWith(color: nFg, fontWeight: FontWeight.w700)),
        _ => Text('${i + 1}', style: text.labelSmall!.copyWith(color: nFg, fontWeight: FontWeight.w600)),
      };
      return Semantics(
        selected: active,
        button: true,
        child: Material(
          key: _keys.putIfAbsent(i, GlobalKey.new),
          color: active ? c.accentSoft : c.card,
          shape: StadiumBorder(side: BorderSide(color: active ? c.accentInk : c.borderStrong)),
          child: InkWell(
            onTap: () => widget.onSelected(i),
            customBorder: const StadiumBorder(),
            child: Container(
              height: 40,
              padding: const EdgeInsetsDirectional.only(start: 10, end: 14),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: nBg, shape: BoxShape.circle),
                  child: number,
                ),
                const SizedBox(width: 6),
                Text(d.label ?? s.traveler(i + 1),
                    style: seenStyle(13, 20, active ? FontWeight.w600 : FontWeight.w500, active ? c.accentInk : c.ink)),
              ]),
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      child: Row(
        children: [
          for (var i = 0; i < widget.travelers.length; i++) ...[chip(i), const SizedBox(width: SeenSpace.s2)],
          if (widget.onAdd != null)
            CustomPaint(
              painter: _DashedStadiumPainter(color: c.borderStrong),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: widget.onAdd,
                  customBorder: const StadiumBorder(),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(SeenIcons.plus, size: 16, color: c.primaryInk),
                      const SizedBox(width: 6),
                      Text(s.addTraveler, style: seenStyle(13, 20, FontWeight.w500, c.primaryInk)),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DashedStadiumPainter extends CustomPainter {
  _DashedStadiumPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      (Offset.zero & size).deflate(.5),
      Radius.circular(size.height / 2),
    );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedStadiumPainter old) => old.color != color;
}
