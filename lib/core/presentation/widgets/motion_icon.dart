// MotionIcon — plays a bundled Lottie micro-interaction, falling back to a
// static Phosphor icon whenever the asset is missing or fails to parse.
// Owns its AnimationController end to end (created here, disposed here).
//
// Two playback modes, chosen by whether [value] is set:
//  - Two-state toggle (e.g. an eye open/closed, a bell on/off): [value]
//    tracks external boolean state (like `Checkbox.value`). The icon jumps
//    straight to the matching frame on first build, then animates forward
//    when it flips to true and reverse when it flips back to false — it
//    never re-plays from frame 0 on every tap the way a one-shot would.
//  - One-shot (e.g. a download/refresh confirmation): [value] stays null;
//    a tap (or an external `SeenMotionIconState.play()` call, e.g. from a
//    parent's `onRefresh`) always plays once forward from frame 0. Never
//    loops on its own — the caller decides if/when to play it again.
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' as lottie;

class SeenMotionIcon extends StatefulWidget {
  const SeenMotionIcon({
    super.key,
    required this.asset,
    required this.fallbackIcon,
    this.size = 24,
    this.color,
    this.semanticLabel,
    this.value,
    this.onTap,
    this.tintAnimation = false,
  });

  /// Path under `assets/motion icons/`, e.g. `'assets/motion icons/refresh.json'`.
  final String asset;

  /// Shown in place of the animation whenever [asset] is missing or fails
  /// to parse — and as the icon itself before the composition has loaded.
  final IconData fallbackIcon;

  final double size;
  final Color? color;
  final String? semanticLabel;

  /// Two-state toggle mode — see the file-level doc comment. Leave null for
  /// a one-shot micro-interaction.
  final bool? value;

  /// When set, the icon becomes tappable and calls this after handling the
  /// tap (playing the one-shot animation, in that mode). Leave null for an
  /// icon only triggered externally via [SeenMotionIconState.play] (e.g. on
  /// pull-to-refresh), or when [value] is driven purely by the parent
  /// rebuilding with a new value.
  final VoidCallback? onTap;

  /// Paints every layer of the animation in [color] (for black artwork that must match the
  /// surface it sits on). Off by default: the animation keeps its own colours.
  final bool tintAnimation;

  @override
  State<SeenMotionIcon> createState() => SeenMotionIconState();
}

class SeenMotionIconState extends State<SeenMotionIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..value = widget.value == true ? 1 : 0;
  bool _ready = false;
  bool _failed = false;

  @override
  void didUpdateWidget(covariant SeenMotionIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == null || oldWidget.value == widget.value) return;
    if (!_ready || _failed) {
      // Composition not loaded yet (or failed) — jump straight there rather
      // than animating over an unknown/zero duration.
      _controller.value = widget.value! ? 1 : 0;
      return;
    }
    if (widget.value!) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Plays the animation once from the start. Safe to call unconditionally
  /// (e.g. from a parent's `onRefresh`) — no-ops before the composition has
  /// loaded, once it's known to have failed, or in two-state [value] mode
  /// (where playback is driven by [value] flipping, not by this).
  void play() {
    if (_ready && !_failed && widget.value == null) _controller.forward(from: 0);
  }

  void _handleTap() {
    if (widget.value == null) play();
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(widget.fallbackIcon, size: widget.size, color: widget.color, semanticLabel: widget.semanticLabel);

    final child = _failed
        ? fallback
        : SizedBox(
            width: widget.size,
            height: widget.size,
            child: lottie.Lottie.asset(
              widget.asset,
              controller: _controller,
              fit: BoxFit.contain,
              delegates: widget.tintAnimation && widget.color != null
                  ? lottie.LottieDelegates(values: [
                      lottie.ValueDelegate.colorFilter(['**'], value: ColorFilter.mode(widget.color!, BlendMode.srcATop)),
                    ])
                  : null,
              onLoaded: (composition) {
                if (!mounted) return;
                _controller.duration = composition.duration;
                _ready = true;
              },
              errorBuilder: (context, error, stackTrace) {
                // Defer to after this build — setState during the parent's
                // build (which is what triggered this errorBuilder) would
                // throw.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && !_failed) setState(() => _failed = true);
                });
                return fallback;
              },
            ),
          );

    if (widget.onTap == null) return child;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: widget.semanticLabel != null,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _handleTap, child: child),
    );
  }
}
