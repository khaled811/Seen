// Button · IconButton
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import 'motion_icon.dart';

enum SeenButtonVariant { primary, secondary, ghost, dangerOutline }

enum SeenButtonSize { regular, small }

/// Primary / secondary / ghost / danger-outline button. 52px (40px small), radius-sm.
/// One primary per screen; when money moves, the label repeats the amount
/// ("Confirm & submit hold · 270.00 USD"). A disabled button always has its reason on screen.
class SeenButton extends StatelessWidget {
  const SeenButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SeenButtonVariant.primary,
    this.size = SeenButtonSize.regular,
    this.icon,
    this.expand = false,
  });

  const SeenButton.secondary(
      {super.key, required this.label, this.onPressed, this.size = SeenButtonSize.regular, this.icon, this.expand = false})
      : variant = SeenButtonVariant.secondary;

  const SeenButton.ghost(
      {super.key, required this.label, this.onPressed, this.size = SeenButtonSize.regular, this.icon, this.expand = false})
      : variant = SeenButtonVariant.ghost;

  const SeenButton.dangerOutline(
      {super.key, required this.label, this.onPressed, this.size = SeenButtonSize.regular, this.icon, this.expand = false})
      : variant = SeenButtonVariant.dangerOutline;

  final String label;
  final VoidCallback? onPressed;
  final SeenButtonVariant variant;
  final SeenButtonSize size;
  final IconData? icon;

  /// Fill the available width (`block` on the web). Needs a bounded width:
  /// inside a Row, wrap the button in Expanded.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final small = size == SeenButtonSize.small;
    final height = small ? SeenSize.buttonSm : SeenSize.button;
    final textStyle = Theme.of(context).textTheme.labelLarge!.copyWith(fontSize: small ? 14 : 15);
    final sizing = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(expand ? double.infinity : 0, height)),
      padding: WidgetStatePropertyAll(
          EdgeInsetsDirectional.symmetric(horizontal: small ? SeenSpace.s4 : SeenSpace.s6)),
      textStyle: WidgetStatePropertyAll(textStyle),
    );

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: small ? 16 : 18), const SizedBox(width: SeenSpace.s2)],
        Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
      ],
    );

    return switch (variant) {
      SeenButtonVariant.primary => FilledButton(onPressed: onPressed, style: sizing, child: child),
      SeenButtonVariant.secondary => OutlinedButton(onPressed: onPressed, style: sizing, child: child),
      SeenButtonVariant.ghost => TextButton(onPressed: onPressed, style: sizing, child: child),
      SeenButtonVariant.dangerOutline => OutlinedButton(
          onPressed: onPressed,
          style: sizing.merge(OutlinedButton.styleFrom(
            foregroundColor: c.dangerFg,
            backgroundColor: c.card,
            side: BorderSide(color: c.dangerLine),
          )),
          child: child,
        ),
    };
  }
}

/// 48×48 icon-only button with an optional unread count (accent, 99+ cap) or short text ("EN").
class SeenIconButton extends StatefulWidget {
  const SeenIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.badge = 0,
    this.text,
    this.color,
    this.motionAsset,
    this.motionValue,
  });

  final IconData icon;

  /// Accessible name — required.
  final String semanticLabel;
  final VoidCallback? onPressed;
  final int badge;
  final String? text;
  final Color? color;

  /// Optional bundled Lottie micro-interaction (see [SeenMotionIcon]) shown
  /// in place of the static [icon]. Falls back to [icon] itself if the
  /// asset is missing or fails to parse.
  final String? motionAsset;

  /// Forwarded to [SeenMotionIcon.value]. Leave null for a one-shot
  /// animation played on every tap; set it to track external two-state
  /// boolean (e.g. "has unread") so the icon animates forward/reverse
  /// between two settled frames instead of always replaying from the start.
  final bool? motionValue;

  @override
  State<SeenIconButton> createState() => _SeenIconButtonState();
}

class _SeenIconButtonState extends State<SeenIconButton> {
  final _motionKey = GlobalKey<SeenMotionIconState>();

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final ink = widget.color ?? c.slate;
    final icon = widget.icon;
    final semanticLabel = widget.semanticLabel;
    final onPressed = widget.onPressed;
    final badge = widget.badge;
    final text = widget.text;
    Widget glyph = widget.motionAsset != null
        ? SeenMotionIcon(
            key: _motionKey,
            asset: widget.motionAsset!,
            fallbackIcon: icon,
            size: 22,
            color: ink,
            value: widget.motionValue,
          )
        : Icon(icon, size: 22, color: ink);
    if (badge > 0) {
      glyph = Badge(
        label: Text(badge > 99 ? '99+' : '$badge'),
        backgroundColor: c.accent,
        textColor: c.onPrimary,
        offset: const Offset(6, -6),
        child: glyph,
      );
    }
    return Semantics(
      button: true,
      label: badge > 0 ? '$semanticLabel ($badge)' : semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onPressed == null && widget.motionAsset == null
            ? null
            : () {
                _motionKey.currentState?.play();
                onPressed?.call();
              },
        borderRadius: const BorderRadius.all(SeenRadius.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: SeenSize.touchMin, minHeight: SeenSize.touchMin),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: SeenSpace.s2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                glyph,
                if (text != null) ...[
                  const SizedBox(width: SeenSpace.s1),
                  Text(text, style: Theme.of(context).textTheme.labelMedium!.copyWith(color: ink)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
