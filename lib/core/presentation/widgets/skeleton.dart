// Loading skeletons (Figma SYS-06): placeholder shapes under one shared sweep (the Seen
// loading system, see widgets/loading/seen_shimmer.dart): a highlight band crossing the
// whole region once every 1.4 s, right -> left in RTL. With "reduce motion" on they are drawn
// still. One [SeenSkeletonGroup] owns the single controller for every box inside it, so a
// screen full of bars costs one ticker.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import 'loading/seen_mark.dart';
import 'loading/seen_shimmer.dart';

/// Owns the sweep for the skeleton boxes below it. [onDark] switches to the white-on-gradient
/// colours (a skeleton on the balance card).
class SeenSkeletonGroup extends StatelessWidget {
  const SeenSkeletonGroup({super.key, required this.child, this.onDark = false});

  final Widget child;
  final bool onDark;

  @override
  Widget build(BuildContext context) => SeenShimmer(
        colors: onDark ? const SeenLoaderColors.onDark() : const SeenLoaderColors(),
        child: child,
      );
}

/// One placeholder shape. Sweeps with its [SeenSkeletonGroup]; still without one.
class SeenSkeletonBox extends StatelessWidget {
  const SeenSkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});

  /// null = as wide as the parent allows.
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => SkeletonBox(width: width, height: height, radius: radius);
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
