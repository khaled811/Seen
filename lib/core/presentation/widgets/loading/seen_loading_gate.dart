// SeenLoadingGate: the show-delay / minimum-visible policy of SPEC section 9.
// Nothing new for the first 300 ms (a fast answer never flashes a skeleton); once shown, the
// loading widget stays at least 500 ms (no flicker). Timers are owned here and cancelled in
// dispose.
import 'dart:async';

import 'package:flutter/widgets.dart';

class SeenLoadingGate extends StatefulWidget {
  const SeenLoadingGate(
      {super.key,
      required this.isLoading,
      required this.loading,
      required this.child});

  final bool isLoading;

  /// Shown once [isLoading] has stayed true for [showDelay].
  final Widget loading;

  /// Shown when nothing is loading. While the delay runs, [child] stays too if it was visible.
  final Widget child;

  static const showDelay = Duration(milliseconds: 300);
  static const minVisible = Duration(milliseconds: 500);

  @override
  State<SeenLoadingGate> createState() => _SeenLoadingGateState();
}

class _SeenLoadingGateState extends State<SeenLoadingGate> {
  bool _showing = false;
  DateTime? _shownAt;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isLoading) _scheduleShow();
  }

  @override
  void didUpdateWidget(SeenLoadingGate old) {
    super.didUpdateWidget(old);
    if (widget.isLoading && !old.isLoading) _scheduleShow();
    if (!widget.isLoading && old.isLoading) _scheduleHide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleShow() {
    _timer?.cancel();
    _timer = Timer(SeenLoadingGate.showDelay, () {
      if (!mounted || !widget.isLoading) return;
      setState(() {
        _showing = true;
        _shownAt = DateTime.now();
      });
    });
  }

  void _scheduleHide() {
    _timer?.cancel();
    if (!_showing) return;
    final left =
        SeenLoadingGate.minVisible - DateTime.now().difference(_shownAt!);
    if (left <= Duration.zero) {
      _showing = false;
      return;
    }
    _timer = Timer(left, () {
      if (mounted && !widget.isLoading) setState(() => _showing = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_showing) return widget.loading;
    // Waiting out the first 300 ms: keep the previous content (nothing on a first load).
    if (widget.isLoading) return const SizedBox.shrink();
    return widget.child;
  }
}
