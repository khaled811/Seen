// ApprovalCard — sub-agent booking waiting for the parent agent. Four facts
// in a 2x2 grid, Reject (danger-outline) | Approve (primary) at equal width.
// Reject must collect a reason; Approve should offer Undo for 5s.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_status.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/avatar.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenApprovalCard extends StatelessWidget {
  const SeenApprovalCard({
    super.key,
    required this.agentName,
    required this.branch,
    required this.timeAgo,
    required this.service,
    required this.travelers,
    required this.amount,
    this.margin,
    this.onApprove,
    this.onReject,
  });

  final String agentName;
  final String branch;
  final String timeAgo;
  final String service;
  final int travelers;
  final num amount;

  /// Omitted when the caller has no per-request margin figure — the amount
  /// fact then spans the full row rather than pairing with a fabricated one.
  final num? margin;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final s = SeenStrings.of(context);
    final text = Theme.of(context).textTheme;
    final dt = text.labelSmall!;
    final dd = seenStyle(14, 22, FontWeight.w600, c.ink).copyWith(fontFeatures: SeenFonts.tabular);

    Widget fact(String k, String v) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text(k, style: dt), Text(v, style: dd)],
        );

    return Container(
      padding: const EdgeInsets.all(SeenSpace.s4),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.md),
        border: Border.all(color: c.pendingLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            SeenAvatar(initial: agentName.isEmpty ? '' : agentName.characters.first),
            const SizedBox(width: SeenSpace.s3),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(agentName, style: text.titleMedium),
                Text('$branch · $timeAgo', style: text.labelSmall),
              ]),
            ),
            const SeenStatusBadge(status: SeenStatus.pending),
          ]),
          Container(
            margin: const EdgeInsets.symmetric(vertical: SeenSpace.s4),
            padding: const EdgeInsets.all(SeenSpace.s3),
            decoration: BoxDecoration(color: c.surface, borderRadius: const BorderRadius.all(SeenRadius.sm)),
            child: Column(children: [
              Row(children: [
                Expanded(child: fact(s.service, service)),
                const SizedBox(width: SeenSpace.s4),
                Expanded(child: fact(s.travelersLabel, '$travelers')),
              ]),
              const SizedBox(height: SeenSpace.s3),
              Row(children: [
                Expanded(child: fact(s.amount, SeenFormat.usd(amount))),
                if (margin != null) ...[
                  const SizedBox(width: SeenSpace.s4),
                  Expanded(child: fact(s.branchMargin, SeenFormat.isolate('+${SeenFormat.money(margin!)}'))),
                ],
              ]),
            ]),
          ),
          Row(children: [
            Expanded(
              child: SeenButton.dangerOutline(
                  label: s.reject, icon: SeenIcons.x, size: SeenButtonSize.small, expand: true, onPressed: onReject),
            ),
            const SizedBox(width: SeenSpace.s3),
            Expanded(
              child: SeenButton(
                  label: s.approve, icon: SeenIcons.check, size: SeenButtonSize.small, expand: true, onPressed: onApprove),
            ),
          ]),
        ],
      ),
    );
  }
}
