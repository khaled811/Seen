import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';

/// Shows [front] or [back] with a 3D card flip around the Y axis
/// (`Matrix4` rotation with perspective). Both faces stay mounted — their
/// state survives a flip — and only the visible one is painted/hit-tested.
///
/// The flip direction follows [Directionality]. With reduced motion the faces
/// swap instantly.
class FlipSwitcher extends StatefulWidget {
  const FlipSwitcher({
    super.key,
    required this.flipped,
    required this.front,
    required this.back,
    this.duration = SpiritualMotion.flip,
  });

  /// false = [front], true = [back].
  final bool flipped;
  final Widget front;
  final Widget back;
  final Duration duration;

  @override
  State<FlipSwitcher> createState() => _FlipSwitcherState();
}

class _FlipSwitcherState extends State<FlipSwitcher>
    with SingleTickerProviderStateMixin {
  static const _perspective = 0.0012;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.flipped ? 1 : 0,
  );

  @override
  void didUpdateWidget(FlipSwitcher old) {
    super.didUpdateWidget(old);
    if (old.flipped == widget.flipped) return;
    final target = widget.flipped ? 1.0 : 0.0;
    final duration = SpiritualMotion.of(context, widget.duration);
    if (duration == Duration.zero) {
      _controller.value = target;
    } else {
      _controller.animateTo(
        target,
        duration: duration,
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _face({
    required Widget child,
    required double angle,
    required bool visible,
  }) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, _perspective)
        ..rotateY(angle),
      child: Visibility(
        visible: visible,
        maintainState: true,
        child: TickerMode(
          enabled: visible,
          child: RepaintBoundary(child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sign = Directionality.of(context) == TextDirection.rtl ? -1.0 : 1.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final angle = sign * t * math.pi;
        final frontVisible = t < 0.5;
        // Children are the same widget instances on every tick, so only the
        // transforms are rebuilt — never the faces.
        return Stack(
          fit: StackFit.expand,
          children: [
            _face(child: widget.front, angle: angle, visible: frontVisible),
            _face(
              child: widget.back,
              angle: angle - sign * math.pi,
              visible: !frontVisible,
            ),
          ],
        );
      },
    );
  }
}
