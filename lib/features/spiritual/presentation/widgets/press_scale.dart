import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';

/// Shared press behaviour for every tappable hub component: scale on pointer
/// down (docs/04 §Global), button semantics, a visible keyboard/switch-access
/// focus ring, and a minimum 48 dp hit area.
///
/// Not interactive when [onTap] is null.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.97,
    this.semanticLabel,
    this.borderRadius = BorderRadius.zero,
    this.onLongPress,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  /// Overrides the label read by screen readers. When null the child's own
  /// text is merged into the button.
  final String? semanticLabel;
  final BorderRadius borderRadius;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;
  bool _focused = false;

  bool get _enabled => widget.onTap != null;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    Widget content = AnimatedScale(
      scale: _down && _enabled ? widget.scale : 1,
      duration: SpiritualMotion.of(context, SpiritualMotion.press),
      curve: SpiritualMotion.pressCurve,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          border: _focused ? Border.all(color: t.accent, width: 2) : null,
        ),
        child: widget.child,
      ),
    );

    content = widget.semanticLabel != null
        ? ExcludeSemantics(child: content)
        : MergeSemantics(child: content);

    // One node for assistive tech: the button, its label, the tap action and
    // the focus node of FocusableActionDetector merged (otherwise screen
    // readers meet an extra unlabelled focus stop on every button).
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: _enabled,
        label: widget.semanticLabel,
        onTap: widget.onTap,
        child: FocusableActionDetector(
          enabled: _enabled,
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onTap?.call();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _enabled ? (_) => _set(true) : null,
            onTapUp: _enabled ? (_) => _set(false) : null,
            onTapCancel: _enabled ? () => _set(false) : null,
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            child: content,
          ),
        ),
      ),
    );
  }
}
