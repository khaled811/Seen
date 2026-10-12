// QuickAction (+ row) — generic home-dashboard tile grid. Domain-agnostic
// (icon/label/count/primary only, no wallet/service/request type), so it
// lives in core rather than any one feature's widgets.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';

/// Tile in the home quick-action row. Only one [primary] tile (navy icon) per row.
class SeenQuickAction extends StatelessWidget {
  const SeenQuickAction({super.key, required this.icon, required this.label, this.count = 0, this.primary = false, this.onTap});

  final IconData icon;
  final String label;
  final int count;
  final bool primary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Material(
      color: c.card,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(SeenRadius.md),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.md)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 92),
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s1, vertical: SeenSpace.s3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primary ? c.primary : c.primarySoft,
                        borderRadius: const BorderRadius.all(SeenRadius.sm),
                      ),
                      child: Icon(icon, size: 22, color: primary ? c.onPrimary : c.primaryInk),
                    ),
                    const SizedBox(height: SeenSpace.s2),
                    Text(label, textAlign: TextAlign.center, maxLines: 2, style: seenStyle(12, 16, FontWeight.w500, c.ink)),
                  ],
                ),
              ),
              if (count > 0)
                PositionedDirectional(top: SeenSpace.s2, end: SeenSpace.s2, child: _CountPill(count: count)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Four equal-width quick actions (equal heights), 8px gaps.
class SeenQuickActionRow extends StatelessWidget {
  const SeenQuickActionRow({super.key, required this.children});

  final List<SeenQuickAction> children;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: SeenSpace.s2),
            Expanded(child: children[i]),
          ],
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(color: c.accent, borderRadius: const BorderRadius.all(SeenRadius.full)),
      alignment: Alignment.center,
      child: Text(count > 99 ? '99+' : '$count', style: seenStyle(11, 18, FontWeight.w600, c.onPrimary)),
    );
  }
}
