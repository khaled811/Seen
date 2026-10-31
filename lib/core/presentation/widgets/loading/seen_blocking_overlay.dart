// The blocking wait for money / irreversible actions only (SPEC section 8): a scrim over the
// screen, back disabled, a centred card with the hero (sky progress when the progress is
// known, otherwise the drawing mark), a title, an optional context line, the do-not-close
// warning and an optional cancel action. Everything else uses a loader inside the button.
import 'package:flutter/material.dart';

import '../../../theme/seen_colors.dart';
import '../../../theme/seen_typography.dart';
import '../../foundation/seen_strings.dart';
import 'loading_strings.dart';
import 'seen_mark_draw.dart';
import 'seen_sky_progress.dart';

class SeenBlockingOverlay extends StatelessWidget {
  const SeenBlockingOverlay({
    super.key,
    required this.visible,
    required this.title,
    required this.child,
    this.contextLine,
    this.progress,
    this.onCancel,
    this.cancelLabel,
  });

  /// True while the action runs.
  final bool visible;

  /// «جاري الإرسال…»: the existing verb of the action.
  final String title;

  /// Service, passengers: one line under the title.
  final String? contextLine;

  /// 0..1 when known (uploads); null = unknown (the mark draws itself).
  final double? progress;

  /// Shown only when the action can really be cancelled.
  final VoidCallback? onCancel;
  final String? cancelLabel;

  /// The screen underneath.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final p = progress;
    return PopScope(
      canPop: !visible,
      child: Stack(
        children: [
          child,
          if (visible) ...[
            const Positioned.fill(
                child: ModalBarrier(
                    dismissible: false, color: SeenBrand.blockingScrim)),
            Positioned.fill(
              child: Semantics(
                liveRegion: true,
                label: title,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius:
                            const BorderRadius.all(Radius.circular(28)),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x731B1530),
                              blurRadius: 48,
                              offset: Offset(0, 24),
                              spreadRadius: -12)
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (p == null)
                              const SeenMarkDraw(height: 96)
                            else
                              SeenSkyProgress(value: p, height: 92),
                            const SizedBox(height: 16),
                            Text(
                              p == null
                                  ? title
                                  : '$title ${s.numeral((p * 100).round())}%',
                              textAlign: TextAlign.center,
                              style: t.h2.copyWith(fontWeight: FontWeight.w700),
                            ),
                            if (contextLine != null) ...[
                              const SizedBox(height: 6),
                              Text(contextLine!,
                                  textAlign: TextAlign.center,
                                  style:
                                      t.body.copyWith(color: c.inkSecondary)),
                            ],
                            const SizedBox(height: 14),
                            Text(s.doNotCloseApp,
                                textAlign: TextAlign.center,
                                style: t.caption.copyWith(color: c.pendingFg)),
                            if (onCancel != null) ...[
                              const SizedBox(height: 10),
                              TextButton(
                                onPressed: onCancel,
                                style: TextButton.styleFrom(
                                    foregroundColor: c.dangerFg),
                                child: Text(cancelLabel ?? s.waitCancel),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
