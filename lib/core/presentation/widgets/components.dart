// Shared small components that screens used to draw by hand (Figma SYS-08): toast,
// list row, checkbox, switch, progress bar and count badge.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';
import 'svg_icon.dart';

// ───────────────────────── Toast ─────────────────────────

/// A short confirmation over the content, with an optional action ("Undo").
/// Shows through the nearest [ScaffoldMessenger], replacing the toast on screen.
void showSeenToast(
  BuildContext context, {
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        duration: duration,
        content: SeenToast(
          message: message,
          actionLabel: actionLabel,
          onAction: onAction == null
              ? null
              : () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  onAction();
                },
        ),
      ),
    );
}

class SeenToast extends StatelessWidget {
  const SeenToast({super.key, required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.all(SeenRadius.lg),
          border: Border.all(color: c.border),
          boxShadow: SeenShadows.stickyBar,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SeenCheckGlyph(size: 18, color: SeenRequestStatus.completed.colors.fg),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: t.label.copyWith(color: c.ink))),
              if (actionLabel != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: onAction,
                  borderRadius: const BorderRadius.all(SeenRadius.r14),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Text(actionLabel!, style: t.label.copyWith(color: c.primaryInk)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── List row ─────────────────────────

/// A tappable card row: icon tile, title, optional second line, and a chevron (or a
/// custom [trailing]).
class SeenListRow extends StatelessWidget {
  const SeenListRow({super.key, required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Replaces the chevron.
  final Widget? trailing;

  /// null = a plain, non-tappable row (no chevron).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.lg);
    return Semantics(
      button: onTap != null,
      container: true,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(color: c.card, borderRadius: radius, border: Border.all(color: c.border)),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(11))),
                    child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20, color: SeenBrand.violet)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: t.body),
                        if (subtitle != null) Text(subtitle!, style: t.caption.copyWith(color: c.inkMuted)),
                      ],
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else if (onTap != null)
                    Icon(SeenIcons.forward(context), size: 16, color: c.inkMuted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Checkbox ─────────────────────────

/// 22 px checkbox: empty, checked, or checked-and-disabled. [onChanged] null = disabled.
class SeenCheckbox extends StatelessWidget {
  const SeenCheckbox({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final enabled = onChanged != null;
    final fill = value ? (enabled ? SeenBrand.violet : SeenBrand.violet40) : c.card;
    return Semantics(
      checked: value,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        // A 44 px touch target around the 22 px box.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: const BorderRadius.all(Radius.circular(7)),
                border: value ? null : Border.all(color: c.borderStrong, width: 1.5),
              ),
              child: value ? SeenCheckGlyph(size: 14, color: c.onPrimary) : null,
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Switch ─────────────────────────

/// 44 x 26 switch: gradient track when on, soft grey when off, white knob.
/// [onChanged] null = disabled (faded).
class SeenSwitch extends StatelessWidget {
  const SeenSwitch({super.key, required this.value, required this.onChanged, this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final enabled = onChanged != null;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      onTap: enabled ? () => onChanged!(!value) : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? () => onChanged!(!value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: SizedBox(
            width: 52,
            height: 44,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 44,
                height: 26,
                padding: const EdgeInsets.all(3),
                alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
                decoration: BoxDecoration(
                  gradient: value ? SeenBrand.gradientCta : null,
                  color: value ? null : c.border,
                  borderRadius: const BorderRadius.all(SeenRadius.full),
                ),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Color(0x332C186A), blurRadius: 3, offset: Offset(0, 1))],
                  ),
                  child: SizedBox(width: 20, height: 20),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Progress & badge ─────────────────────────

/// 6 px progress bar: pale track, gradient fill of [fraction] (0..1) from the reading start.
class SeenProgressBar extends StatelessWidget {
  const SeenProgressBar({super.key, required this.fraction, this.width, this.semanticLabel});

  final double fraction;

  /// null = as wide as the parent allows.
  final double? width;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final f = fraction.isNaN ? 0.0 : fraction.clamp(0.0, 1.0);
    return Semantics(
      label: semanticLabel,
      value: '${(f * 100).round()}%',
      child: SizedBox(
        width: width,
        height: 6,
        child: DecoratedBox(
          decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(SeenRadius.full)),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: FractionallySizedBox(
              widthFactor: f,
              child: const DecoratedBox(
                decoration: BoxDecoration(gradient: SeenBrand.gradientCta, borderRadius: BorderRadius.all(Radius.circular(3))),
                child: SizedBox(height: 6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small red count pill ("3"). 99+ for anything above 99.
class SeenCountBadge extends StatelessWidget {
  const SeenCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    final c = SeenColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SeenRequestStatus.deadlineUnder24h.colors.fg,
        borderRadius: const BorderRadius.all(SeenRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        child: Text(count > 99 ? '99+' : '$count', style: t.caption.copyWith(color: c.onPrimary)),
      ),
    );
  }
}
