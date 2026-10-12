import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';
import 'press_scale.dart';

/// One bottom-navigation slot: 24 dp icon over a 13 sp label, 56 dp min height.
/// Active = accent + bold. Colours can be overridden so the shared mode bar
/// works on top of both the agent and the hub themes.
class SpiritualNavItem extends StatelessWidget {
  const SpiritualNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeColor,
    this.inactiveColor,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color? activeColor;
  final Color? inactiveColor;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final color =
        selected ? (activeColor ?? t.accent) : (inactiveColor ?? t.inkBody);
    return Semantics(
      selected: selected,
      child: PressScale(
        onTap: onTap,
        scale: 0.94,
        borderRadius: BorderRadius.circular(SpiritualRadius.control),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 56,
            minWidth: SpiritualSpace.minTap,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 24, color: color),
              const SizedBox(height: SpiritualSpace.s2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: SpiritualType.micro.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
