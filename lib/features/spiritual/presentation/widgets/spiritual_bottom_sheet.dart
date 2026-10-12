import 'package:flutter/material.dart';

import '../spiritual_strings.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import 'spiritual_icon_button.dart';

/// Modal sheet: radius 28 top, 40×5 grab handle, title row with a 48 dp close
/// button, 36 % scrim, slide-up 280 ms / out 220 ms. The content is wrapped
/// in [SpiritualTheme] because modal routes sit above the hub's Theme/RTL.
Future<T?> showSpiritualBottomSheet<T>(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) {
  final t = SpiritualTokens.of(context);
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: t.scrim,
    sheetAnimationStyle: AnimationStyle(
      duration: SpiritualMotion.of(context, SpiritualMotion.sheetIn),
      reverseDuration: SpiritualMotion.of(context, SpiritualMotion.sheetOut),
    ),
    builder: (sheetContext) => SpiritualTheme(
      child: Builder(
        builder: (inner) => _SheetFrame(title: title, child: builder(inner)),
      ),
    ),
  );
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SpiritualRadius.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: SpiritualSpace.s10),
            Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: t.borderStrong,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SpiritualSpace.s16,
                vertical: SpiritualSpace.s8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: SpiritualType.section.copyWith(color: t.inkPrimary),
                      ),
                    ),
                  ),
                  SpiritualIconButton(
                    icon: Icons.close,
                    semanticLabel: SpiritualStrings.close,
                    onPressed: () => Navigator.maybePop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  SpiritualSpace.s16,
                  0,
                  SpiritualSpace.s16,
                  SpiritualSpace.s16,
                ),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
