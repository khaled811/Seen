import 'package:flutter/material.dart';

import '../../core/number_format.dart';
import '../../domain/entities/compass_reading.dart';
import '../../domain/utils/qibla_math.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_card.dart';

/// "المسافة إلى مكة" and "دقة البوصلة", side by side.
class QiblaInfoCards extends StatelessWidget {
  const QiblaInfoCards({
    super.key,
    required this.distanceKm,
    required this.accuracy,
    this.showAccuracy = true,
  });

  final double distanceKm;
  final CompassAccuracy accuracy;

  /// False when there is no compass (nothing to be accurate about).
  final bool showAccuracy;

  @override
  Widget build(BuildContext context) {
    if (!showAccuracy) return _DistanceCard(km: distanceKm);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _DistanceCard(km: distanceKm)),
          const SizedBox(width: SpiritualSpace.s12),
          Expanded(child: AccuracyCard(accuracy: accuracy)),
        ],
      ),
    );
  }
}

class _DistanceCard extends StatelessWidget {
  const _DistanceCard({required this.km});

  final double km;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return SpiritualCard(
      compact: true,
      radius: SpiritualRadius.tile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SpiritualStrings.distanceToMakkah,
            style: SpiritualType.caption.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: SpiritualSpace.s6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: SpiritualSpace.s6,
            children: [
              Text(
                formatThousands(km),
                style: SpiritualType.h2.copyWith(
                  fontSize: 26,
                  color: t.inkPrimary,
                ),
              ),
              Text(
                SpiritualStrings.kmUnit,
                style: SpiritualType.body.copyWith(
                  fontWeight: FontWeight.w700,
                  color: t.inkPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compass accuracy with three bars: excellent (sage), good (amber), poor
/// (accent).
class AccuracyCard extends StatelessWidget {
  const AccuracyCard({super.key, required this.accuracy});

  final CompassAccuracy accuracy;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final (label, color, bar, lit) = switch (accuracy) {
      CompassAccuracy.excellent => (SpiritualStrings.accExcellent, t.sage, t.sage, 3),
      CompassAccuracy.good => (SpiritualStrings.accGood, t.amber, t.amberBar, 2),
      CompassAccuracy.poor => (SpiritualStrings.accPoor, t.accent, t.accent, 1),
      CompassAccuracy.unknown => (SpiritualStrings.accUnknown, t.inkMuted, t.track, 0),
    };
    return SpiritualCard(
      compact: true,
      radius: SpiritualRadius.tile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            SpiritualStrings.compassAccuracy,
            style: SpiritualType.caption.copyWith(color: t.inkMuted),
          ),
          const SizedBox(height: SpiritualSpace.s6),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            spacing: SpiritualSpace.s10,
            runSpacing: SpiritualSpace.s4,
            children: [
              Text(
                label,
                style: SpiritualType.h2.copyWith(color: color),
              ),
              ExcludeSemantics(
                child: SizedBox(
                  height: 20,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 3),
                        Container(
                          width: 5,
                          height: const [8.0, 14.0, 20.0][i],
                          decoration: BoxDecoration(
                            color: i < lit ? bar : t.track,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "الكعبة المشرفة" with its coordinates and the calibrate button.
class KaabaCard extends StatelessWidget {
  const KaabaCard({super.key, required this.onCalibrate});

  final VoidCallback onCalibrate;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return SpiritualCard(
      radius: SpiritualRadius.tile,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  SpiritualStrings.kaabaName,
                  style: SpiritualType.label.copyWith(color: t.inkPrimary),
                ),
                const SizedBox(height: SpiritualSpace.s2),
                Text(
                  '${formatCoordinate(QiblaMath.kaabaLatitude, 'ش')} · '
                  '${formatCoordinate(QiblaMath.kaabaLongitude, 'ق')}',
                  style: SpiritualType.micro.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: t.inkBody,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: SpiritualSpace.s12),
          CalibrateButton(onPressed: onCalibrate),
        ],
      ),
    );
  }
}

class CalibrateButton extends StatelessWidget {
  const CalibrateButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final radius = BorderRadius.circular(SpiritualRadius.control);
    return PressScale(
      onTap: onPressed,
      borderRadius: radius,
      child: Container(
        constraints: const BoxConstraints(minHeight: SpiritualSpace.minTap),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: radius,
          border: Border.all(color: t.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.waves, size: 20, color: t.inkPrimary),
            const SizedBox(width: SpiritualSpace.s8),
            Text(
              SpiritualStrings.calibrate,
              style: SpiritualType.caption.copyWith(
                fontWeight: FontWeight.w700,
                color: t.inkPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
