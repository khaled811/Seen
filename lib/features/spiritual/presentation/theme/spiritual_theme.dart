import 'package:flutter/material.dart';

import 'spiritual_base_theme.dart';
import 'spiritual_tokens.dart';

/// Wraps [child] in the hub's light theme and native RTL. The Manasik hub is
/// Arabic-only and light-only (readability in sunlight), independent of the
/// app locale and theme mode.
class SpiritualTheme extends StatelessWidget {
  const SpiritualTheme({super.key, required this.child, this.tokens = SpiritualTokens.light});

  final Widget child;
  final SpiritualTokens tokens;

  static ThemeData data(ThemeData base, SpiritualTokens t) => base.copyWith(
        brightness: Brightness.light,
        scaffoldBackgroundColor: t.bg,
        canvasColor: t.bg,
        colorScheme: base.colorScheme.copyWith(
          brightness: Brightness.light,
          primary: t.accent,
          onPrimary: Colors.white,
          surface: t.surface,
          onSurface: t.inkPrimary,
        ),
        textTheme: base.textTheme.apply(
          fontFamily: SpiritualFonts.ui,
          bodyColor: t.inkPrimary,
          displayColor: t.inkPrimary,
        ),
        iconTheme: IconThemeData(color: t.inkBody, size: 24),
        extensions: [t],
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        // Frozen legacy base, not the app theme: see spiritual_base_theme.dart.
        data: data(SpiritualBaseTheme.of(Theme.of(context).brightness), tokens),
        child: DefaultTextStyle.merge(
          style: SpiritualType.body.copyWith(color: tokens.inkPrimary),
          child: child,
        ),
      ),
    );
  }
}
