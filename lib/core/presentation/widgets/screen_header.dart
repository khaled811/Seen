// ScreenHeader — Figma flow header: round back button, centered title with an
// optional caption (e.g. "Step 2 of 3"), and a trailing slot (or an equal
// spacer so the title stays centered).
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';
import '../foundation/seen_strings.dart';
import 'actions.dart';

class SeenScreenHeader extends StatelessWidget {
  const SeenScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.showBack = true,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, SeenSpace.s3, 20, SeenSpace.s3),
  });

  final String title;
  final String? subtitle;

  /// Defaults to popping the current route.
  final VoidCallback? onBack;
  final bool showBack;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  static const _slot = 44.0;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (showBack)
            SeenRoundIconButton(
              icon: SeenIcons.back(context),
              semanticLabel: SeenStrings.of(context).back,
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          else
            const SizedBox(width: _slot),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: type.title),
                if (subtitle != null)
                  Text(subtitle!, textAlign: TextAlign.center, style: type.caption.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          trailing ?? const SizedBox(width: _slot),
        ],
      ),
    );
  }
}
