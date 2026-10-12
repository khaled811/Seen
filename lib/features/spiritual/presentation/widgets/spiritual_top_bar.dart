import 'package:flutter/material.dart';

import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import 'spiritual_icon_button.dart';

/// Top bar: leading (back by default), centred title with optional subtitle,
/// trailing slot. Height 64, grows with text scale.
class SpiritualTopBar extends StatelessWidget {
  const SpiritualTopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onBack,
    this.showBack = true,
  });

  final String title;
  final String? subtitle;

  /// Replaces the default back button.
  final Widget? leading;
  final Widget? trailing;

  /// Defaults to popping the current route.
  final VoidCallback? onBack;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final lead = leading ??
        (showBack
            ? SpiritualIconButton(
                icon: Icons.arrow_back,
                semanticLabel: SpiritualStrings.back,
                onPressed: onBack ?? () => Navigator.maybePop(context),
              )
            : null);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Row(
        children: [
          SizedBox(width: SpiritualSpace.minTap, child: lead),
          const SizedBox(width: SpiritualSpace.s8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: SpiritualType.title.copyWith(color: t.inkPrimary),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: SpiritualType.caption.copyWith(color: t.inkMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: SpiritualSpace.s8),
          trailing != null
              ? ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: SpiritualSpace.minTap),
                  child: trailing,
                )
              : const SizedBox(width: SpiritualSpace.minTap),
        ],
      ),
    );
  }
}
