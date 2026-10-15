import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/navigation/shell_tab_request.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

/// Booking success / receipt (Figma BOOK-01). Reached via
/// `Navigator.pushReplacement` from [BookingReviewScreen] so the completed form
/// can't be navigated back into.
///
/// [balanceAfterCents] is the wallet balance known before submitting minus the
/// hold; null (wallet not loaded) hides that row rather than guessing.
class BookingSuccessScreen extends StatelessWidget {
  const BookingSuccessScreen({
    super.key,
    required this.requestId,
    this.serviceName,
    this.travelerCount,
    this.heldCents,
    this.balanceAfterCents,
  });

  final String requestId;
  final String? serviceName;
  final int? travelerCount;
  final int? heldCents;
  final int? balanceAfterCents;

  void _leaveTo(BuildContext context, int tab) {
    ShellTabRequest.show(tab);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _soon(BuildContext context, AppLocalizations l10n) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(l10n.bookingReceiptSoon)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final done = SeenRequestStatus.completed.colors;
    final review = SeenRequestStatus.underReview.colors;

    Widget row(String label, String value) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(
            children: [
              Expanded(child: Text(label, style: t.body.copyWith(color: c.inkSecondary))),
              Text(value, style: t.bodyStrong),
            ],
          ),
        );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) _leaveTo(context, 0);
      },
      child: Scaffold(
        body: SeenScreenBackground(
          washHeight: 320,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 46, 20, 24),
                    children: [
                      Center(
                        child: ExcludeSemantics(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: done.bg,
                              shape: BoxShape.circle,
                              border: Border.all(color: c.border),
                            ),
                            child: SizedBox(
                              width: 104,
                              height: 104,
                              child: Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: c.card,
                                    borderRadius: const BorderRadius.all(SeenRadius.r20),
                                    boxShadow: SeenShadows.stickyBar,
                                  ),
                                  child: const SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: Center(child: SeenSvgIcon(SeenVectors.successCheck, size: 29)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(l10n.bookingSuccessTitle, textAlign: TextAlign.center, style: t.h1),
                      const SizedBox(height: 14),
                      Text(
                        l10n.bookingSuccessSubtitle,
                        textAlign: TextAlign.center,
                        style: t.body.copyWith(color: c.inkSecondary),
                      ),
                      const SizedBox(height: 14),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.card,
                          borderRadius: const BorderRadius.all(SeenRadius.r24),
                          border: Border.all(color: c.border),
                          boxShadow: SeenShadows.stickyBar,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              DecoratedBox(
                                decoration: const BoxDecoration(
                                  color: SeenBrand.violet05,
                                  borderRadius: BorderRadius.all(SeenRadius.r14),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(l10n.bookingReceiptRef, style: t.caption.copyWith(color: c.inkMuted)),
                                            Directionality(
                                              textDirection: TextDirection.ltr,
                                              child: Text(requestId, style: t.h2.copyWith(color: SeenBrand.violet)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SeenTextLink(
                                        label: l10n.bookingReceiptCopy,
                                        onTap: () => _copyReference(context, l10n),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (serviceName != null) row(l10n.bookingReceiptService, serviceName!),
                              if (travelerCount != null) row(l10n.bookingReceiptTravelers, s.numeral(travelerCount!)),
                              if (heldCents != null)
                                row(l10n.bookingReceiptHeld, SeenFormat.usd(heldCents! / 100)),
                              if (balanceAfterCents != null)
                                row(l10n.bookingReceiptBalanceAfter, SeenFormat.usd(balanceAfterCents! / 100)),
                              const SizedBox(height: 12),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  color: review.bg,
                                  borderRadius: const BorderRadius.all(SeenRadius.lg),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  child: Row(
                                    children: [
                                      const SeenSvgIcon(SeenVectors.infoReview, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          l10n.bookingReceiptHoldNote,
                                          style: t.label.copyWith(color: review.fg),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(child: _TonalButton(label: l10n.bookingReceiptDownload, onTap: () => _soon(context, l10n))),
                          const SizedBox(width: 8),
                          Expanded(child: _TonalButton(label: l10n.bookingReceiptShare, onTap: () => _soon(context, l10n))),
                        ],
                      ),
                    ],
                  ),
                ),
                SeenActionBar(
                  actions: [
                    SeenButton(
                      label: l10n.bookingFollowRequest,
                      expand: true,
                      onPressed: () => _leaveTo(context, 1),
                    ),
                    SeenButton.secondary(
                      label: l10n.bookingNewRequest,
                      expand: true,
                      onPressed: () => _leaveTo(context, 0),
                    ),
                  ],
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

class _TonalButton extends StatelessWidget {
  const _TonalButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r14);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: SeenBrand.violet10,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: 40,
            child: Center(child: Text(label, style: t.label.copyWith(color: SeenBrand.violet))),
          ),
        ),
      ),
    );
  }
}
