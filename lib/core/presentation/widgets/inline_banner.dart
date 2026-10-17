// InlineBanner — Figma "Banner · offline / warn / error" (password-recovery
// frames): a rounded 16 strip with an icon and one or two lines of text, and an
// optional text action at the end. Three tones reuse the status colours:
// offline = cancelled (grey), warn = action required (amber), error = rejected,
// ok = completed (green).
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_vectors.dart';
import 'svg_icon.dart';

enum SeenBannerTone { offline, warn, error, ok }

class SeenInlineBanner extends StatelessWidget {
  const SeenInlineBanner({
    super.key,
    required this.tone,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconAsset,
  });

  final SeenBannerTone tone;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Defaults to the alert glyph (clock for [SeenBannerTone.warn]).
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    final colors = switch (tone) {
      SeenBannerTone.offline => SeenRequestStatus.cancelled.colors,
      SeenBannerTone.warn => SeenRequestStatus.actionRequired.colors,
      SeenBannerTone.error => SeenRequestStatus.rejected.colors,
      SeenBannerTone.ok => SeenRequestStatus.completed.colors,
    };
    final asset = iconAsset ??
        switch (tone) {
          SeenBannerTone.warn => SeenVectors.walletClock,
          SeenBannerTone.ok => SeenVectors.walletCheck,
          _ => SeenVectors.notifAlert,
        };
    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.bg, borderRadius: const BorderRadius.all(SeenRadius.lg)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              SeenSvgIcon(asset, size: 20, color: colors.fg),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: t.label.copyWith(color: colors.fg))),
              if (actionLabel != null) ...[
                const SizedBox(width: 10),
                InkWell(
                  onTap: onAction,
                  borderRadius: const BorderRadius.all(SeenRadius.sm),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: Text(actionLabel!, style: t.label.copyWith(color: colors.fg)),
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
