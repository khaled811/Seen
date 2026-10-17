// System state building blocks (Figma SYS-03 / 04 / 05): the round illustration with
// a white tile and icon, title + body, and the "no permission" view.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import 'actions.dart';

/// 128 px circle (tinted [background] or the violet wash) holding a 64 px white
/// tile with a 36 px [icon].
class SeenSystemIllustration extends StatelessWidget {
  const SeenSystemIllustration(
      {super.key, required this.icon, this.background, this.iconColor});

  final IconData icon;

  /// A flat fill; null = the violet wash used by maintenance and update.
  final Color? background;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: background,
          gradient: background == null
              ? const LinearGradient(
                  begin: AlignmentDirectional.centerEnd,
                  end: AlignmentDirectional.centerStart,
                  colors: [Color(0xFFE5DCFD), Color(0xFFFFFFFF)],
                )
              : null,
          border: Border.all(color: c.border),
        ),
        child: SizedBox(
          width: 128,
          height: 128,
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: const BorderRadius.all(SeenRadius.r20),
                boxShadow: SeenShadows.stickyBar,
              ),
              child: SizedBox(
                width: 64,
                height: 64,
                child:
                    Icon(icon, size: 36, color: iconColor ?? SeenBrand.violet),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Illustration, title and body centred; [below] goes under the body.
class SeenSystemMessage extends StatelessWidget {
  const SeenSystemMessage({
    super.key,
    required this.illustration,
    required this.title,
    required this.body,
    this.below = const [],
  });

  final Widget illustration;
  final String title;
  final String body;
  final List<Widget> below;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: illustration),
        const SizedBox(height: 18),
        Text(title, textAlign: TextAlign.center, style: t.h1),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 310),
            child: Text(body,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: c.inkSecondary)),
          ),
        ),
        ...below,
      ],
    );
  }
}

/// SYS-03: the signed-in user lacks a permission. Offers asking the account owner
/// and going home; [rule] is the small note on how restricted things are shown.
class SeenForbiddenView extends StatelessWidget {
  const SeenForbiddenView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    required this.requestLabel,
    required this.onRequest,
    required this.backLabel,
    required this.onBack,
    this.rule,
    this.requesting = false,
    this.requested = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String requestLabel;

  /// null = no way to ask (hides the button).
  final VoidCallback? onRequest;
  final String backLabel;
  final VoidCallback? onBack;
  final String? rule;
  final bool requesting;

  /// The request was sent: the button stays but is disabled.
  final bool requested;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SeenSystemMessage(
                illustration: SeenSystemIllustration(
                  icon: icon,
                  background: SeenRequestStatus.actionRequired.colors.bg,
                  iconColor: SeenRequestStatus.actionRequired.colors.fg,
                ),
                title: title,
                body: message,
                below: [
                  const SizedBox(height: 20),
                  if (onRequest != null)
                    SeenButton(
                      label: requestLabel,
                      expand: true,
                      loading: requesting,
                      onPressed: requested || requesting ? null : onRequest,
                    ),
                  if (onBack != null) ...[
                    const SizedBox(height: 8),
                    SeenButton.ghost(
                        label: backLabel, expand: true, onPressed: onBack),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (rule != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: const BorderRadius.all(SeenRadius.r22),
                border: Border.all(color: c.border),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child:
                    Text(rule!, style: t.caption.copyWith(color: c.inkMuted)),
              ),
            ),
          ),
      ],
    );
  }
}
