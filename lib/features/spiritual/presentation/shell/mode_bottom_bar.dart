import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../domain/entities/app_mode.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_nav_item.dart';
import 'agent_tab.dart';

/// Shared bottom bar of the dual-mode shell: a flip trigger for the other
/// workspace plus the tab set of the current one. The tab set cross-swaps
/// when the mode changes.
///
/// Colours come from the app's [SeenColors] (not the hub tokens) so the bar
/// stays correct in dark mode while the agent workspace is showing.
class ModeBottomBar extends StatelessWidget {
  const ModeBottomBar({
    super.key,
    required this.mode,
    required this.manasikTab,
    this.agentTabs = const [],
    this.agentIndex = 0,
    this.onAgentTab,
    this.onAccount,
    required this.onToggleMode,
    required this.onManasikTab,
  });

  final AppMode mode;
  final int manasikTab;
  final List<AgentTab> agentTabs;

  /// Selected agent tab: 0 = home, i = agentTabs[i - 1].
  final int agentIndex;
  final ValueChanged<int>? onAgentTab;

  /// Opens the account sheet; when set, the account tab does that instead of
  /// switching to an in-hub page.
  final void Function(BuildContext context)? onAccount;
  final VoidCallback onToggleMode;
  final ValueChanged<int> onManasikTab;

  static const _accountTab = 3;

  static const _manasikTabs = [
    (Icons.home_outlined, SpiritualStrings.navHome),
    (Icons.mosque_outlined, SpiritualStrings.navManasik),
    (Icons.menu_book_outlined, SpiritualStrings.navQuran),
    (Icons.person_outline, SpiritualStrings.navAccount),
  ];

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final duration = SpiritualMotion.of(context, SpiritualMotion.base);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        border: Border(top: BorderSide(color: c.border)),
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
              _ModeSwitchButton(mode: mode, onTap: onToggleMode),
              const SizedBox(width: SpiritualSpace.s4),
              Expanded(
                child: AnimatedSwitcher(
                  duration: duration,
                  switchInCurve: SpiritualMotion.baseCurve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(mode),
                    child: mode == AppMode.manasik
                        ? _manasikRow(context, c)
                        : _agentRow(context, c),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _manasikRow(BuildContext context, SeenColors c) => Row(
        children: [
          for (var i = 0; i < _manasikTabs.length; i++)
            Expanded(
              child: SpiritualNavItem(
                icon: _manasikTabs[i].$1,
                label: _manasikTabs[i].$2,
                selected: i == manasikTab,
                activeColor: c.accentInk,
                inactiveColor: c.inkSecondary,
                onTap: i == _accountTab && onAccount != null
                    ? () => onAccount!(context)
                    : () => onManasikTab(i),
              ),
            ),
        ],
      );

  /// Home followed by the app-supplied tabs; page tabs switch the content
  /// above this bar, action tabs (account) run their action.
  Widget _agentRow(BuildContext context, SeenColors c) => Row(
        children: [
          Expanded(
            child: SpiritualNavItem(
              icon: Icons.home_outlined,
              label: SeenStrings.of(context).nav.first,
              selected: agentIndex == 0,
              activeColor: c.accentInk,
              inactiveColor: c.inkSecondary,
              onTap: () => onAgentTab?.call(0),
            ),
          ),
          for (var i = 0; i < agentTabs.length; i++)
            Expanded(
              child: SpiritualNavItem(
                icon: agentTabs[i].icon,
                label: agentTabs[i].label,
                selected: agentIndex == i + 1,
                activeColor: c.accentInk,
                inactiveColor: c.inkSecondary,
                onTap: () => onAgentTab?.call(i + 1),
              ),
            ),
        ],
      );
}

class _ModeSwitchButton extends StatelessWidget {
  const _ModeSwitchButton({required this.mode, required this.onTap});

  final AppMode mode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    // Label names the workspace you will flip TO.
    final target = mode == AppMode.agent
        ? SpiritualStrings.modeManasik
        : SpiritualStrings.modeAgent;
    final radius = BorderRadius.circular(SpiritualRadius.button);
    return PressScale(
      onTap: onTap,
      borderRadius: radius,
      semanticLabel: '${SpiritualStrings.modeSwitchHint}: $target',
      child: Container(
        width: 96,
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
          horizontal: SpiritualSpace.s6,
          vertical: SpiritualSpace.s6,
        ),
        decoration: BoxDecoration(color: c.accentSoft, borderRadius: radius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flip, size: 22, color: c.accentInk),
            Text(
              target,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: SpiritualType.micro.copyWith(color: c.accentInk),
            ),
          ],
        ),
      ),
    );
  }
}
