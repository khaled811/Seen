import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';
import 'spiritual_top_bar.dart';

/// Page frame: `bg` background, safe area, 16 dp gutter, optional top bar and
/// bottom navigation.
class SpiritualScaffold extends StatelessWidget {
  const SpiritualScaffold({
    super.key,
    required this.body,
    this.topBar,
    this.bottomNav,
    this.background,
    this.gutter = true,
  });

  final Widget body;
  final SpiritualTopBar? topBar;
  final Widget? bottomNav;

  /// Overrides `bg` (the Quran reader uses the warmer `bgReader`).
  final Color? background;

  /// Apply the 16 dp side gutter to the top bar and body.
  final bool gutter;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final side = EdgeInsets.symmetric(
      horizontal: gutter ? SpiritualSpace.gutter : 0,
    );
    return Scaffold(
      backgroundColor: background ?? t.bg,
      bottomNavigationBar: bottomNav,
      body: SafeArea(
        bottom: bottomNav == null,
        child: Column(
          children: [
            if (topBar != null) Padding(padding: side, child: topBar),
            Expanded(child: Padding(padding: side, child: body)),
          ],
        ),
      ),
    );
  }
}
