import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../../domain/utils/sun_position.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_card.dart';

/// Shown instead of the live compass when the device has no magnetometer: the
/// static Qibla angle from north, and where the sun is, so the user can find
/// north without a sensor.
class QiblaFallbackNote extends StatelessWidget {
  const QiblaFallbackNote({super.key, required this.bearing, required this.sun});

  final double bearing;
  final SunPosition? sun;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final up = sun != null && sun!.isUp;
    return SpiritualCard(
      radius: SpiritualRadius.tile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.explore_off_outlined, size: 24, color: t.accent),
              const SizedBox(width: SpiritualSpace.s10),
              Expanded(
                child: Text(
                  SpiritualStrings.noCompassTitle,
                  style: SpiritualType.bodyStrong.copyWith(color: t.inkPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: SpiritualSpace.s8),
          Text(
            SpiritualStrings.noCompassBody,
            style: SpiritualType.body.copyWith(color: t.inkBody),
          ),
          const SizedBox(height: SpiritualSpace.s12),
          Semantics(
            container: true,
            child: Text(
              toArabicDigits(
                '${SpiritualStrings.qiblaAngle}: ${bearing.round()}° '
                'من ${SpiritualStrings.northReference}، باتجاه عقارب الساعة',
              ),
              style: SpiritualType.bodyStrong.copyWith(color: t.accent),
            ),
          ),
          if (up) ...[
            const SizedBox(height: SpiritualSpace.s8),
            Row(
              children: [
                Icon(Icons.wb_sunny_outlined, size: 20, color: t.amber),
                const SizedBox(width: SpiritualSpace.s8),
                Expanded(
                  child: Text(
                    toArabicDigits(
                      'الشمس الآن باتجاه ${sun!.azimuth.round()}° من الشمال',
                    ),
                    style: SpiritualType.caption.copyWith(color: t.inkBody),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
