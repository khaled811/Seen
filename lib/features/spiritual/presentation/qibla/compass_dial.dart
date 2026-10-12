import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/arabic_digits.dart';
import '../../domain/utils/angles.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/kaaba_glyph.dart';

/// The compass dial (docs/03 §6): 300 dp, 72 ticks, upright cardinal letters,
/// the Kaaba at the Qibla bearing, a centre disk with the angles, and a pulse
/// ring while locked.
///
/// The dial rotates by −heading. A [Ticker] eases the drawn heading towards
/// the (already low-pass filtered) [heading] every frame, along the shortest
/// angle, so the dial never jumps across 359° → 1°. Only the rotation is
/// rebuilt per frame; the tick marks are painted once.
///
/// With a null [heading] (no compass) the dial is static, north up.
class CompassDial extends StatefulWidget {
  const CompassDial({
    super.key,
    required this.bearing,
    required this.heading,
    required this.locked,
    this.sunAzimuth,
  });

  /// Qibla bearing, degrees clockwise from north.
  final double bearing;
  final double? heading;
  final bool locked;

  /// Sun azimuth to mark on the ring (no-compass fallback), or null.
  final double? sunAzimuth;

  static const size = 300.0;

  @override
  State<CompassDial> createState() => _CompassDialState();
}

class _CompassDialState extends State<CompassDial>
    with SingleTickerProviderStateMixin {
  // Owned here: created in initState, disposed in dispose.
  late final Ticker _ticker;
  final ValueNotifier<double> _shown = ValueNotifier(0);
  bool _seeded = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame);
    final h = widget.heading;
    if (h != null) {
      _shown.value = h;
      _seeded = true;
    }
  }

  @override
  void didUpdateWidget(CompassDial old) {
    super.didUpdateWidget(old);
    // Wake the ticker only when there is somewhere to go: an idle compass
    // costs no frames (battery).
    if (widget.heading != old.heading && widget.heading != null) _wake();
  }

  void _wake() {
    if (!_ticker.isActive) _ticker.start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = SpiritualMotion.reduced(context);
  }

  void _onFrame(Duration _) {
    final target = widget.heading;
    if (target == null) {
      _ticker.stop();
      return;
    }
    if (!_seeded || _reduceMotion) {
      _seeded = true;
      _shown.value = target;
      _ticker.stop();
      return;
    }
    final delta = shortestDelta(_shown.value, target);
    if (delta.abs() < 0.02) {
      _shown.value = target;
      _ticker.stop(); // settled: stop asking for frames
      return;
    }
    _shown.value = lerpAngle(_shown.value, target, 0.35);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _shown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final locked = widget.locked;
    final ring = locked ? t.sage : const Color(0xFFCFEFF3);
    final ticks = RepaintBoundary(
      child: CustomPaint(
        size: const Size.square(CompassDial.size),
        painter: _TicksPainter(
          major: t.inkPrimary,
          mid: t.inkBody,
          minor: Color.lerp(t.borderStrong, t.inkMuted, 0.6)!,
        ),
      ),
    );
    return SizedBox.square(
      dimension: CompassDial.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (locked) const _PulseRing(),
          ValueListenableBuilder<double>(
            valueListenable: _shown,
            child: ticks,
            builder: (context, shown, ticks) {
              final rotation = -_rad(shown);
              return AnimatedContainer(
                duration: SpiritualMotion.of(context, SpiritualMotion.base),
                width: CompassDial.size,
                height: CompassDial.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: t.surface,
                  border: Border.all(color: ring, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D1A1C1E),
                      offset: Offset(0, 2),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Transform.rotate(
                  angle: rotation,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ticks!,
                      _onDial(0, rotation, 30, _cardinal('ش', 22, t.accent)),
                      _onDial(
                          90, rotation, 30, _cardinal('ق', 18, t.inkPrimary)),
                      _onDial(
                          180, rotation, 30, _cardinal('ج', 18, t.inkPrimary)),
                      _onDial(
                          270, rotation, 30, _cardinal('غ', 18, t.inkPrimary)),
                      if (widget.sunAzimuth != null)
                        _onDial(
                          widget.sunAzimuth!,
                          rotation,
                          56,
                          Icon(Icons.wb_sunny_outlined,
                              size: 22, color: t.amber),
                        ),
                      _onDial(widget.bearing, rotation, 26,
                          const KaabaGlyph(size: 28)),
                    ],
                  ),
                ),
              );
            },
          ),
          _CentreDisk(
            bearing: widget.bearing,
            heading: widget.heading,
            locked: locked,
          ),
        ],
      ),
    );
  }

  /// Places [child] at [angle] degrees clockwise from the top of the dial,
  /// [inset] dp inside the rim, and keeps it upright whatever the dial's
  /// rotation ([dialRotation], radians).
  Widget _onDial(
      double angle, double dialRotation, double inset, Widget child) {
    final a = _rad(angle);
    return Transform.rotate(
      angle: a,
      child: SizedBox.square(
        dimension: CompassDial.size - 6,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: inset - 3),
            child: Transform.rotate(angle: -(a + dialRotation), child: child),
          ),
        ),
      ),
    );
  }

  Widget _cardinal(String letter, double size, Color color) => SizedBox(
        width: 36,
        child: Text(
          letter,
          textAlign: TextAlign.center,
          style: SpiritualType.section.copyWith(
            fontSize: size,
            height: 1.2,
            color: color,
          ),
        ),
      );

  static double _rad(double deg) => deg * math.pi / 180;
}

class _CentreDisk extends StatelessWidget {
  const _CentreDisk({
    required this.bearing,
    required this.heading,
    required this.locked,
  });

  final double bearing;
  final double? heading;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final h = heading;
    return Container(
      width: 156,
      height: 156,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: t.bg,
        border: Border.all(color: const Color(0xFFE0F7FA)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(SpiritualSpace.s12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                SpiritualStrings.qiblaAngle,
                style: SpiritualType.micro.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: t.inkBody,
                ),
              ),
              Text(
                '${toArabicDigits(bearing.round())}°',
                style: SpiritualType.compassDeg.copyWith(color: t.inkPrimary),
              ),
              if (h != null)
                Text(
                  '${SpiritualStrings.yourHeading} '
                  '${toArabicDigits(normalizeDegrees(h).round() % 360)}°',
                  style: SpiritualType.micro.copyWith(
                    fontSize: 14,
                    color: locked ? t.sageInk : t.inkBody,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sage ring that swells and fades while locked (1600 ms, repeating). With
/// reduced motion it is a static 35 % halo.
class _PulseRing extends StatefulWidget {
  const _PulseRing();

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SpiritualMotion.reduced(context)) {
      _controller.stop();
      _started = false;
    } else if (!_started) {
      _started = true;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    Widget ring(double opacity) => Opacity(
          opacity: opacity,
          child: Container(
            width: CompassDial.size,
            height: CompassDial.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: t.sage, width: 6),
            ),
          ),
        );
    if (SpiritualMotion.reduced(context)) return ring(0.35);
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final v = Curves.easeOut.transform(_controller.value);
        return Transform.scale(scale: 1 + 0.16 * v, child: ring(0.6 * (1 - v)));
      },
    );
  }
}

class _TicksPainter extends CustomPainter {
  _TicksPainter({required this.major, required this.mid, required this.minor});

  final Color major;
  final Color mid;
  final Color minor;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    // Inside the 3 dp rim plus a 5 dp margin (design: ticks start 5 px down).
    final outer = size.width / 2 - 3 - 2;
    for (var i = 0; i < 72; i++) {
      final deg = i * 5;
      final isMajor = deg % 30 == 0;
      final isMid = deg % 10 == 0;
      final len = isMajor ? 16.0 : (isMid ? 11.0 : 7.0);
      final paint = Paint()
        ..color = isMajor ? major : (isMid ? mid : minor)
        ..strokeWidth = isMajor ? 3 : (isMid ? 2 : 1.5)
        ..strokeCap = StrokeCap.round;
      final a = deg * math.pi / 180;
      final dir = Offset(math.sin(a), -math.cos(a));
      canvas.drawLine(c + dir * outer, c + dir * (outer - len), paint);
    }
  }

  @override
  bool shouldRepaint(_TicksPainter old) =>
      old.major != major || old.mid != mid || old.minor != minor;
}
