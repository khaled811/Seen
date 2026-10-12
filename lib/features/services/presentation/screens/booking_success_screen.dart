import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';

/// Terminal screen for a successfully submitted booking. Reached via
/// `Navigator.pushReplacement` from [BookingReviewScreen] so the completed
/// form can't be navigated back into.
class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(SeenSpace.s6),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(color: c.successBg, shape: BoxShape.circle),
                  child: Icon(SeenIcons.check, size: 36, color: c.successFg),
                ),
                const SizedBox(height: SeenSpace.s4),
                Text(l10n.bookingSuccessTitle, style: text.titleLarge, textAlign: TextAlign.center),
                const SizedBox(height: SeenSpace.s2),
                Text(l10n.bookingSuccessMessage(requestId),
                    style: text.bodyMedium!.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
                const SizedBox(height: SeenSpace.s3),
                InkWell(
                  borderRadius: const BorderRadius.all(SeenRadius.xs),
                  onTap: () => _copyReference(context, l10n),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s2, vertical: SeenSpace.s1),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(requestId,
                            textDirection: TextDirection.ltr,
                            style: SeenType.of(context).refMono.copyWith(fontSize: 14, color: c.ink)),
                        const SizedBox(width: SeenSpace.s1),
                        Icon(SeenIcons.copy, size: 16, color: c.inkMuted, semanticLabel: l10n.bookingCopyReferenceTooltip),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: SeenSpace.s6),
                SeenButton(
                  label: l10n.bookingBackToHomeAction,
                  expand: true,
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _copyReference(BuildContext context, AppLocalizations l10n) async {
    await Clipboard.setData(ClipboardData(text: requestId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.bookingReferenceCopiedMessage)));
  }
}
