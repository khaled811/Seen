// Skeletons. One `SeenShimmer` per screen region owns a single sweep (a highlight band 50 % of
// the region wide, 1400 ms linear, moving right -> left in RTL, start -> end in LTR); every
// `SkeletonBox` inside paints its own slice of that same band, so the sweep is continuous
// across boxes and never repaints static chrome (cards, borders, shadows) around them.
// Reduce motion: no sweep, static base colour.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'seen_mark.dart';

class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({
    required this.animation,
    required this.regionKey,
    required this.colors,
    required this.rtl,
    required super.child,
  });

  /// null = still (reduce motion).
  final Animation<double>? animation;
  final GlobalKey regionKey;
  final SeenLoaderColors colors;
  final bool rtl;

  @override
  bool updateShouldNotify(_ShimmerScope old) =>
      animation != old.animation ||
      colors != old.colors ||
      rtl != old.rtl ||
      regionKey != old.regionKey;
}

/// Wrap a region of [SkeletonBox]es. Created in initState, disposed in dispose; stopped while
/// "reduce motion" is on.
class SeenShimmer extends StatefulWidget {
  const SeenShimmer(
      {super.key, required this.child, this.colors = const SeenLoaderColors()});

  final Widget child;
  final SeenLoaderColors colors;

  @override
  State<SeenShimmer> createState() => _SeenShimmerState();
}

class _SeenShimmerState extends State<SeenShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400));
  final _regionKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (seenReduceMotion(context)) {
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
    return _ShimmerScope(
      animation: seenReduceMotion(context) ? null : _c,
      regionKey: _regionKey,
      colors: widget.colors,
      rtl: Directionality.of(context) == TextDirection.rtl,
      child: KeyedSubtree(key: _regionKey, child: widget.child),
    );
  }
}

/// A skeleton shape. Use the same size and radius as the real component it stands in for.
/// Outside a [SeenShimmer] it is drawn still.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox(
      {super.key, this.width, required this.height, this.radius = 6});

  /// null = as wide as the parent allows.
  final double? width;
  final double height, radius;

  @override
  Widget build(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_ShimmerScope>();
    return _SweepBox(
      width: width,
      height: height,
      radius: radius,
      colors: scope?.colors ?? const SeenLoaderColors(),
      animation: scope?.animation,
      regionKey: scope?.regionKey,
      rtl: scope?.rtl ?? true,
    );
  }
}

class _SweepBox extends LeafRenderObjectWidget {
  const _SweepBox({
    required this.width,
    required this.height,
    required this.radius,
    required this.colors,
    required this.animation,
    required this.regionKey,
    required this.rtl,
  });

  final double? width;
  final double height, radius;
  final SeenLoaderColors colors;
  final Animation<double>? animation;
  final GlobalKey? regionKey;
  final bool rtl;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSweepBox(
        width: width,
        height: height,
        radius: radius,
        colors: colors,
        animation: animation,
        regionKey: regionKey,
        rtl: rtl,
      );

  @override
  void updateRenderObject(BuildContext context, _RenderSweepBox r) {
    r
      ..widthHint = width
      ..heightValue = height
      ..radius = radius
      ..colors = colors
      ..animation = animation
      ..regionKey = regionKey
      ..rtl = rtl;
  }
}

class _RenderSweepBox extends RenderBox {
  _RenderSweepBox({
    required double? width,
    required double height,
    required double radius,
    required SeenLoaderColors colors,
    required Animation<double>? animation,
    required GlobalKey? regionKey,
    required bool rtl,
  })  : _width = width,
        _height = height,
        _radius = radius,
        _colors = colors,
        _animation = animation,
        _regionKey = regionKey,
        _rtl = rtl;

  double? _width;
  double _height;
  double _radius;
  SeenLoaderColors _colors;
  Animation<double>? _animation;
  GlobalKey? _regionKey;
  bool _rtl;

  set widthHint(double? v) {
    if (_width == v) return;
    _width = v;
    markNeedsLayout();
  }

  set heightValue(double v) {
    if (_height == v) return;
    _height = v;
    markNeedsLayout();
  }

  set radius(double v) {
    if (_radius == v) return;
    _radius = v;
    markNeedsPaint();
  }

  set colors(SeenLoaderColors v) {
    if (_colors == v) return;
    _colors = v;
    markNeedsPaint();
  }

  set regionKey(GlobalKey? v) {
    _regionKey = v;
    markNeedsPaint();
  }

  set rtl(bool v) {
    if (_rtl == v) return;
    _rtl = v;
    markNeedsPaint();
  }

  set animation(Animation<double>? v) {
    if (_animation == v) return;
    if (attached) _animation?.removeListener(markNeedsPaint);
    _animation = v;
    if (attached) _animation?.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _animation?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _animation?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void performLayout() {
    final w = _width ?? constraints.maxWidth;
    size = constraints
        .constrain(Size(w.isFinite ? w : constraints.maxWidth, _height));
  }

  @override
  bool get sizedByParent => false;

  @override
  void paint(PaintingContext context, Offset offset) {
    final rrect =
        RRect.fromRectAndRadius(offset & size, Radius.circular(_radius));
    final paint = Paint()..color = _colors.skeletonBase;
    final anim = _animation;
    final region = _regionKey?.currentContext?.findRenderObject();
    if (anim != null &&
        region is RenderBox &&
        region.hasSize &&
        region.size.width > 0) {
      final w = region.size.width;
      final boxX = localToGlobal(Offset.zero, ancestor: region).dx;
      // Band centre in region coordinates: it travels the whole width plus half a band each side.
      final t = anim.value;
      final cx = _rtl ? w * (1.25 - 1.5 * t) : w * (-.25 + 1.5 * t);
      final band = w * .5;
      // Gradient in this box's coordinates (box left edge = offset.dx).
      final left = offset.dx + (cx - band / 2) - boxX;
      paint.shader = LinearGradient(
        colors: [
          _colors.skeletonBase,
          _colors.skeletonHighlight,
          _colors.skeletonBase
        ],
      ).createShader(Rect.fromLTWH(left, offset.dy, band, size.height));
    }
    context.canvas.drawRRect(rrect, paint);
  }
}
