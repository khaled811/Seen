import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/seen_haptics.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_segmented.dart';

/// Hands-free reading speed: how fast the screen moves down.
enum AutoReadSpeed {
  slow(14, SpiritualStrings.autoSlow),
  medium(26, SpiritualStrings.autoMedium),
  fast(42, SpiritualStrings.autoFast);

  const AutoReadSpeed(this.pixelsPerSecond, this.label);

  /// Logical pixels per second.
  final double pixelsPerSecond;
  final String label;
}

/// Moves a [ScrollController] down at a constant speed, frame by frame, until
/// the end. Stops by itself at the end and on [stop]; costs nothing while
/// stopped (the [Ticker] is not scheduled).
///
/// Owner: whoever creates it calls [dispose].
class AutoScroller {
  AutoScroller({
    required TickerProvider vsync,
    required this.controller,
    this.onEnd,
  }) {
    _ticker = vsync.createTicker(_onTick);
  }

  final ScrollController controller;

  /// Called once when the end of the content has been reached.
  final VoidCallback? onEnd;

  /// Extra distance travelled (at the same speed) after the content's end
  /// before [onEnd] fires: a page that fits the screen still gets its reading
  /// time instead of turning at once.
  double tail = 0;

  late final Ticker _ticker;
  double _speed = 0;
  Duration _last = Duration.zero;
  double _offset = 0;

  bool get running => _ticker.isActive;

  void start(double pixelsPerSecond) {
    _speed = pixelsPerSecond;
    if (_ticker.isActive) return;
    _last = Duration.zero;
    _offset = controller.hasClients ? controller.position.pixels : 0;
    _ticker.start();
  }

  void changeSpeed(double pixelsPerSecond) => _speed = pixelsPerSecond;

  void stop() {
    if (_ticker.isActive) _ticker.stop();
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    if (!controller.hasClients) return;
    final pos = controller.position;
    // Follow any manual or programmatic move made since the last frame.
    if (_offset <= pos.maxScrollExtent && (pos.pixels - _offset).abs() > 1) {
      _offset = pos.pixels;
    }
    _offset += _speed * dt;
    if (_offset >= pos.maxScrollExtent + tail) {
      controller.jumpTo(pos.maxScrollExtent);
      stop();
      onEnd?.call();
      return;
    }
    controller.jumpTo(_offset.clamp(0.0, pos.maxScrollExtent));
  }

  void dispose() => _ticker.dispose();
}

/// Play / pause for hands-free reading, 48 dp.
class AutoReadButton extends StatelessWidget {
  const AutoReadButton({
    super.key,
    required this.running,
    required this.onPressed,
    this.color,
  });

  final bool running;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final c = color ?? t.accent;
    return PressScale(
      onTap: () {
        SeenHaptics.select();
        onPressed();
      },
      semanticLabel:
          running ? SpiritualStrings.autoStop : SpiritualStrings.autoStart,
      borderRadius: BorderRadius.circular(SpiritualRadius.button),
      child: Container(
        constraints: const BoxConstraints(
          minHeight: SpiritualSpace.minTap,
          minWidth: SpiritualSpace.minTap,
        ),
        padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s12),
        decoration: BoxDecoration(
          color: running ? c : t.surface,
          borderRadius: BorderRadius.circular(SpiritualRadius.button),
          border: Border.all(color: running ? c : t.borderControl),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              running ? Icons.pause : Icons.south,
              size: 22,
              color: running ? Colors.white : c,
            ),
            const SizedBox(width: SpiritualSpace.s6),
            Text(
              running ? SpiritualStrings.autoStop : SpiritualStrings.autoShort,
              style: SpiritualType.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: running ? Colors.white : c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The three speeds, shown while hands-free reading runs.
class AutoReadSpeedPicker extends StatelessWidget {
  const AutoReadSpeedPicker({
    super.key,
    required this.speed,
    required this.onChanged,
  });

  final AutoReadSpeed speed;
  final ValueChanged<AutoReadSpeed> onChanged;

  @override
  Widget build(BuildContext context) {
    return SpiritualSegmented<AutoReadSpeed>(
      options: [
        for (final s in AutoReadSpeed.values)
          SegmentOption(value: s, label: s.label),
      ],
      value: speed,
      onChanged: (s) {
        SeenHaptics.select();
        onChanged(s);
      },
    );
  }
}
