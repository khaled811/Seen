// The refresher. As the user pulls, the Seen mark draws itself: window (0-55 %), tooth (55-80 %),
// smile (80-100 %). Armed (>= 72 px): the bubble fills with ink, the mark turns white, scale
// 1.08, one light haptic tick. Loading: white bubble, the trace, settles at 56 px while the
// old data stays visible and scrollable. Done: smile bounce (500 ms) + a green check at the
// top-end of the bubble, held 900 ms, collapses in 250 ms.
// Engine: package:custom_refresh_indicator. Bubble widgets are pure (golden-testable).
import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/seen_colors.dart';
import '../../foundation/seen_strings.dart';
import '../svg_icon.dart';
import 'loading_strings.dart';
import 'seen_mark.dart';

enum SeenRefreshStage { pull, armed, loading, done }

/// The bubble. [pull] is 0..1 and only used while [stage] is [SeenRefreshStage.pull].
class SeenRefreshBubble extends StatefulWidget {
  const SeenRefreshBubble({
    super.key,
    required this.stage,
    this.pull = 0,
    this.size = 52,
    this.colors = const SeenLoaderColors(),
  });

  final SeenRefreshStage stage;
  final double pull;
  final double size;
  final SeenLoaderColors colors;

  @override
  State<SeenRefreshBubble> createState() => _SeenRefreshBubbleState();
}

class _SeenRefreshBubbleState extends State<SeenRefreshBubble>
    with TickerProviderStateMixin {
  late final AnimationController _trace = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final AnimationController _bounce = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));

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
    if (widget.stage == SeenRefreshStage.done && from != SeenRefreshStage.done) {
      _bounce.forward(from: 0);
    }
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
    final p = clamp01(widget.pull);
    double part(double a, double b) => clamp01((p - a) / (b - a));
    final whole = armed || loading || done;

    final ink = armed ? Colors.white : c.ink;
    final track = armed
        ? const Color(0x40FFFFFF)
        : (loading ? c.track : c.track.withOpacity(c.track.opacity * .55));
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
          color: armed ? c.ink : Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
                color: Color(0x292C186A),
                blurRadius: 32,
                offset: Offset(0, 12),
                spreadRadius: -4)
          ],
        ),
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            AnimatedBuilder(
              animation: Listenable.merge([_trace, _bounce]),
              builder: (context, _) {
                final smileScale =
                    done ? 1 + .16 * math.sin(_bounce.value * math.pi) : 1.0;
                return CustomPaint(
                  size: seenMarkSize(markH),
                  painter: SeenMarkPainter(
                    ink: ink,
                    track: track,
                    showTrack: true,
                    tracePhase: loading ? _trace.value : null,
                    window: whole ? SeenSeg.full : SeenSeg(0, part(0, .55)),
                    tooth: whole ? SeenSeg.full : SeenSeg(0, part(.55, .80)),
                    smile: whole ? SeenSeg.full : SeenSeg(0, part(.80, 1)),
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
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Padding(padding: EdgeInsets.all(4), child: SeenCheckGlyph(size: 12, color: Colors.white)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Pull-to-refresh with the Seen bubble. Threshold 72 px of indicator travel; settles at 56 px
/// while loading; «done» is shown 900 ms then collapses. Old content stays visible.
///
/// Drop-in for `RefreshIndicator(onRefresh:, child:)`. [onRefresh] should complete when the
/// data is back; a thrown error ends the refresh like a completion (the screen keeps its old
/// data and shows its own error pattern).
class SeenRefresh extends StatelessWidget {
  const SeenRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.colors = const SeenLoaderColors(),
    this.notificationPredicate,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final SeenLoaderColors colors;

  /// Forwarded to the engine; null = the engine default (the nearest scrollable).
  final bool Function(ScrollNotification)? notificationPredicate;

  static const double armedOffset = 72;
  static const double loadingOffset = 56;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      notificationPredicate:
          notificationPredicate ?? defaultScrollNotificationPredicate,
      offsetToArmed: armedOffset,
      durations: const RefreshIndicatorDurations(
        completeDuration: Duration(milliseconds: 900),
        finalizeDuration: Duration(milliseconds: 250),
      ),
      onStateChanged: (change) {
        if (change.didChange(to: IndicatorState.armed)) {
          HapticFeedback.lightImpact();
        }
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
          final v = math.min(math.max(controller.value, 0.0), 1.5);
          // The content moves down by the indicator's travel; settled height while loading/done.
          final double offset;
          if (controller.isLoading ||
              controller.isSettling ||
              controller.isComplete) {
            offset = loadingOffset + 30;
          } else if (controller.isFinalizing) {
            offset = v * (loadingOffset + 30);
          } else {
            offset = v * (armedOffset + 30);
          }
          final label = switch (stage) {
            SeenRefreshStage.pull => s.refreshPull,
            SeenRefreshStage.armed => s.refreshArmed,
            SeenRefreshStage.loading => s.refreshLoading,
            SeenRefreshStage.done => s.refreshDone,
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
                        child: ExcludeSemantics(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SeenRefreshBubble(
                                  stage: stage, pull: v, colors: colors),
                              const SizedBox(height: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 16 / 12,
                                  fontWeight: stage == SeenRefreshStage.armed
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: switch (stage) {
                                    SeenRefreshStage.done => c.successFg,
                                    SeenRefreshStage.armed =>
                                      SeenBrand.refreshArmedLabel,
                                    _ => c.inkSecondary,
                                  },
                                ),
                              ),
                            ],
                          ),
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
