// Loading skeletons (Figma SYS-06): grey placeholder shapes with one shared, calm pulse
// (1.6 s). With "reduce motion" on they are drawn still. One [SeenSkeletonGroup] owns the
// single controller for every box inside it, so a screen full of bars costs one ticker.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';

const _skeletonColors = [Color(0xFFEFEBF8), Color(0xFFF7F5FC)];

/// How long one pulse (dim -> bright -> dim) takes.
const seenSkeletonPulse = Duration(milliseconds: 1600);

class _PulseScope extends InheritedWidget {
  const _PulseScope({required this.animation, required super.child});

  /// null = still (reduce motion, or no group around the box).
  final Animation<double>? animation;

  @override
  bool updateShouldNotify(_PulseScope old) => animation != old.animation;
}

/// Owns the pulse for the skeleton boxes below it. Created in initState, disposed in
/// dispose; stopped while "reduce motion" is on.
class SeenSkeletonGroup extends StatefulWidget {
  const SeenSkeletonGroup({super.key, required this.child});

  final Widget child;

  @override
  State<SeenSkeletonGroup> createState() => _SeenSkeletonGroupState();
}

class _SeenSkeletonGroupState extends State<SeenSkeletonGroup> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: seenSkeletonPulse);
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return _PulseScope(animation: still ? null : _curve, child: widget.child);
  }
}

/// One placeholder shape. Pulses with its [SeenSkeletonGroup]; still without one.
class SeenSkeletonBox extends StatelessWidget {
  const SeenSkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});

  /// null = as wide as the parent allows.
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final animation = context.dependOnInheritedWidgetOfExactType<_PulseScope>()?.animation;
    final box = DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.centerRight, end: Alignment.centerLeft, colors: _skeletonColors),
        borderRadius: BorderRadius.all(Radius.circular(radius)),
      ),
      child: SizedBox(width: width, height: height),
    );
    if (animation == null) {
      return box;
    }
    return FadeTransition(opacity: Tween<double>(begin: 0.55, end: 1).animate(animation), child: box);
  }
}

/// The balance card while the wallet loads (Figma SYS-06).
class SeenBalanceSkeleton extends StatelessWidget {
  const SeenBalanceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(SeenRadius.r24)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SeenSkeletonBox(width: 100, height: 10, radius: 5),
            SizedBox(height: 10),
            SeenSkeletonBox(width: 220, height: 30, radius: 8),
            SizedBox(height: 10),
            Row(
              children: [
                SeenSkeletonBox(width: 120, height: 24, radius: 12),
                SizedBox(width: 8),
                SeenSkeletonBox(width: 120, height: 24, radius: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A list card while its data loads: icon square, two lines, a pill and a rule.
class SeenCardSkeleton extends StatelessWidget {
  const SeenCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                SeenSkeletonBox(width: 40, height: 40, radius: 12),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SeenSkeletonBox(width: 140, height: 12),
                    SizedBox(height: 6),
                    SeenSkeletonBox(width: 90, height: 10, radius: 5),
                  ],
                ),
                Spacer(),
                SeenSkeletonBox(width: 80, height: 22, radius: 11),
              ],
            ),
            SizedBox(height: 10),
            SeenSkeletonBox(height: 5, radius: 3),
          ],
        ),
      ),
    );
  }
}

/// [count] card skeletons in a column, under one pulse, announced as "loading".
class SeenCardsSkeleton extends StatelessWidget {
  const SeenCardsSkeleton({super.key, this.count = 3, this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 24), this.label = ''});

  final int count;
  final EdgeInsetsGeometry padding;

  /// The accessible name ("loading"); callers pass the localized word.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      container: true,
      child: ExcludeSemantics(
        child: SeenSkeletonGroup(
          child: ListView(
            physics: const NeverScrollableScrollPhysics(),
            padding: padding,
            children: [
              for (var i = 0; i < count; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                const SeenCardSkeleton(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
