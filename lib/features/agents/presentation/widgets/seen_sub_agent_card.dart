// Sub-agent widgets for Figma 13 (node 18:722): the overview stat tile and the
// agent card (initial avatar, name and caption, status chip and balance).
import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

/// Overview stat: caption (11, secondary) over a 22 / bold value, r22 card.
class SeenAgentStatTile extends StatelessWidget {
  const SeenAgentStatTile(
      {super.key, required this.label, required this.value});

  final String label;

  /// Pre-formatted by the caller (Arabic-Indic count, or an isolated amount).
  final String value;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      container: true,
      label: '$label $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.all(SeenRadius.r22),
          border: Border.all(color: c.border),
          boxShadow: SeenShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.caption.copyWith(color: c.inkSecondary)),
              const SizedBox(height: 4),
              Text(value,
                  maxLines: 1,
                  style: t.h1.copyWith(fontFeatures: SeenFonts.tabular)),
            ],
          ),
        ),
      ),
    );
  }
}

class SeenSubAgentCard extends StatelessWidget {
  const SeenSubAgentCard({
    super.key,
    required this.name,
    required this.caption,
    required this.balance,
    required this.suspended,
    required this.statusLabel,
    this.onTap,
  });

  final String name;

  /// Short identity line under the name (the branch code; a left-to-right run).
  final String caption;

  /// Major units.
  final num balance;
  final bool suspended;
  final String statusLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r20);
    final initial = name.trim().isEmpty
        ? ''
        : String.fromCharCodes(name.trim().runes.take(1));
    final balanceText = SeenFormat.usd(balance);
    return Semantics(
      button: onTap != null,
      container: true,
      label: '$name $statusLabel $balanceText',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: const BoxDecoration(
            boxShadow: SeenShadows.card, borderRadius: radius),
        child: Material(
          color: c.card,
          shape: RoundedRectangleBorder(
              borderRadius: radius, side: BorderSide(color: c.border)),
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                        color: SeenBrand.violet10, shape: BoxShape.circle),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                          child: Text(initial,
                              style: t.title.copyWith(color: c.primary))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyStrong),
                        const SizedBox(height: 2),
                        Text(
                          SeenFormat.isolate(caption),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SeenStatusChip(
                        status: suspended
                            ? SeenRequestStatus.cancelled
                            : SeenRequestStatus.completed,
                        label: statusLabel,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        balanceText,
                        textDirection: TextDirection.ltr,
                        style: t.label.copyWith(
                            color: c.ink, fontFeatures: SeenFonts.tabular),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
