// Loader — app-wide loading indicator, replacing the plain
// CircularProgressIndicator with the bundled `loadingV2.json` motion icon.
// Unlike SeenMotionIcon (one-shot or two-state toggle), this one genuinely
// loops for as long as it's on screen — that's what a loading spinner is
// supposed to do — and stops the instant it's removed from the tree
// (AnimationController is disposed in dispose(), same as everywhere else).
// Falls back to a real CircularProgressIndicator if the asset is missing or
// fails to parse, so a loading state never renders blank.
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart' as lottie;

import '../foundation/seen_motion_icons.dart';

class SeenLoader extends StatefulWidget {
  const SeenLoader({super.key, this.size = 40, this.color});

  final double size;
  final Color? color;

  @override
  State<SeenLoader> createState() => _SeenLoaderState();
}

class _SeenLoaderState extends State<SeenLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  bool _failed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _fallback() =>
      SizedBox(width: widget.size, height: widget.size, child: CircularProgressIndicator(strokeWidth: 3, color: widget.color));

  @override
  Widget build(BuildContext context) {
    if (_failed) return _fallback();
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: lottie.Lottie.asset(
        SeenMotionIcons.loading,
        controller: _controller,
        fit: BoxFit.contain,
        onLoaded: (composition) {
          if (!mounted) return;
          _controller
            ..duration = composition.duration
            ..repeat();
        },
        errorBuilder: (context, error, stackTrace) {
          // Defer to after this build — setState during the parent's build
          // (which is what triggered this errorBuilder) would throw.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_failed) setState(() => _failed = true);
          });
          return _fallback();
        },
      ),
    );
  }
}
