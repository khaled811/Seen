// Traveler switcher (Figma BOOK-02): a 64 px tile per traveler (active, filled,
// with a problem) and a dashed "+" that adds one, up to the limit of a request.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/dashed_border.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import 'seen_traveler_chips.dart' show SeenTravelerState;
import '../../../../core/presentation/widgets/svg_icon.dart';

class SeenTravelerSwitcher extends StatefulWidget {
  const SeenTravelerSwitcher({
    super.key,
    required this.states,
    required this.activeIndex,
    required this.onSelected,
    this.onAdd,
  });

  /// One entry per traveler, in order.
  final List<SeenTravelerState> states;
  final int activeIndex;
  final ValueChanged<int> onSelected;

  /// null = no more travelers can be added (the "+" is shown disabled).
  final VoidCallback? onAdd;

  @override
  State<SeenTravelerSwitcher> createState() => _SeenTravelerSwitcherState();
}

class _SeenTravelerSwitcherState extends State<SeenTravelerSwitcher> {
  // Owned here, disposed in dispose().
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};

  @override
  void didUpdateWidget(covariant SeenTravelerSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeIndex != widget.activeIndex || oldWidget.states.length != widget.states.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keys[widget.activeIndex]?.currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(ctx, alignment: .5, duration: const Duration(milliseconds: 200));
        }
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    const radius = BorderRadius.all(SeenRadius.r14);

    Widget tile(int i) {
      final state = widget.states[i];
      final active = i == widget.activeIndex;
      final error = state == SeenTravelerState.error;
      final borderColor = error ? c.dangerFg : (active ? c.primary : c.border);
      final fg = active ? c.primary : c.inkSecondary;
      final icon = switch (state) {
        SeenTravelerState.done => SeenCheckGlyph(size: 16, color: SeenRequestStatus.completed.colors.fg),
        SeenTravelerState.error => Icon(SeenIcons.alert, size: 16, color: c.dangerFg),
        SeenTravelerState.empty => Icon(SeenIcons.user, size: 16, color: active ? c.primary : c.inkMuted),
      };
      return Semantics(
        button: true,
        selected: active,
        label: s.travelerShort(i + 1),
        child: Material(
          key: _keys.putIfAbsent(i, GlobalKey.new),
          color: active ? SeenBrand.violet10 : c.card,
          shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: borderColor)),
          child: InkWell(
            onTap: () => widget.onSelected(i),
            customBorder: const RoundedRectangleBorder(borderRadius: radius),
            child: SizedBox(
              width: 64,
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(s.travelerShort(i + 1), style: t.caption.copyWith(color: fg)),
                  const SizedBox(height: 2),
                  icon,
                ],
              ),
            ),
          ),
        ),
      );
    }

    final add = Semantics(
      button: true,
      enabled: widget.onAdd != null,
      label: s.addTraveler,
      child: Opacity(
        opacity: widget.onAdd == null ? 0.45 : 1,
        child: SeenDashedBorder(
          color: SeenBrand.violet60,
          radius: 14,
          strokeWidth: 1,
          child: InkWell(
            onTap: widget.onAdd,
            borderRadius: radius,
            child: SizedBox(
              width: 44,
              height: 64,
              child: Center(child: Text('+', style: t.h2.copyWith(color: c.primary))),
            ),
          ),
        ),
      ),
    );

    // The first traveler sits at the start edge, the "+" after the last one.
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < widget.states.length; i++) ...[tile(i), const SizedBox(width: 8)],
          add,
        ],
      ),
    );
  }
}
