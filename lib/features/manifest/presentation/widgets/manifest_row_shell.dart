import 'package:flutter/material.dart';

import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';

/// One row of a manifest card. Rows are built lazily by a sliver, so the card's rounded
/// outline is drawn row by row: [first] rounds the top corners, [last] the bottom ones.
/// Each row has a uniform border; every row after the first is drawn 1 px up so the
/// borders between two rows merge into one line.
class ManifestRowShell extends StatelessWidget {
  const ManifestRowShell(
      {super.key,
      required this.first,
      required this.last,
      required this.child});

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    const r = SeenRadius.r22;
    final row = DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.vertical(
            top: first ? r : Radius.zero, bottom: last ? r : Radius.zero),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, first ? 16 : 12, 14, last ? 16 : 12),
        child: child,
      ),
    );
    return first
        ? row
        : Transform.translate(offset: const Offset(0, -1), child: row);
  }
}
