// The Seen mark and the pieces every loader is drawn from. Paths are traced from the logo
// (box 120 x 140): the airplane window plus the two strokes of the letter "س" (tooth + smile).
// All motion is built on `PathMetric.extractPath`. Adapted from design/loading/reference.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../theme/seen_colors.dart';

abstract final class SeenMarkGeometry {
  static const Size box = Size(120, 140);
  static const double windowStroke = 10;
  static const double toothStroke = 9.5;
  static const double smileStroke = 10;

  static final RRect window = RRect.fromRectAndRadius(
      const Rect.fromLTWH(11, 7, 99, 127), const Radius.circular(31));

  /// Inner edge of the window stroke: clips the sky fill.
  static final RRect windowInner = RRect.fromRectAndRadius(
      const Rect.fromLTWH(15.5, 11.5, 90, 118), const Radius.circular(26.5));

  static Path windowPath() => Path()..addRRect(window);

  static Path toothPath() => Path()
    ..moveTo(36.6, 67)
    ..lineTo(45.8, 53.5)
    ..quadraticBezierTo(60.3, 63.9, 80.5, 52);

  static Path smilePath() => Path()
    ..moveTo(24.2, 76.6)
    ..quadraticBezierTo(59, 102.4, 94.7, 76.1);
}

double clamp01(double v) => v < 0 ? 0.0 : (v > 1 ? 1.0 : v);

/// Part of [source] between fractions [from] and [to] of its length. For closed paths the
/// segment may wrap past the end (used by the trace).
Path pathSegment(Path source, double from, double to, {bool wrap = false}) {
  final out = Path();
  if (to <= from) return out;
  for (final metric in source.computeMetrics()) {
    final len = metric.length;
    if (to - from >= 1) {
      out.addPath(metric.extractPath(0, len), Offset.zero);
      continue;
    }
    if (!wrap) {
      out.addPath(metric.extractPath(clamp01(from) * len, clamp01(to) * len),
          Offset.zero);
      continue;
    }
    final a = (from % 1) * len;
    final b = a + (to - from) * len;
    if (b <= len) {
      out.addPath(metric.extractPath(a, b), Offset.zero);
    } else {
      out.addPath(metric.extractPath(a, len), Offset.zero);
      out.addPath(metric.extractPath(0, b - len), Offset.zero);
    }
  }
  return out;
}

/// The colours the loaders need, taken from the app's brand tokens ([SeenBrand]). The
/// on-dark variant is for gradient or dark surfaces (balance card, dark buttons, boot).
@immutable
class SeenLoaderColors {
  const SeenLoaderColors({
    this.ink = SeenBrand.violet,
    this.track = SeenBrand.violet20,
    this.skyTop = SeenBrand.skyTop,
    this.skyBottom = SeenBrand.skyBottom,
    this.windowFill = SeenBrand.violet05,
    this.skeletonBase = SeenBrand.skeletonBase,
    this.skeletonHighlight = SeenBrand.skeletonHighlight,
    this.success = SeenBrand.loaderDone,
  });

  const SeenLoaderColors.onDark()
      : this(
          ink: Colors.white,
          track: SeenBrand.loaderTrackOnDark,
          skeletonBase: SeenBrand.skeletonOnDarkBase,
          skeletonHighlight: SeenBrand.skeletonOnDarkHighlight,
        );

  /// Same palette with another ink (e.g. a loader inside a button of another colour).
  SeenLoaderColors withInk(Color color) => SeenLoaderColors(
        ink: color,
        track: color.withOpacity(.22),
        skyTop: skyTop,
        skyBottom: skyBottom,
        windowFill: windowFill,
        skeletonBase: skeletonBase,
        skeletonHighlight: skeletonHighlight,
        success: success,
      );

  final Color ink,
      track,
      skyTop,
      skyBottom,
      windowFill,
      skeletonBase,
      skeletonHighlight,
      success;

  @override
  bool operator ==(Object other) =>
      other is SeenLoaderColors &&
      other.ink == ink &&
      other.track == track &&
      other.skyTop == skyTop &&
      other.skyBottom == skyBottom &&
      other.windowFill == windowFill &&
      other.skeletonBase == skeletonBase &&
      other.skeletonHighlight == skeletonHighlight &&
      other.success == success;

  @override
  int get hashCode => Object.hash(ink, track, skyTop, skyBottom, windowFill,
      skeletonBase, skeletonHighlight, success);
}

/// "Reduce motion" is on: loops stop or slow down (SPEC section 11).
bool seenReduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// A stroke range (fractions of a path's length).
class SeenSeg {
  const SeenSeg(this.a, this.b);
  final double a, b;
  static const full = SeenSeg(0, 1);
  static const none = SeenSeg(0, 0);
}

Size seenMarkSize(double height) => Size(height * 120 / 140, height);

/// Painter shared by the trace, the draw and the refresher.
class SeenMarkPainter extends CustomPainter {
  SeenMarkPainter({
    required this.ink,
    required this.track,
    this.window = SeenSeg.full,
    this.tooth = SeenSeg.full,
    this.smile = SeenSeg.full,
    this.tracePhase,
    this.showTrack = false,
    this.showGlyph = true,
    this.smileScale = 1,
  });

  final Color ink, track;
  final SeenSeg window, tooth, smile;

  /// When non-null, the window is a running light: tail 34 %, head 14 %.
  final double? tracePhase;
  final bool showTrack, showGlyph;
  final double smileScale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 120, size.height / 140);
    canvas.save();
    canvas.translate((size.width - 120 * s) / 2, (size.height - 140 * s) / 2);
    canvas.scale(s);

    // Strokes are never thinner than 2 physical px at small sizes.
    final minUnits = 2 / s;
    final ws = math.max(SeenMarkGeometry.windowStroke * 1.05, minUnits);
    Paint stroke(Color c, double w, {StrokeCap cap = StrokeCap.butt}) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = cap
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = true
      ..color = c;

    final win = SeenMarkGeometry.windowPath();
    if (showTrack) canvas.drawPath(win, stroke(track, ws));

    final phase = tracePhase;
    if (phase != null) {
      canvas.drawPath(pathSegment(win, phase, phase + .34, wrap: true),
          stroke(ink.withOpacity(ink.opacity * .38), ws, cap: StrokeCap.round));
      canvas.drawPath(pathSegment(win, phase + .20, phase + .34, wrap: true),
          stroke(ink, ws, cap: StrokeCap.round));
    } else {
      canvas.drawPath(pathSegment(win, window.a, window.b), stroke(ink, ws));
    }

    if (showGlyph) {
      final gs = math.max(SeenMarkGeometry.toothStroke, 1.6 / s);
      canvas.drawPath(
          pathSegment(SeenMarkGeometry.toothPath(), tooth.a, tooth.b),
          stroke(ink, gs));
      final smilePath =
          pathSegment(SeenMarkGeometry.smilePath(), smile.a, smile.b);
      final smileStroke =
          stroke(ink, math.max(SeenMarkGeometry.smileStroke, 1.6 / s));
      if (smileScale != 1) {
        canvas.save();
        canvas.translate(59.5, 86);
        canvas.scale(smileScale, 1 + (smileScale - 1) * .6);
        canvas.translate(-59.5, -86);
        canvas.drawPath(smilePath, smileStroke);
        canvas.restore();
      } else {
        canvas.drawPath(smilePath, smileStroke);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(SeenMarkPainter oldDelegate) =>
      oldDelegate.ink != ink ||
      oldDelegate.track != track ||
      oldDelegate.window.a != window.a ||
      oldDelegate.window.b != window.b ||
      oldDelegate.tooth.a != tooth.a ||
      oldDelegate.tooth.b != tooth.b ||
      oldDelegate.smile.a != smile.a ||
      oldDelegate.smile.b != smile.b ||
      oldDelegate.tracePhase != tracePhase ||
      oldDelegate.showTrack != showTrack ||
      oldDelegate.showGlyph != showGlyph ||
      oldDelegate.smileScale != smileScale;
}
