// SubAgentRow — branch row in the sub-agent directory. Place inside a
// SeenListGroup.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/avatar.dart';
import '../../../../core/presentation/widgets/tag.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenSubAgentRow extends StatelessWidget {
  const SeenSubAgentRow({
    super.key,
    required this.name,
    required this.city,
    this.users,
    required this.marginLabel,
    required this.balance,
    this.suspended = false,
    this.onTap,
  });

  final String name;

  /// City, or any other short location/identity string (e.g. a branch code)
  /// when the caller has no city on hand.
  final String city;

  /// Omit when the caller has no per-branch user count — [city] is then
  /// shown alone rather than a fabricated "0 users".
  final int? users;

  /// "+5.00 / traveler" or "8%".
  final String marginLabel;
  final num balance;
  final bool suspended;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: SeenSpace.s3),
        child: Row(children: [
          SeenAvatar(icon: SeenIcons.building, square: true),
          const SizedBox(width: SeenSpace.s3),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(name, style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600))),
                if (suspended) ...[const SizedBox(width: 6), SeenTag(s.suspended, muted: true)],
              ]),
              const SizedBox(height: 2),
              Wrap(
                spacing: SeenSpace.s2,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(users != null ? '$city · ${s.users(users!)}' : city, style: text.labelSmall),
                  SeenTag(s.margin(marginLabel)),
                ],
              ),
            ]),
          ),
          const SizedBox(width: SeenSpace.s2),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(s.balance, style: text.labelSmall),
            Text(SeenFormat.money(balance),
                textDirection: TextDirection.ltr, style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600, fontFeatures: SeenFonts.tabular)),
          ]),
        ]),
      ),
    );
  }
}
