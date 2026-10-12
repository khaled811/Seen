import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';
import 'spiritual_nav_item.dart';

class SpiritualNavDestination {
  const SpiritualNavDestination({required this.icon, required this.label});

  final IconData icon;
  final String label;
}

/// Hub bottom navigation: white, 1 px top border, bottom inset for the home
/// indicator.
class SpiritualBottomNav extends StatelessWidget {
  const SpiritualBottomNav({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<SpiritualNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border(top: BorderSide(color: t.borderControl)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SpiritualSpace.s8,
            vertical: SpiritualSpace.s4,
          ),
          child: Row(
            children: [
              for (var i = 0; i < destinations.length; i++)
                Expanded(
                  child: SpiritualNavItem(
                    icon: destinations[i].icon,
                    label: destinations[i].label,
                    selected: i == selectedIndex,
                    onTap: () => onSelected(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
