// RequestSummaryCard — Figma "Request card": icon tile + title/subtitle, status
// chip, 5-step progress bars with the current step, and a footer with the date
// and reference (or the deadline countdown for action-required requests).
//
// A new widget next to the legacy [SeenRequestCard]; the requests dashboard
// moves over when its screen is migrated.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import 'request_status_seen_mapping.dart';

class SeenRequestSummaryCard extends StatelessWidget {
  const SeenRequestSummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.progress,
    required this.reference,
    required this.dateLabel,
    this.iconAsset = SeenVectors.iconRequests,
    this.slaDeadline,
    this.note,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final SeenRequestStatus status;
  final SeenRequestProgress progress;

  /// e.g. "SB-20481" — always an LTR run.
  final String reference;

  /// Pre-formatted, e.g. SeenFormat.date(submittedAt).
  final String dateLabel;
  final String iconAsset;

  /// When set, the footer shows the live-at-build countdown instead of the date.
  final DateTime? slaDeadline;

  /// What to fix (the backend's rejection / action note), shown under the
  /// progress label for action-required requests. Real data only.
  final String? note;
  final VoidCallback? onTap;

  static const _barCount = 5;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final s = SeenStrings.of(context);
    const radius = BorderRadius.all(SeenRadius.r22);
    final countdown = seenCountdownState(slaDeadline);

    final referenceText = Directionality(
      textDirection: TextDirection.ltr,
      child: Text(reference, style: type.label.copyWith(color: c.primaryInk, fontFeatures: SeenFonts.tabular)),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(borderRadius: radius, boxShadow: SeenShadows.card),
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide(color: c.border)),
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Padding(
            padding: const EdgeInsets.all(SeenSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          DecoratedBox(
                            decoration: const BoxDecoration(
                              color: SeenBrand.violet05,
                              borderRadius: BorderRadius.all(SeenRadius.r14),
                            ),
                            child: SizedBox(width: 44, height: 44, child: Center(child: SeenSvgIcon(iconAsset, size: 28))),
                          ),
                          const SizedBox(width: SeenSpace.s3),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: type.bodyStrong),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: type.caption.copyWith(color: c.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SeenSpace.s2),
                    SeenStatusChip(status: status, label: s.requestStatus(status)),
                  ],
                ),
                if (progress.isVisible) ...[
                  const SizedBox(height: SeenSpace.s3),
                  Row(
                    children: [
                      for (var i = 1; i <= _barCount; i++) ...[
                        if (i > 1) const SizedBox(width: SeenSpace.s1),
                        _Bar(color: _barColor(i)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.requestStep(progress.step)} · ${s.stepOf(progress.step, progress.total)}',
                    style: type.caption.copyWith(color: c.inkSecondary),
                  ),
                  if (note != null && note!.trim().isNotEmpty) ...[
                    const SizedBox(height: SeenSpace.s1),
                    Text(note!, style: type.caption.copyWith(color: SeenRequestStatus.actionRequired.colors.fg)),
                  ],
                ],
                const SizedBox(height: SeenSpace.s3),
                Divider(height: 1, thickness: 1, color: c.border),
                const SizedBox(height: SeenSpace.s3),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    referenceText,
                    if (countdown != null)
                      SeenCountdownPill(label: _countdownLabel(s, countdown), state: countdown)
                    else
                      Text(dateLabel, style: type.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _barColor(int i) {
    if (i < progress.step) return SeenBrand.progressDone;
    if (i == progress.step) return progress.waiting ? SeenBrand.progressWaiting : SeenBrand.progressDone;
    return SeenBrand.progressTodo;
  }

  String _countdownLabel(SeenStrings s, SeenCountdownState state) {
    if (state == SeenCountdownState.expired) return s.requestStatus(SeenRequestStatus.expired);
    final left = slaDeadline!.difference(DateTime.now());
    return left.inHours >= 1 ? s.remainingHours(left.inHours) : s.remainingMinutes(left.inMinutes.clamp(1, 59));
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.all(Radius.circular(3))),
        child: const SizedBox(width: 30, height: 5),
      );
}
