// Draft card (Figma REQ-02): a dashed white card with the "Draft" chip, the
// service and traveler count, what is still missing (amber), and Continue /
// Delete with the age (or the deletion warning) at the end.
import 'package:flutter/material.dart';

import '../../../../core/presentation/widgets/dashed_border.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenDraftCard extends StatelessWidget {
  const SeenDraftCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.chipLabel,
    required this.iconAsset,
    required this.continueLabel,
    required this.deleteLabel,
    required this.ageLabel,
    this.missingLine,
    this.expiryLabel,
    this.onContinue,
    this.onDelete,
  });

  final String title;
  final String subtitle;
  final String chipLabel;
  final String iconAsset;
  final String continueLabel;
  final String deleteLabel;

  /// "Edited 2 hours ago".
  final String ageLabel;

  /// Amber "Missing: …" line; null for a complete draft.
  final String? missingLine;

  /// Red "Deleted in 2 days" in place of the age, when the end is near.
  final String? expiryLabel;
  final VoidCallback? onContinue;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final amber = SeenRequestStatus.actionRequired.colors;
    final urgent = SeenRequestStatus.deadlineUnder24h.colors;
    return Semantics(
      container: true,
      label: '$title. $subtitle. ${missingLine ?? ''}',
      child: SeenDashedBorder(
        color: c.borderStrong,
        radius: SeenRadius.r22.x,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.all(SeenRadius.r22),
            boxShadow: SeenShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    DecoratedBox(
                      decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(SeenRadius.r12)),
                      child: SizedBox(width: 40, height: 40, child: Center(child: SeenSvgIcon(iconAsset, size: 22))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: t.label),
                          Text(subtitle, style: t.caption.copyWith(color: c.inkMuted)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SeenStatusChip(status: SeenRequestStatus.newRequest, label: chipLabel),
                  ],
                ),
                if (missingLine != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.info_rounded, size: 14, color: amber.fg),
                      const SizedBox(width: 6),
                      Expanded(child: Text(missingLine!, style: t.caption.copyWith(color: amber.fg))),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    _TonalButton(label: continueLabel, onTap: onContinue),
                    const SizedBox(width: 6),
                    _TextButton(label: deleteLabel, onTap: onDelete),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        expiryLabel ?? ageLabel,
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: expiryLabel != null ? urgent.fg : c.inkMuted),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TonalButton extends StatelessWidget {
  const _TonalButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: SeenBrand.violet10,
        borderRadius: const BorderRadius.all(SeenRadius.r14),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(SeenRadius.r14),
          child: SizedBox(
            height: 40,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: Text(label, style: t.label.copyWith(color: SeenBrand.violet))),
            ),
          ),
        ),
      ),
    );
  }
}

class _TextButton extends StatelessWidget {
  const _TextButton({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(SeenRadius.r14),
        child: SizedBox(
          height: 40,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(child: Text(label, style: t.label.copyWith(color: c.primaryInk))),
          ),
        ),
      ),
    );
  }
}
