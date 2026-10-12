// Button · IconButton
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import 'motion_icon.dart';

/// Figma variants: primary (CTA gradient), secondary (#F3F0FD), outline,
/// dark, destructive. `ghost` and `dangerOutline` are legacy variants kept so
/// existing call sites compile; they use the new tokens.
enum SeenButtonVariant { primary, secondary, outline, dark, destructive, ghost, dangerOutline }

/// Figma sizes: regular = M (52, r16), small = S (40, r14), large = L (58, r20),
/// extraSmall = XS (32, pill).
enum SeenButtonSize { regular, small, large, extraSmall }

/// Button bound to the Figma tokens. One primary per screen; when money moves,
/// the label repeats the amount ("Confirm & submit hold · 270.00 USD"). A
/// disabled button always has its reason on screen.
///
/// States (all from the Figma Button component set):
///  * default  — variant fill (primary: [SeenBrand.gradientCta])
///  * pressed  — primary: solid `primaryHover`; others: variant pressed fill
///  * disabled ([onPressed] == null) — muted fill + violet-40 label
///  * loading  — default fill + 16px spinner before the label; taps are ignored.
///    The caller passes the loading label (e.g. "Please wait…").
class SeenButton extends StatefulWidget {
  const SeenButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SeenButtonVariant.primary,
    this.size = SeenButtonSize.regular,
    this.icon,
    this.expand = false,
    this.loading = false,
  });

  const SeenButton.secondary(
      {super.key,
      required this.label,
      this.onPressed,
      this.size = SeenButtonSize.regular,
      this.icon,
      this.expand = false,
      this.loading = false})
      : variant = SeenButtonVariant.secondary;

  const SeenButton.outline(
      {super.key,
      required this.label,
      this.onPressed,
      this.size = SeenButtonSize.regular,
      this.icon,
      this.expand = false,
      this.loading = false})
      : variant = SeenButtonVariant.outline;

  const SeenButton.dark(
      {super.key,
      required this.label,
      this.onPressed,
      this.size = SeenButtonSize.regular,
      this.icon,
      this.expand = false,
      this.loading = false})
      : variant = SeenButtonVariant.dark;

  const SeenButton.destructive(
      {super.key,
      required this.label,
      this.onPressed,
      this.size = SeenButtonSize.regular,
      this.icon,
      this.expand = false,
      this.loading = false})
      : variant = SeenButtonVariant.destructive;

  const SeenButton.ghost(
      {super.key,
      required this.label,
      this.onPressed,
      this.size = SeenButtonSize.regular,
      this.icon,
      this.expand = false,
      this.loading = false})
      : variant = SeenButtonVariant.ghost;

  const SeenButton.dangerOutline(
      {super.key,
      required this.label,
      this.onPressed,
      this.size = SeenButtonSize.regular,
      this.icon,
      this.expand = false,
      this.loading = false})
      : variant = SeenButtonVariant.dangerOutline;

  final String label;
  final VoidCallback? onPressed;
  final SeenButtonVariant variant;
  final SeenButtonSize size;
  final IconData? icon;

  /// Fill the available width (`block` on the web). Needs a bounded width:
  /// inside a Row, wrap the button in Expanded.
  final bool expand;

  /// Shows the spinner and blocks taps while keeping the default fill.
  final bool loading;

  @override
  State<SeenButton> createState() => _SeenButtonState();
}

typedef _ButtonPaint = ({Color? fill, Gradient? gradient, Color fg, BorderSide? side});

class _SeenButtonState extends State<SeenButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  /// Resolved paint for the current variant and state.
  _ButtonPaint _paint(SeenColors c, {required bool disabled}) {
    const outlineWidth = 1.5;
    switch (widget.variant) {
      case SeenButtonVariant.primary:
        if (disabled) {
          return (fill: SeenBrand.buttonDisabledBg, gradient: null, fg: SeenBrand.buttonDisabledFg, side: null);
        }
        if (_pressed) return (fill: c.primaryHover, gradient: null, fg: c.onPrimary, side: null);
        return (fill: null, gradient: SeenBrand.gradientCta, fg: c.onPrimary, side: null);
      case SeenButtonVariant.secondary:
        if (disabled) return (fill: SeenBrand.violet05, gradient: null, fg: SeenBrand.buttonDisabledFg, side: null);
        return (
          fill: _pressed ? SeenBrand.violet20 : SeenBrand.buttonSecondaryBg,
          gradient: null,
          fg: c.primaryInk,
          side: null
        );
      case SeenButtonVariant.outline:
        if (disabled) {
          return (
            fill: null,
            gradient: null,
            fg: SeenBrand.buttonDisabledFg,
            side: const BorderSide(color: SeenBrand.violet20, width: outlineWidth)
          );
        }
        return (
          fill: _pressed ? SeenBrand.violet05 : null,
          gradient: null,
          fg: c.primaryInk,
          side: const BorderSide(color: SeenBrand.buttonOutlineBorder, width: outlineWidth)
        );
      case SeenButtonVariant.dark:
        if (disabled) return (fill: SeenBrand.progressTodo, gradient: null, fg: c.inkMuted, side: null);
        return (
          fill: _pressed ? SeenBrand.buttonDarkPressedBg : SeenBrand.buttonDarkBg,
          gradient: null,
          fg: c.onPrimary,
          side: null
        );
      case SeenButtonVariant.destructive:
        if (disabled) {
          return (
            fill: SeenBrand.buttonDestructiveDisabledBg,
            gradient: null,
            fg: SeenBrand.buttonDestructiveDisabledFg,
            side: null
          );
        }
        return (
          fill: _pressed ? SeenBrand.buttonDestructivePressedBg : SeenBrand.buttonDestructiveBg,
          gradient: null,
          fg: SeenBrand.buttonDestructiveFg,
          side: null
        );
      case SeenButtonVariant.ghost:
        return (
          fill: _pressed && !disabled ? SeenBrand.violet05 : null,
          gradient: null,
          fg: disabled ? c.inkDisabled : c.primaryInk,
          side: null
        );
      case SeenButtonVariant.dangerOutline:
        return (
          fill: _pressed && !disabled ? SeenBrand.buttonDestructiveBg : c.card,
          gradient: null,
          fg: disabled ? c.inkDisabled : c.dangerFg,
          side: BorderSide(color: disabled ? c.border : c.dangerFg.withAlpha(0x66), width: outlineWidth)
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final w = widget;
    final enabled = w.onPressed != null && !w.loading;
    final disabled = w.onPressed == null && !w.loading;
    final p = _paint(c, disabled: disabled);

    final (height, radius, textStyle, hPad, iconSize) = switch (w.size) {
      SeenButtonSize.regular => (SeenSize.button, SeenRadius.lg, type.buttonM, SeenSpace.s5, 18.0),
      SeenButtonSize.small => (SeenSize.buttonSm, SeenRadius.r14, type.buttonS, SeenSpace.s5, 16.0),
      SeenButtonSize.large => (SeenSize.buttonL, SeenRadius.r20, type.buttonL, SeenSpace.s5, 20.0),
      SeenButtonSize.extraSmall => (SeenSize.buttonXs, SeenRadius.full, type.buttonXs, 14.0, 14.0),
    };
    final shape = BorderRadius.all(radius);
    final style = textStyle.copyWith(color: p.fg);

    final content = Row(
      mainAxisSize: w.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (w.loading) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: p.fg),
          ),
          const SizedBox(width: SeenSpace.s2),
        ] else if (w.icon != null) ...[
          Icon(w.icon, size: iconSize, color: p.fg),
          const SizedBox(width: SeenSpace.s2),
        ],
        Flexible(child: Text(w.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style)),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: w.label,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            color: p.fill,
            gradient: p.gradient,
            borderRadius: shape,
            border: p.side == null ? null : Border.fromBorderSide(p.side!),
          ),
          child: InkWell(
            onTap: enabled ? w.onPressed : null,
            onHighlightChanged: enabled ? _setPressed : null,
            borderRadius: shape,
            splashColor: Colors.transparent, // pressed state is a fill change, not a ripple
            highlightColor: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height, minWidth: w.expand ? double.infinity : 0),
              child: Padding(
                padding: EdgeInsetsDirectional.symmetric(horizontal: hPad),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
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

/// 44px circular icon button from the Figma header (back, chat, plus, …).
/// `tonal` = violet-10 fill (back / add); default = white with a 1px line and
/// the card shadow (chat, support). The glyph is the brand violet.
class SeenRoundIconButton extends StatelessWidget {
  const SeenRoundIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.tonal = false,
    this.size = 44,
    this.iconSize = 22,
  });

  final IconData icon;

  /// Accessible name — required.
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool tonal;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: tonal ? c.primarySoft : c.card,
            border: tonal ? null : Border.all(color: c.border),
            boxShadow: tonal ? null : SeenShadows.card,
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Center(child: Icon(icon, size: iconSize, color: c.primary)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Inline Figma text link: Label 13/20 Medium in the link color (`primaryInk`),
/// no underline. 44px minimum tap height. Sits at the reading start of its row.
class SeenTextLink extends StatelessWidget {
  const SeenTextLink({super.key, required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final style = SeenType.of(context).label.copyWith(color: onTap == null ? c.inkDisabled : c.primaryInk);
    return Semantics(
      link: true,
      button: true,
      enabled: onTap != null,
      excludeSemantics: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(SeenRadius.xs),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SeenSize.touchMin - 4),
          child: Center(widthFactor: 1, child: Text(label, style: style)),
        ),
      ),
    );
  }
}
