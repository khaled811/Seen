// TopBar · BottomNav · ActionBar · SectionHeader · ProgressRule · ListGroup
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';
import '../foundation/seen_motion_icons.dart';
import '../foundation/seen_strings.dart';
import '../foundation/seen_vectors.dart';
import 'actions.dart';
import 'svg_icon.dart';

/// 56px app bar. `.home` = org identity + language + bell (no page title);
/// `.inner` = back, centered title + subtitle (step or reference), trailing action.
class SeenTopBar extends StatelessWidget implements PreferredSizeWidget {
  const SeenTopBar.home({
    super.key,
    required String this.company,
    required String this.agentId,
    this.unread = 0,
    this.onLanguage,
    this.onNotifications,
    this.themeIcon,
    this.themeSemanticLabel,
    this.onThemeToggle,
  })  : title = null,
        subtitle = null,
        onBack = null,
        trailing = null,
        showBack = true;

  const SeenTopBar.inner({
    super.key,
    required String this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.showBack = true,
  })  : company = null,
        agentId = null,
        unread = 0,
        onLanguage = null,
        onNotifications = null,
        themeIcon = null,
        themeSemanticLabel = null,
        onThemeToggle = null;

  final String? company;
  final String? agentId;
  final int unread;
  final VoidCallback? onLanguage;
  final VoidCallback? onNotifications;

  /// Shown as a third icon when both this and [onThemeToggle] are set — the
  /// caller owns the ThemeMode read, this bar stays Bloc-agnostic.
  final IconData? themeIcon;
  final String? themeSemanticLabel;
  final VoidCallback? onThemeToggle;
  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  /// Hides the back button when the screen is a tab, not a pushed route.
  final bool showBack;

  @override
  Size get preferredSize => const Size.fromHeight(SeenSize.appBar);

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    final s = SeenStrings.of(context);

    final Widget bar;
    if (title == null) {
      bar = Padding(
        padding: const EdgeInsetsDirectional.only(start: SeenSpace.s4, end: SeenSpace.s2),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.primary, borderRadius: const BorderRadius.all(SeenRadius.sm)),
              child: Text(company!.isEmpty ? '' : company!.characters.first,
                  style: text.titleSmall!.copyWith(color: c.onPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            const SizedBox(width: SeenSpace.s3),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(company!, style: text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(agentId!, style: text.labelSmall, maxLines: 1),
                ],
              ),
            ),
            SeenIconButton(icon: SeenIcons.globe, semanticLabel: s.languageLabel, text: s.languageSwitch, onPressed: onLanguage),
            SeenIconButton(
              icon: SeenIcons.bell,
              semanticLabel: s.notifications,
              badge: unread,
              onPressed: onNotifications,
              motionAsset: SeenMotionIcons.notification,
              // Two-state toggle (the file's own name is
              // "notification-bell-on-off"), not a one-shot ring — true
              // when there's something unread. If the asset's frames turn
              // out reversed on screen, flip this to `unread == 0`.
              motionValue: unread > 0,
            ),
            if (themeIcon != null && onThemeToggle != null)
              SeenIconButton(icon: themeIcon!, semanticLabel: themeSemanticLabel ?? '', onPressed: onThemeToggle),
          ],
        ),
      );
    } else {
      bar = Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: SeenSpace.s1),
        child: Row(
          children: [
            if (showBack)
              SeenIconButton(
                icon: SeenIcons.back(context),
                glyph: const SeenBackGlyph(),
                semanticLabel: s.back,
                onPressed: onBack ?? () => Navigator.maybePop(context),
              )
            else
              const SizedBox(width: SeenSize.touchMin),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title!,
                      style: text.titleSmall!.copyWith(fontSize: 16, height: 22 / 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  if (subtitle != null) Text(subtitle!, style: text.labelSmall, maxLines: 1),
                ],
              ),
            ),
            trailing ?? const SizedBox(width: SeenSize.touchMin),
          ],
        ),
      );
    }

    return Material(
      color: c.card,
      child: DecoratedBox(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.border))),
        child: SafeArea(bottom: false, child: SizedBox(height: SeenSize.appBar, child: bar)),
      ),
    );
  }
}

/// Five-tab bottom navigation: Home, Requests, Wallet, Sub-agents, Account.
/// Flows (booking, detail) hide it and show a [SeenActionBar] instead.
/// The icon of the tab that is tapped (also the one already selected) does a short springy hop.
class SeenBottomNav extends StatefulWidget {
  const SeenBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.dimmed = const {},
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  /// Tabs the signed-in role cannot use: drawn faded (Figma ROLE-01). They still open,
  /// onto the no-permission view, so the reason is one tap away.
  final Set<int> dimmed;

  static const _icons = [
    SeenVectors.iconHome,
    SeenVectors.iconRequests,
    SeenVectors.iconWallet,
    SeenVectors.iconAgents,
    SeenVectors.iconAccount,
  ];

  @override
  State<SeenBottomNav> createState() => _SeenBottomNavState();
}

class _SeenBottomNavState extends State<SeenBottomNav> {
  /// Bumped per tap on a tab; its icon replays the hop when its number changes.
  final _taps = List<int>.filled(5, 0);

  void _select(int i) {
    setState(() => _taps[i]++);
    widget.onSelected(i);
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final labels = SeenStrings.of(context).nav;
    // Figma tab item: 22px glyph in a 56x30 pill (violet-10 when active),
    // 11px label — Regular muted when idle, Medium link color when active.
    return DecoratedBox(
      decoration: BoxDecoration(color: c.card, border: Border(top: BorderSide(color: c.border))),
      child: NavigationBarTheme(
        data: NavigationBarTheme.of(context).copyWith(
          backgroundColor: c.card,
          indicatorColor: c.primarySoft,
          indicatorShape: const StadiumBorder(),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final selected = states.contains(WidgetState.selected);
            return type.caption.copyWith(
              color: selected ? c.primaryInk : c.inkMuted,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: widget.selectedIndex,
          onDestinationSelected: _select,
          destinations: [
            for (var i = 0; i < 5; i++)
              Opacity(
                opacity: widget.dimmed.contains(i) ? .25 : 1,
                child: NavigationDestination(
                  icon: _TabHop(
                    tick: _taps[i],
                    child: SeenSvgIcon(SeenBottomNav._icons[i], color: SeenBrand.tabIconInactive),
                  ),
                  selectedIcon: _TabHop(
                    tick: _taps[i],
                    child: SeenSvgIcon(SeenBottomNav._icons[i], color: c.primary),
                  ),
                  label: labels[i],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A calm, playful tilt of a tab icon: it leans one way, sways back past upright, and settles
/// with a small rise and a soft grow (about 480 ms). Replays when [tick] changes; still with
/// "reduce motion". Owns one controller, disposed in dispose.
class _TabHop extends StatefulWidget {
  const _TabHop({required this.tick, required this.child});

  final int tick;
  final Widget child;

  @override
  State<_TabHop> createState() => _TabHopState();
}

class _TabHopState extends State<_TabHop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 480));

  /// Radians: lean, sway back the other way, then rest.
  static final _tilt = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -.22).chain(CurveTween(curve: Curves.easeOutCubic)), weight: 28),
    TweenSequenceItem(tween: Tween(begin: -.22, end: .14).chain(CurveTween(curve: Curves.easeInOutCubic)), weight: 32),
    TweenSequenceItem(tween: Tween(begin: .14, end: 0.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 40),
  ]);

  /// A soft grow and back.
  static final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1).chain(CurveTween(curve: Curves.easeOut)), weight: 35),
    TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 65),
  ]);

  /// A small rise and back.
  static final _lift = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut)), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeInOut)), weight: 60),
  ]);

  @override
  void didUpdateWidget(_TabHop old) {
    super.didUpdateWidget(old);
    if (old.tick != widget.tick && !MediaQuery.disableAnimationsOf(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = _c.value;
        return Transform.translate(
          offset: Offset(0, -2 * _lift.transform(t)),
          child: Transform.rotate(
            angle: _tilt.transform(t),
            child: Transform.scale(scale: _scale.transform(t), child: child),
          ),
        );
      },
    );
  }
}

/// Sticky bottom bar with the running summary and the screen's primary action.
/// Put it in `Scaffold.bottomNavigationBar`. Buttons share the width.
class SeenActionBar extends StatelessWidget {
  const SeenActionBar({super.key, this.summaryLabel, this.summaryAmount, required this.actions});

  /// e.g. "3 travelers × 85.00"
  final String? summaryLabel;

  /// e.g. SeenFormat.usd(255) — rendered LTR, 18/600.
  final String? summaryAmount;

  /// 1–2 [SeenButton]s. Each is expanded to share the width.
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      // Figma sticky actions: white bar, upward violet-tinted shadow.
      decoration: BoxDecoration(color: c.card, boxShadow: SeenShadows.stickyBar),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(20, 14, 20, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (summaryLabel != null || summaryAmount != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: SeenSpace.s3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Expanded(
                        child: Text(summaryLabel ?? '',
                            style: text.bodySmall!.copyWith(color: c.inkSecondary, fontWeight: FontWeight.w500)),
                      ),
                      if (summaryAmount != null)
                        Text(summaryAmount!,
                            textDirection: TextDirection.ltr,
                            style: seenStyle(18, 24, FontWeight.w600, c.ink).copyWith(fontFeatures: SeenFonts.tabular)),
                    ],
                  ),
                ),
              Row(
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: SeenSpace.s3),
                    Expanded(child: actions[i]),
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

/// Section label with an optional urgent count (terracotta pill) and trailing link.
/// Spacing: space-6 above, space-3 below.
class SeenSectionHeader extends StatelessWidget {
  const SeenSectionHeader({
    super.key,
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    this.padding = const EdgeInsets.only(top: SeenSpace.s6, bottom: SeenSpace.s3),
  });

  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Space around the row (24 above / 12 below by default).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding,
      child: Row(
        children: [
          // The title (and its count) takes all the room the link leaves, so the link sits at
          // the far end of the row. (A Flexible + Spacer pair split the free space in half and
          // left the link floating next to the title.)
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: Text(title, style: SeenType.of(context).h2)),
                  if (count != null) ...[
                    const SizedBox(width: SeenSpace.s2),
                    Container(
                      constraints: const BoxConstraints(minWidth: 20),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration:
                          BoxDecoration(color: c.dangerBg, borderRadius: const BorderRadius.all(SeenRadius.full)),
                      child: Text('$count',
                          textAlign: TextAlign.center,
                          style: text.labelMedium!.copyWith(color: c.dangerFg, height: 20 / 12)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(width: SeenSpace.s3),
            SeenTextLink(label: actionLabel!, onTap: onAction),
          ],
        ],
      ),
    );
  }
}

/// Underlined text link in primaryInk (14/600).
class SeenLink extends StatelessWidget {
  const SeenLink({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(SeenRadius.xs),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: SeenSize.touchMin),
        child: Center(
          widthFactor: 1,
          child: Text(label,
              style: seenStyle(14, 22, FontWeight.w600, c.primaryInk).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: c.primaryInk,
                decorationThickness: 1,
              )),
        ),
      ),
    );
  }
}

/// 3-segment flow progress under the top bar ("Step n of 3"), 3px, accent / border.
class SeenProgressRule extends StatelessWidget {
  const SeenProgressRule({super.key, required this.current, this.steps = 3});

  /// 1-based: segments <= current are filled.
  final int current;
  final int steps;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Row(
      children: [
        for (var i = 0; i < steps; i++) ...[
          if (i > 0) const SizedBox(width: SeenSpace.s1),
          Expanded(
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: i < current ? c.accent : c.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// One bordered container (radius-md) holding rows separated by 1px dividers.
/// Used by ledger rows, sub-agent rows, passenger rows, settings and notifications.
class SeenListGroup extends StatelessWidget {
  const SeenListGroup({super.key, required this.children});

  /// Rows and optional [SeenListGroupHeader]s. Dividers are drawn between rows,
  /// never directly above or below a header.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      final isHeader = children[i] is SeenListGroupHeader;
      final prevHeader = i > 0 && children[i - 1] is SeenListGroupHeader;
      if (i > 0 && !isHeader && !prevHeader) items.add(Divider(height: 1, color: c.border));
      items.add(children[i]);
    }
    // A Material (not a DecoratedBox) so row InkWells paint their ripple on the card.
    return Material(
      color: c.card,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(SeenRadius.md),
        side: BorderSide(color: c.border),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: items),
    );
  }
}

/// Date/group header inside a [SeenListGroup] ("Today", "Yesterday").
class SeenListGroupHeader extends StatelessWidget {
  const SeenListGroupHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Container(
      width: double.infinity,
      color: c.surface,
      padding: const EdgeInsetsDirectional.fromSTEB(SeenSpace.s4, SeenSpace.s4, SeenSpace.s4, SeenSpace.s2),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: c.inkMuted)),
    );
  }
}
