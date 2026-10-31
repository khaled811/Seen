// The wait policy of SPEC section 9 for a first-load region:
//   0-300 ms  nothing new (SeenLoadingGate)      >= 300 ms  the skeleton
//   10 s      the slow banner over the skeleton  30 s / cancel  the timeout card
// The skeleton keeps running under the banner. The timers belong to this State and are
// cancelled in dispose. A retry restarts the clock.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../theme/seen_colors.dart';
import '../../../theme/seen_dimensions.dart';
import '../../../theme/seen_typography.dart';
import '../../foundation/seen_icons.dart';
import '../../foundation/seen_strings.dart';
import '../actions.dart';
import 'loading_strings.dart';
import 'seen_loader.dart';
import 'seen_loading_gate.dart';

class SeenWaitPolicy extends StatefulWidget {
  const SeenWaitPolicy({
    super.key,
    required this.isLoading,
    required this.loading,
    required this.child,
    required this.onRetry,
    this.onCancel,
    this.slowAfter = const Duration(seconds: 10),
    this.timeoutAfter = const Duration(seconds: 30),
    this.errorCode = 'ERR_TIMEOUT',
  });

  /// A branch of a state switch that is shown only while loading: the policy runs for as long
  /// as this widget is mounted (the screen replaces it when the state changes).
  const SeenWaitPolicy.loading({
    super.key,
    required this.loading,
    required this.onRetry,
    this.onCancel,
    this.slowAfter = const Duration(seconds: 10),
    this.timeoutAfter = const Duration(seconds: 30),
    this.errorCode = 'ERR_TIMEOUT',
  })  : isLoading = true,
        child = const SizedBox.shrink();

  /// True while the region has nothing to show yet and a request is running.
  final bool isLoading;

  /// The skeleton of the region (built from the screen's own widgets).
  final Widget loading;

  /// The loaded content (or whatever the screen shows when it is not loading).
  final Widget child;

  /// Reload. Called by the timeout card's retry button.
  final VoidCallback onRetry;

  /// Called when the user cancels from the slow banner (the screen may abort its request).
  final VoidCallback? onCancel;

  final Duration slowAfter;
  final Duration timeoutAfter;
  final String errorCode;

  @override
  State<SeenWaitPolicy> createState() => _SeenWaitPolicyState();
}

class _SeenWaitPolicyState extends State<SeenWaitPolicy> {
  Timer? _slowTimer;
  Timer? _timeoutTimer;
  bool _slow = false;
  bool _timedOut = false;

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) _start();
  }

  @override
  void didUpdateWidget(SeenWaitPolicy old) {
    super.didUpdateWidget(old);
    if (widget.isLoading && !old.isLoading) _start();
    if (!widget.isLoading && old.isLoading) _stop();
  }

  @override
  void dispose() {
    _slowTimer?.cancel();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _start() {
    _slowTimer?.cancel();
    _timeoutTimer?.cancel();
    _slow = false;
    _timedOut = false;
    _slowTimer = Timer(widget.slowAfter, () {
      if (mounted && widget.isLoading) setState(() => _slow = true);
    });
    _timeoutTimer = Timer(widget.timeoutAfter, () {
      if (mounted && widget.isLoading) setState(() => _timedOut = true);
    });
  }

  void _stop() {
    _slowTimer?.cancel();
    _timeoutTimer?.cancel();
    _slow = false;
    _timedOut = false;
  }

  void _cancel() {
    widget.onCancel?.call();
    setState(() => _timedOut = true);
  }

  void _retry() {
    setState(_start);
    widget.onRetry();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && _timedOut) {
      return SeenTimeoutState(
          onRetry: _retry,
          errorCode: widget.errorCode,
          seconds: widget.timeoutAfter.inSeconds);
    }
    final loading = _slow
        ? LayoutBuilder(
            builder: (context, box) => Stack(
              // A bounded region is filled so the banner is always inside the hit area; in an
              // unbounded one (a list child) the skeleton sets the size.
              fit:
                  box.hasBoundedHeight ? StackFit.expand : StackFit.passthrough,
              children: [
                widget.loading,
                Positioned(
                  top: 8,
                  left: 14,
                  right: 14,
                  child: SeenSlowBanner(onCancel: _cancel),
                ),
              ],
            ),
          )
        : widget.loading;
    return SeenLoadingGate(
        isLoading: widget.isLoading, loading: loading, child: widget.child);
  }
}

/// «الاتصال بطيء — ما زلنا نحاول (١٢ ث)» with a loader in amber and a cancel link.
class SeenSlowBanner extends StatefulWidget {
  const SeenSlowBanner(
      {super.key, required this.onCancel, this.startSeconds = 10});

  final VoidCallback onCancel;

  /// The count starts here (the banner appears after this many seconds).
  final int startSeconds;

  @override
  State<SeenSlowBanner> createState() => _SeenSlowBannerState();
}

class _SeenSlowBannerState extends State<SeenSlowBanner> {
  // Owned here; created in initState, cancelled in dispose.
  Timer? _tick;
  late int _seconds = widget.startSeconds;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
            color: c.pendingBg,
            borderRadius: const BorderRadius.all(SeenRadius.r18)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              SeenLoader(size: 20, color: c.pendingFg),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: s.slowTitle,
                        style: t.label.copyWith(
                            color: c.pendingFg, fontWeight: FontWeight.w700)),
                    TextSpan(
                        text: ' — ${s.slowBanner(_seconds)}',
                        style: t.caption.copyWith(color: c.pendingFg)),
                  ]),
                ),
              ),
              TextButton(
                onPressed: widget.onCancel,
                style: TextButton.styleFrom(
                    foregroundColor: c.pendingFg,
                    minimumSize: const Size(48, 40)),
                child: Text(s.waitCancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The timeout card: a 84 dp danger tile with a clock, the reason, a retry button and a small
/// LTR error code. Replaces the skeleton; nothing the user typed is lost (it only replaces a
/// first-load region).
class SeenTimeoutState extends StatelessWidget {
  const SeenTimeoutState(
      {super.key,
      required this.onRetry,
      this.errorCode = 'ERR_TIMEOUT',
      this.seconds = 30});

  final VoidCallback onRetry;
  final String errorCode;
  final int seconds;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                  color: c.dangerBg,
                  borderRadius: const BorderRadius.all(SeenRadius.r24)),
              child: SizedBox(
                  width: 84,
                  height: 84,
                  child: Icon(SeenIcons.clock, size: 40, color: c.dangerFg)),
            ),
            const SizedBox(height: 18),
            Text(s.timeoutTitle, textAlign: TextAlign.center, style: t.h2),
            const SizedBox(height: 8),
            Text(s.timeoutBody(seconds),
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: c.inkSecondary)),
            const SizedBox(height: 20),
            SeenButton(label: s.retryAction, expand: true, onPressed: onRetry),
            const SizedBox(height: 12),
            Directionality(
              textDirection: TextDirection.ltr,
              child:
                  Text(errorCode, style: t.caption.copyWith(color: c.inkMuted)),
            ),
          ],
        ),
      ),
    );
  }
}
