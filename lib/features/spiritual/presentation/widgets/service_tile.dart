import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';
import 'press_scale.dart';

/// Dashboard service tile: icon in a 52 dp tinted circle over a centred label
/// (max 2 lines). The whole tile is the tap target.
class ServiceTile extends StatelessWidget {
  const ServiceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final radius = BorderRadius.circular(SpiritualRadius.tile);
    return PressScale(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s8, vertical: SpiritualSpace.s16),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: radius,
          border: Border.all(color: t.borderCard),
          boxShadow: SpiritualTokens.cardShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: t.accentTint, shape: BoxShape.circle),
              child: Icon(icon, color: t.accent, size: 26),
            ),
            const SizedBox(height: SpiritualSpace.s10),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: SpiritualType.label.copyWith(color: t.inkPrimary),
            ),
          ],
        ),
      ),
    );
  }
}
