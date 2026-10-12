import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../../domain/entities/hijri_date.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_icon_button.dart';

/// Location button, Hijri date pill and profile button.
class DashboardHeader extends StatelessWidget {
  const DashboardHeader({
    super.key,
    required this.city,
    required this.hijri,
    required this.onCityTap,
    required this.onProfileTap,
  });

  final String city;
  final HijriDate hijri;
  final VoidCallback onCityTap;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Flexible(
            flex: 3,
            child: PressScale(
              onTap: onCityTap,
              semanticLabel: '${SpiritualStrings.changeCity}: $city',
              borderRadius: BorderRadius.circular(SpiritualRadius.control),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: SpiritualSpace.minTap,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined, size: 22, color: t.accent),
                      const SizedBox(width: SpiritualSpace.s6),
                      Flexible(
                        child: Text(
                          city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SpiritualType.bodyStrong.copyWith(
                            color: t.inkPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: SpiritualSpace.s6),
                      Icon(Icons.expand_more, size: 18, color: t.inkMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: SpiritualSpace.s8),
          Flexible(
            flex: 2,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: t.borderControl),
                  ),
                  child: Text(
                    toArabicDigits(
                      '${hijri.day} ${hijri.monthName} ${hijri.year}',
                    ),
                    style: SpiritualType.caption.copyWith(color: t.inkBody),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: SpiritualSpace.s8),
          SpiritualIconButton(
            icon: Icons.person_outline,
            semanticLabel: SpiritualStrings.profileSettings,
            onPressed: onProfileTap,
          ),
        ],
      ),
    );
  }
}
