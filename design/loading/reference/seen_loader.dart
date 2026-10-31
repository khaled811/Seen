// SeenLoader — reference implementation of the Seen brand loaders and refresher.
//
// Read it, then copy/adapt into the app's own structure (e.g. lib/core/widgets/loading/).
// Do NOT add it as a package and do NOT restyle any existing screen with it.
//
// Contents
//   SeenMarkGeometry      paths traced from the logo (box 120 × 140)
//   SeenLoaderColors      the 6 colours the loaders need — wire them to the app's existing theme
//   SeenLoader            SeenMark.trace  — default spinner (buttons, fields, toasts, cards)
//   SeenMarkDraw          SeenMark.draw   — the mark writes itself (boot, blocking waits)
//   SeenSkyProgress       SeenMark.sky    — determinate progress (uploads, submit, export)
//   SeenWindows           SeenWindows     — inline 3-window loader (load more, typing, saving)
//   SeenShimmer/SkeletonBox                skeleton with RTL sweep
//   SeenRefreshBubble     the refresher bubble for each stage (pure widget, golden-testable)
//   SeenRefresh           pull-to-refresh wrapper (uses package:custom_refresh_indicator)
//   SeenLoadingGate       300 ms show-delay + 500 ms minimum-visible policy
//
// Requires Dart 3 / Flutter ≥ 3.27 (Color.withValues, Color.a). On older Flutter replace
// `c.withValues(alpha: x)` with `c.withOpacity(x)` and `c.a` with `c.opacity`.
// Only SeenRefresh needs a package:
//   custom_refresh_indicator: ^4.0.1   — if the app already uses another refresh package, adapt
//   SeenRefresh to it and keep SeenRefreshBubble unchanged.

import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Geometry
// ─────────────────────────────────────────────────────────────────────────────

/// Paths traced from the Seen logo. Box 120 × 140, butt caps, miter joins.
/// window = airplane window, tooth + smile = the letter «س» inside it.
abstract final class SeenMarkGeometry {
  static const Size box = Size(120, 140);
  static const double windowStroke = 10;
  static const double toothStroke = 9.5;
  static const double smileStroke = 10;

  static final RRect window = RRect.fromRectAndRadius(
    const Rect.fromLTWH(11, 7, 99, 127),
    const Radius.circular(31),
  );

  /// Inner edge of the window stroke — used to clip the sky fill.
  static final RRect windowInner = RRect.fromRectAndRadius(
    const Rect.fromLTWH(15.5, 11.5, 90, 118),
    const Radius.circular(26.5),
  );

  static Path windowPath() => Path()..addRRect(window);

  static Path toothPath() => Path()
    ..moveTo(36.6, 67)
    ..lineTo(45.8, 53.5)
    ..quadraticBezierTo(60.3, 63.9, 80.5, 52);

  static Path smilePath() => Path()
    ..moveTo(24.2, 76.6)
    ..quadraticBezierTo(59, 102.4, 94.7, 76.1);
}

double _c01(double v) => v < 0 ? 0.0 : (v > 1 ? 1.0 : v);

/// Part of [source] between fractions [from] and [to] of its length (0..1).
/// For closed paths the segment may wrap past the end (used by the trace).
Path _segment(Path source, double from, double to, {bool wrap = false}) {
  final out = Path();
  if (to <= from) return out;
  for (final metric in source.computeMetrics()) {
    final len = metric.length;
    if (to - from >= 1) {
      out.addPath(metric.extractPath(0, len), Offset.zero);
      continue;
    }
    if (!wrap) {
      out.addPath(metric.extractPath(_c01(from) * len, _c01(to) * len), Offset.zero);
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

// ─────────────────────────────────────────────────────────────────────────────
// Colours — map these to the app's EXISTING theme tokens, don't hard-code.
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class SeenLoaderColors {
  const SeenLoaderColors({
    this.ink = const Color(0xFF7B52F6), // brand accent
    this.track = const Color(0xFFE6DEFD), // accent tint
    this.skyTop = const Color(0xFFA68BFF),
    this.skyBottom = const Color(0xFF5A36D2),
    this.windowFill = const Color(0xFFF5F2FE), // surface tint
    this.skeletonBase = const Color(0xFFECE7FA),
    this.skeletonHighlight = const Color(0xBFFFFFFF), // white 75 %
    this.success = const Color(0xFF2E9E6B),
  });

  /// Variant for gradient / dark surfaces (boot, dark buttons, toasts).
  const SeenLoaderColors.onDark()
      : this(
          ink: const Color(0xFFFFFFFF),
          track: const Color(0x38FFFFFF), // white 22 %
          skeletonBase: const Color(0x29FFFFFF), // white 16 %
          skeletonHighlight: const Color(0x47FFFFFF), // white 28 %
        );

  final Color ink, track, skyTop, skyBottom, windowFill, skeletonBase, skeletonHighlight, success;
}

bool _reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

// ─────────────────────────────────────────────────────────────────────────────
// Painter shared by trace / draw / refresher
// ─────────────────────────────────────────────────────────────────────────────

class _Seg {
  const _Seg(this.a, this.b);
  final double a, b;
  static const full = _Seg(0, 1);
  static const none = _Seg(0, 0);
}

class _SeenMarkPainter extends CustomPainter {
  _SeenMarkPainter({
    required this.ink,
    required this.track,
    this.window = _Seg.full,
    this.tooth = _Seg.full,
    this.smile = _Seg.full,
    this.tracePhase,
    this.showTrack = false,
    this.showGlyph = true,
    this.smileScale = 1,
  });

  final Color ink, track;
  final _Seg window, tooth, smile;

  /// When non-null, the window is drawn as a running light: tail 34 %, head 14 %.
  final double? tracePhase;
  final bool showTrack, showGlyph;
  final double smileScale;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 120, size.height / 140);
    canvas.save();
    canvas.translate((size.width - 120 * s) / 2, (size.height - 140 * s) / 2);
    canvas.scale(s);

    // Keep strokes ≥ 2 physical px at small sizes (18–24 px).
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
      canvas.drawPath(_segment(win, phase, phase + .34, wrap: true),
          stroke(ink.withValues(alpha: ink.a * .38), ws, cap: StrokeCap.round));
      canvas.drawPath(_segment(win, phase + .20, phase + .34, wrap: true), stroke(ink, ws, cap: StrokeCap.round));
    } else {
      canvas.drawPath(_segment(win, window.a, window.b), stroke(ink, ws));
    }

    if (showGlyph) {
      final gs = math.max(SeenMarkGeometry.toothStroke, 1.6 / s);
      canvas.drawPath(_segment(SeenMarkGeometry.toothPath(), tooth.a, tooth.b), stroke(ink, gs));
      final smilePath = _segment(SeenMarkGeometry.smilePath(), smile.a, smile.b);
      if (smileScale != 1) {
        canvas.save();
        canvas.translate(59.5, 86);
        canvas.scale(smileScale, 1 + (smileScale - 1) * .6);
        canvas.translate(-59.5, -86);
        canvas.drawPath(smilePath, stroke(ink, math.max(SeenMarkGeometry.smileStroke, 1.6 / s)));
        canvas.restore();
      } else {
        canvas.drawPath(smilePath, stroke(ink, math.max(SeenMarkGeometry.smileStroke, 1.6 / s)));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SeenMarkPainter oldDelegate) =>
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

Size _markSize(double height) => Size(height * 120 / 140, height);

// ─────────────────────────────────────────────────────────────────────────────
// SeenMark.trace — default spinner
// ─────────────────────────────────────────────────────────────────────────────

/// Light running round the window. [height] is the mark height (16, 18, 24, 40, 64, 96…).
/// The «س» glyph is shown from 36 px up. 1100 ms linear (2600 ms with reduce-motion).
class SeenLoader extends StatefulWidget {
  const SeenLoader({super.key, this.height = 24, this.colors = const SeenLoaderColors(), this.semanticLabel});

  const SeenLoader.onDark({super.key, this.height = 18, this.semanticLabel})
      : colors = const SeenLoaderColors.onDark();

  final double height;
  final SeenLoaderColors colors;

  /// Leave null when the surrounding container already announces «جاري التحميل».
  final String? semanticLabel;

  @override
  State<SeenLoader> createState() => _SeenLoaderState();
}

class _SeenLoaderState extends State<SeenLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final d = Duration(milliseconds: _reduceMotion(context) ? 2600 : 1100);
    if (_c.duration != d || !_c.isAnimating) {
      _c.duration = d;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final painter = AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: _markSize(widget.height),
        painter: _SeenMarkPainter(
          ink: widget.colors.ink,
          track: widget.colors.track,
          tracePhase: _c.value,
          showTrack: true,
          showGlyph: widget.height >= 36,
        ),
      ),
    );
    return Semantics(label: widget.semanticLabel, excludeSemantics: true, child: RepaintBoundary(child: painter));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SeenMark.draw — the mark writes itself
// ─────────────────────────────────────────────────────────────────────────────

/// 2800 ms loop: window 0–32 %, tooth 22–42 %, smile 36–58 %, hold, then each stroke erases forward
/// (window 72–94 %, tooth 76–95 %, smile 80–97 %). Curve ≈ cubic-bezier(.65,0,.35,1).
/// Reduce-motion: the complete mark, static.
class SeenMarkDraw extends StatefulWidget {
  const SeenMarkDraw({super.key, this.height = 96, this.colors = const SeenLoaderColors()});
  const SeenMarkDraw.onDark({super.key, this.height = 120}) : colors = const SeenLoaderColors.onDark();

  final double height;
  final SeenLoaderColors colors;

  @override
  State<SeenMarkDraw> createState() => _SeenMarkDrawState();
}

class _SeenMarkDrawState extends State<SeenMarkDraw> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800));
  static const _curve = Cubic(.65, 0, .35, 1);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static _Seg _seg(double t, double d0, double d1, double e0, double e1) {
    if (t < d0) return _Seg.none;
    if (t < d1) return _Seg(0, _curve.transform((t - d0) / (d1 - d0)));
    if (t < e0) return _Seg.full;
    if (t < e1) return _Seg(_curve.transform((t - e0) / (e1 - e0)), 1);
    return _Seg.none;
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion(context);
    return ExcludeSemantics(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            return CustomPaint(
              size: _markSize(widget.height),
              painter: _SeenMarkPainter(
                ink: widget.colors.ink,
                track: widget.colors.track,
                window: reduce ? _Seg.full : _seg(t, 0, .32, .72, .94),
                tooth: reduce ? _Seg.full : _seg(t, .22, .42, .76, .95),
                smile: reduce ? _Seg.full : _seg(t, .36, .58, .80, .97),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SeenMark.sky — determinate progress
// ─────────────────────────────────────────────────────────────────────────────

/// The window fills with sky from the bottom as [value] goes 0 → 1; clouds drift right → left;
/// the «س» turns white where the sky covers it. Always pair with a visible % text.
class SeenSkyProgress extends StatefulWidget {
  const SeenSkyProgress({super.key, required this.value, this.height = 92, this.colors = const SeenLoaderColors()});

  final double value;
  final double height;
  final SeenLoaderColors colors;

  @override
  State<SeenSkyProgress> createState() => _SeenSkyProgressState();
}

class _SeenSkyProgressState extends State<SeenSkyProgress> with SingleTickerProviderStateMixin {
  late final AnimationController _clouds = AnimationController(vsync: this, duration: const Duration(seconds: 70));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _clouds.stop();
    } else if (!_clouds.isAnimating) {
      _clouds.repeat();
    }
  }

  @override
  void dispose() {
    _clouds.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c01(widget.value);
    return Semantics(
      value: '${(v * 100).round()}٪',
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: v),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        builder: (context, value, _) => AnimatedBuilder(
          animation: _clouds,
          builder: (context, _) => CustomPaint(
            size: _markSize(widget.height),
            painter: _SkyPainter(value: value, cloudT: _clouds.value * 70, colors: widget.colors), // seconds; 70 = lcm(7, 10)
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.value, required this.cloudT, required this.colors});
  final double value, cloudT;
  final SeenLoaderColors colors;

  void _cloud(Canvas canvas, Offset c, double scale, Paint p) {
    canvas.drawOval(Rect.fromCenter(center: c, width: 26 * scale, height: 14 * scale), p);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(9 * scale, -4 * scale), width: 18 * scale, height: 14 * scale), p);
    canvas.drawOval(Rect.fromCenter(center: c + Offset(-10 * scale, 2 * scale), width: 16 * scale, height: 10 * scale), p);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 120, size.height / 140);
    canvas.save();
    canvas.translate((size.width - 120 * s) / 2, (size.height - 140 * s) / 2);
    canvas.scale(s);

    final skyTop = 129 - value * 117;
    final skyRect = Rect.fromLTRB(0, skyTop, 120, 140);
    final airRect = Rect.fromLTRB(0, 0, 120, skyTop);

    // window content
    canvas.save();
    canvas.clipRRect(SeenMarkGeometry.windowInner);
    canvas.drawRect(const Rect.fromLTWH(11, 7, 99, 127), Paint()..color = colors.windowFill);
    canvas.save();
    canvas.clipRect(skyRect);
    canvas.drawRect(
      const Rect.fromLTWH(11, 7, 99, 127),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [colors.skyTop, colors.skyBottom],
        ).createShader(const Rect.fromLTWH(11, 7, 99, 127)),
    );
    final cloudPaint = Paint()..color = const Color(0xE6FFFFFF);
    // drift right → left (RTL), 7 s and 10 s periods
    double x(double period, double offset) => 130 - (((cloudT + offset) % period) / period) * 200;
    _cloud(canvas, Offset(x(7, 3.6), 112), 1, cloudPaint);
    _cloud(canvas, Offset(x(10, 4), 40), .8, cloudPaint);
    canvas.drawRect(Rect.fromLTWH(0, skyTop, 120, 2.5), Paint()..color = const Color(0x73FFFFFF));
    canvas.restore();
    canvas.restore();

    Paint glyph(Color c, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.butt
      ..color = c;
    void drawGlyph(Color c) {
      canvas.drawPath(SeenMarkGeometry.toothPath(), glyph(c, SeenMarkGeometry.toothStroke));
      canvas.drawPath(SeenMarkGeometry.smilePath(), glyph(c, SeenMarkGeometry.smileStroke));
    }

    canvas.save();
    canvas.clipRect(airRect);
    drawGlyph(colors.ink);
    canvas.restore();
    canvas.save();
    canvas.clipRect(skyRect);
    drawGlyph(const Color(0xFFFFFFFF));
    canvas.restore();

    canvas.drawRRect(
      SeenMarkGeometry.window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(SeenMarkGeometry.windowStroke, 2 / s)
        ..color = colors.ink,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SkyPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.cloudT != cloudT || oldDelegate.colors != colors;
}

// ─────────────────────────────────────────────────────────────────────────────
// SeenWindows — inline loader
// ─────────────────────────────────────────────────────────────────────────────

/// Three cabin windows that light up start → end (right → left in RTL), stagger 180 ms, 1200 ms.
/// [size] is the window height (6–10 inline, up to 18).
class SeenWindows extends StatefulWidget {
  const SeenWindows({super.key, this.size = 8, this.color});
  final double size;
  final Color? color;

  @override
  State<SeenWindows> createState() => _SeenWindowsState();
}

class _SeenWindowsState extends State<SeenWindows> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // 0 → .35 rise to lit, .35 → .70 fall, rest dim
  double _lit(double t) {
    t = t % 1;
    if (t < .35) return Curves.easeInOut.transform(t / .35);
    if (t < .70) return 1 - Curves.easeInOut.transform((t - .35) / .35);
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? const SeenLoaderColors().ink;
    final reduce = _reduceMotion(context);
    final d = widget.size;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) SizedBox(width: d * .55),
              Builder(builder: (_) {
                final lit = reduce ? (i == 0 ? 1.0 : .4) : _lit(_c.value - i * .15);
                return Opacity(
                  opacity: .3 + .7 * lit,
                  child: Container(
                    width: d * .82,
                    height: d,
                    decoration: BoxDecoration(
                      color: Color.lerp(color.withValues(alpha: 0), color, lit),
                      border: Border.all(color: color, width: math.max(1.2, d * .2)),
                      borderRadius: BorderRadius.circular(d * .36),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton
// ─────────────────────────────────────────────────────────────────────────────

/// Wrap a subtree of [SkeletonBox]es (or any opaque shapes) — one shared sweep, 1400 ms linear,
/// moving right → left in RTL. Reduce-motion: static base colour.
class SeenShimmer extends StatefulWidget {
  const SeenShimmer({super.key, required this.child, this.colors = const SeenLoaderColors()});
  final Widget child;
  final SeenLoaderColors colors;

  @override
  State<SeenShimmer> createState() => _SeenShimmerState();
}

class _SeenShimmerState extends State<SeenShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_reduceMotion(context)) return widget.child;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (_, child) => ShaderMask(
        blendMode: BlendMode.srcATop,
        shaderCallback: (bounds) {
          // band = 50 % of the width; travels fully across, start → end
          final p = rtl ? 1.5 - _c.value * 3 : -1.5 + _c.value * 3;
          return LinearGradient(
            colors: [widget.colors.skeletonBase, widget.colors.skeletonHighlight, widget.colors.skeletonBase],
            stops: const [.25, .5, .75],
            transform: _SlideGradient(p),
          ).createShader(bounds);
        },
        child: child,
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  const _SlideGradient(this.percent);
  final double percent;
  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * percent, 0, 0);
}

/// A skeleton shape. Use the same radius as the real component it stands in for.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 6, this.colors = const SeenLoaderColors()});
  final double? width;
  final double height, radius;
  final SeenLoaderColors colors;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: colors.skeletonBase, borderRadius: BorderRadius.circular(radius)),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Refresher
// ─────────────────────────────────────────────────────────────────────────────

enum SeenRefreshStage { pull, armed, loading, done }

/// The refresher bubble — the mark draws itself as the user pulls.
/// pull 0 → .55 window, .55 → .80 tooth, .80 → 1 smile; armed: bubble fills ink, scale 1.08;
/// loading: SeenMark.trace; done: smile bounce 500 ms + green ✓.
class SeenRefreshBubble extends StatefulWidget {
  const SeenRefreshBubble({
    super.key,
    required this.stage,
    this.pull = 0,
    this.size = 52,
    this.colors = const SeenLoaderColors(),
  });

  final SeenRefreshStage stage;

  /// 0..1 — only used while [stage] is pull.
  final double pull;
  final double size;
  final SeenLoaderColors colors;

  @override
  State<SeenRefreshBubble> createState() => _SeenRefreshBubbleState();
}

class _SeenRefreshBubbleState extends State<SeenRefreshBubble> with TickerProviderStateMixin {
  late final AnimationController _trace = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _bounce = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));

  @override
  void initState() {
    super.initState();
    _sync(null);
  }

  @override
  void didUpdateWidget(SeenRefreshBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(oldWidget.stage);
  }

  void _sync(SeenRefreshStage? from) {
    if (widget.stage == SeenRefreshStage.loading) {
      if (!_trace.isAnimating) _trace.repeat();
    } else {
      _trace.stop();
    }
    if (widget.stage == SeenRefreshStage.done && from != SeenRefreshStage.done) _bounce.forward(from: 0);
  }

  @override
  void dispose() {
    _trace.dispose();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final armed = widget.stage == SeenRefreshStage.armed;
    final loading = widget.stage == SeenRefreshStage.loading;
    final done = widget.stage == SeenRefreshStage.done;
    final p = _c01(widget.pull);
    double part(double a, double b) => _c01((p - a) / (b - a));
    final whole = armed || loading || done;

    final ink = armed ? const Color(0xFFFFFFFF) : c.ink;
    final track = armed ? const Color(0x40FFFFFF) : (loading ? c.track : c.track.withValues(alpha: c.track.a * .55));
    final markH = widget.size * 30 / 52;

    return AnimatedScale(
      scale: armed ? 1.08 : 1,
      duration: const Duration(milliseconds: 250),
      curve: const Cubic(.2, 0, 0, 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: armed ? c.ink : const Color(0xFFFFFFFF),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Color(0x292C186A), blurRadius: 32, offset: Offset(0, 12), spreadRadius: -4)],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_trace, _bounce]),
              builder: (context, _) {
                final b = _bounce.value;
                final smileScale = done ? 1 + .16 * math.sin(b * math.pi) : 1.0;
                return CustomPaint(
                  size: _markSize(markH),
                  painter: _SeenMarkPainter(
                    ink: ink,
                    track: track,
                    showTrack: true,
                    tracePhase: loading ? _trace.value : null,
                    window: whole ? _Seg.full : _Seg(0, part(0, .55)),
                    tooth: whole ? _Seg.full : _Seg(0, part(.55, .80)),
                    smile: whole ? _Seg.full : _Seg(0, part(.80, 1)),
                    smileScale: smileScale,
                  ),
                );
              },
            ),
            if (done)
              PositionedDirectional(
                top: -2,
                end: -2,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: c.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFFFFF), width: 2),
                  ),
                  child: const Icon(Icons.check_rounded, size: 12, color: Color(0xFFFFFFFF)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Labels under the bubble (Arabic).
class SeenRefreshLabels {
  const SeenRefreshLabels({
    this.pull = 'اسحب للتحديث',
    this.armed = 'أفلت للتحديث',
    this.loading = 'جاري التحديث…',
    this.done = 'تم التحديث',
  });
  final String pull, armed, loading, done;
}

/// Pull-to-refresh with the Seen bubble. Threshold 72 px of indicator travel; settles at 56 px
/// while loading; shows «done» for 900 ms then collapses in 250 ms. Old content stays visible.
///
/// Built on package:custom_refresh_indicator (^4.0.1). Check the installed version's API
/// (IndicatorController / IndicatorState / onStateChanged) and adjust if it differs.
class SeenRefresh extends StatelessWidget {
  const SeenRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.labels = const SeenRefreshLabels(),
    this.colors = const SeenLoaderColors(),
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final SeenRefreshLabels labels;
  final SeenLoaderColors colors;

  static const double armedOffset = 72;
  static const double loadingOffset = 56;

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      offsetToArmed: armedOffset,
      // v3+/v4 API. If your installed version still has `completeStateDuration`, use that instead.
      durations: const RefreshIndicatorDurations(completeDuration: Duration(milliseconds: 900)),
      onStateChanged: (change) {
        if (change.didChange(to: IndicatorState.armed)) HapticFeedback.lightImpact();
      },
      builder: (context, child, controller) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final SeenRefreshStage stage;
          if (controller.isComplete || controller.isFinalizing) {
            stage = SeenRefreshStage.done;
          } else if (controller.isLoading || controller.isSettling) {
            stage = SeenRefreshStage.loading;
          } else if (controller.isArmed) {
            stage = SeenRefreshStage.armed;
          } else {
            stage = SeenRefreshStage.pull;
          }
          final double v = math.min(math.max(controller.value, 0.0), 1.5);
          // settled height while loading / done; follows the drag otherwise (and collapses when finalizing)
          final double offset;
          if (controller.isLoading || controller.isSettling || controller.isComplete) {
            offset = loadingOffset + 30;
          } else if (controller.isFinalizing) {
            offset = v * (loadingOffset + 30); // collapse from the settled height
          } else {
            offset = v * (armedOffset + 30);
          }
          final label = switch (stage) {
            SeenRefreshStage.pull => labels.pull,
            SeenRefreshStage.armed => labels.armed,
            SeenRefreshStage.loading => labels.loading,
            SeenRefreshStage.done => labels.done,
          };
          return Stack(
            children: [
              Transform.translate(offset: Offset(0, offset), child: child),
              if (!controller.isIdle)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: offset,
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.center,
                      minHeight: 0,
                      maxHeight: 96,
                      child: Semantics(
                        liveRegion: true,
                        label: label,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SeenRefreshBubble(stage: stage, pull: v, colors: colors),
                            const SizedBox(height: 6),
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                height: 16 / 12,
                                fontWeight: stage == SeenRefreshStage.armed ? FontWeight.w600 : FontWeight.w400,
                                color: switch (stage) {
                                  SeenRefreshStage.done => const Color(0xFF17694A),
                                  SeenRefreshStage.armed => const Color(0xFF2C186A),
                                  _ => const Color(0xFF5B5280),
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timing policy
// ─────────────────────────────────────────────────────────────────────────────

/// Shows [loading] only if [isLoading] stays true for 300 ms; once shown keeps it ≥ 500 ms
/// so it never flickers. Otherwise shows [child].
class SeenLoadingGate extends StatefulWidget {
  const SeenLoadingGate({super.key, required this.isLoading, required this.loading, required this.child});
  final bool isLoading;
  final Widget loading;
  final Widget child;

  static const showDelay = Duration(milliseconds: 300);
  static const minVisible = Duration(milliseconds: 500);

  @override
  State<SeenLoadingGate> createState() => _SeenLoadingGateState();
}

class _SeenLoadingGateState extends State<SeenLoadingGate> {
  bool _showing = false;
  DateTime? _shownAt;
  Future<void>? _pending;

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) _scheduleShow();
  }

  @override
  void didUpdateWidget(SeenLoadingGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading && !oldWidget.isLoading) _scheduleShow();
    if (!widget.isLoading && oldWidget.isLoading) _scheduleHide();
  }

  void _scheduleShow() {
    final f = Future<void>.delayed(SeenLoadingGate.showDelay);
    _pending = f;
    f.then((_) {
      if (!mounted || _pending != f || !widget.isLoading) return;
      setState(() {
        _showing = true;
        _shownAt = DateTime.now();
      });
    });
  }

  void _scheduleHide() {
    _pending = null;
    if (!_showing) return;
    final left = SeenLoadingGate.minVisible - DateTime.now().difference(_shownAt!);
    if (left <= Duration.zero) {
      setState(() => _showing = false);
      return;
    }
    Future<void>.delayed(left).then((_) {
      if (mounted && !widget.isLoading) setState(() => _showing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // While waiting the first 300 ms keep the previous content (or nothing on first load).
    if (_showing) return widget.loading;
    if (widget.isLoading) return const SizedBox.shrink();
    return widget.child;
  }
}
