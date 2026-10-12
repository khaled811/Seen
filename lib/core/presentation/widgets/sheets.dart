// BottomSheet: showSeenSheet() + SeenSheet
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../foundation/seen_icons.dart';
import '../foundation/seen_strings.dart';
import 'actions.dart';

/// Opens a Seen bottom sheet: grab handle (theme), title + subtitle + close,
/// scrolling body, pinned footer. Use for every confirm-with-money step
/// (review, top-up, funding, reject reason, margin edit).
Future<T?> showSeenSheet<T>({
  required BuildContext context,
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
  WidgetBuilder? footerBuilder,
  bool isDismissible = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: isDismissible,
    builder: (ctx) => SeenSheet(
      title: title,
      subtitle: subtitle,
      footer: footerBuilder?.call(ctx),
      child: builder(ctx),
    ),
  );
}

/// The sheet's content layout. Grows to at most 92% of the screen height and
/// lifts above the keyboard.
class SeenSheet extends StatelessWidget {
  const SeenSheet({super.key, required this.title, this.subtitle, required this.child, this.footer});

  final String title;
  final String? subtitle;
  final Widget child;

  /// Usually one expanded [SeenButton] — the sheet's only primary action.
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * .92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(SeenSpace.s4, 0, SeenSpace.s2, SeenSpace.s3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.headlineSmall),
                        if (subtitle != null) Text(subtitle!, style: text.bodySmall!.copyWith(color: c.inkMuted)),
                      ],
                    ),
                  ),
                  SeenIconButton(
                    icon: SeenIcons.x,
                    semanticLabel: SeenStrings.of(context).close,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: c.border),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(SeenSpace.s4),
                child: child,
              ),
            ),
            if (footer != null)
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(SeenSpace.s4, SeenSpace.s3, SeenSpace.s4, SeenSpace.s4),
                    child: footer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
