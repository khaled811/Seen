// SubAgentCard — Figma 13 sub-agent card: name and code, the assigned balance,
// an Active / Suspended badge and a "Fund" quick action.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenSubAgentCard extends StatelessWidget {
  const SeenSubAgentCard({
    super.key,
    required this.name,
    required this.code,
    required this.balance,
    required this.suspended,
    required this.statusLabel,
    required this.balanceLabel,
    required this.fundLabel,
    this.onFund,
  });

  final String name;

  /// Branch reference; shown as a left-to-right run.
  final String code;

  /// Major units.
  final num balance;
  final bool suspended;
  final String statusLabel;
  final String balanceLabel;
  final String fundLabel;
  final VoidCallback? onFund;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      container: true,
      label: '$name $statusLabel $balanceLabel ${SeenFormat.usd(balance)}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.all(SeenRadius.r22),
          border: Border.all(color: c.border),
          boxShadow: SeenShadows.card,
        ),
        child: Padding(
          padding: const EdgeInsets.all(SeenSpace.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(SeenRadius.r14)),
                    child: SizedBox(width: 44, height: 44, child: Icon(SeenIcons.building, size: 22, color: c.primary)),
                  ),
                  const SizedBox(width: SeenSpace.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                        Text(
                          SeenFormat.isolate(code),
                          textDirection: TextDirection.ltr,
                          style: t.caption.copyWith(color: c.inkMuted),
                        ),
                      ],
                    ),
                  ),
                  SeenStatusChip(
                    status: suspended ? SeenRequestStatus.cancelled : SeenRequestStatus.completed,
                    label: statusLabel,
                  ),
                ],
              ),
              const SizedBox(height: SeenSpace.s3),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(balanceLabel, style: t.caption.copyWith(color: c.inkMuted)),
                        Text(
                          SeenFormat.usd(balance),
                          textDirection: TextDirection.ltr,
                          style: t.h2.copyWith(fontFeatures: SeenFonts.tabular),
                        ),
                      ],
                    ),
                  ),
                  SeenButton.secondary(label: fundLabel, size: SeenButtonSize.small, icon: SeenIcons.wallet, onPressed: onFund),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
