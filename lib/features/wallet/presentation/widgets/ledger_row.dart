// LedgerRow — one wallet ledger entry (Figma 11). A tinted icon tile, the
// transaction title with its reference / time, and the signed amount as an
// explicit left-to-right run ("+500.00 USD"). Credits are green, debits ink.
// Arrows are never mirrored. Place rows inside a SeenListGroup.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/presentation/widgets/status.dart';

enum SeenLedgerType { credit, debit }

class SeenLedgerRow extends StatelessWidget {
  const SeenLedgerRow({
    super.key,
    required this.type,
    required this.title,
    required this.reference,
    required this.time,
    required this.amount,
    this.icon,
    this.status,
    this.statusLabel,
    this.onTap,
  });

  final SeenLedgerType type;
  final String title;
  final String reference;
  final String time;

  /// Major units (dollars), always positive; [type] decides the sign.
  final num amount;

  /// Overrides the default arrow-in / arrow-out glyph.
  final IconData? icon;

  /// Only shown when set (approved is the resting state and stays silent).
  final SeenRequestStatus? status;
  final String? statusLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final credit = type == SeenLedgerType.credit;
    final amountText = SeenFormat.isolate('${SeenFormat.signed(amount, credit: credit)} USD');
    final meta = [if (reference.isNotEmpty) SeenFormat.isolate(reference), time].join('  ·  ');
    return Semantics(
      container: true,
      label: '$title $amountText${statusLabel == null ? '' : ' $statusLabel'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: SeenSpace.s3),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: credit ? c.successBg : SeenBrand.violet05,
                  borderRadius: const BorderRadius.all(SeenRadius.r14),
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    icon ?? (credit ? SeenIcons.credit : SeenIcons.debit),
                    size: 20,
                    color: credit ? c.successFg : c.primary,
                  ),
                ),
              ),
              const SizedBox(width: SeenSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyStrong),
                    const SizedBox(height: 2),
                    Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: SeenSpace.s2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    textDirection: TextDirection.ltr,
                    style: t.bodyStrong.copyWith(
                      color: credit ? c.successFg : c.ink,
                      fontFeatures: SeenFonts.tabular,
                    ),
                  ),
                  if (status != null && statusLabel != null) ...[
                    const SizedBox(height: 4),
                    SeenStatusChip(status: status!, label: statusLabel!),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
