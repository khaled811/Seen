// RequestTicket — Figma "Ticket" on Request tracking: a violet gradient head
// (status chip, reference, title, subtitle) over a perforated white stub with
// fees / travelers / request date.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenRequestTicket extends StatelessWidget {
  const SeenRequestTicket({
    super.key,
    required this.status,
    required this.statusLabel,
    required this.reference,
    required this.title,
    required this.subtitle,
    required this.feeLabel,
    required this.feeValue,
    required this.travelersLabel,
    required this.travelersValue,
    required this.dateLabel,
    required this.dateValue,
    this.onReferenceTap,
  });

  final SeenRequestStatus status;
  final String statusLabel;

  /// e.g. "SB-20481" — always an LTR run.
  final String reference;
  final String title;
  final String subtitle;

  /// Stub columns: caption + pre-formatted value.
  final String feeLabel;
  final String feeValue;
  final String travelersLabel;
  final String travelersValue;
  final String dateLabel;
  final String dateValue;

  /// Tapping the reference (e.g. to copy it).
  final VoidCallback? onReferenceTap;

  static const _notch = 22.0;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r28);

    Widget stubColumn(String caption, String value, CrossAxisAlignment align) => Column(
          crossAxisAlignment: align,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(caption, style: type.caption.copyWith(color: c.inkMuted)),
            const SizedBox(height: 2),
            Text(value, style: type.bodyStrong),
          ],
        );

    return DecoratedBox(
      decoration: const BoxDecoration(borderRadius: radius, boxShadow: SeenShadows.ticket),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: c.card,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: const BoxDecoration(gradient: SeenBrand.gradientCard),
                child: Stack(
                  children: [
                    Positioned(
                      left: -142,
                      top: -91,
                      width: 350,
                      height: 253,
                      child: ExcludeSemantics(
                        child: SvgPicture.asset(SeenVectors.patternIsometricWhite, fit: BoxFit.fill),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 112),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                InkWell(
                                  onTap: onReferenceTap,
                                  borderRadius: const BorderRadius.all(SeenRadius.xs),
                                  child: Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      reference,
                                      style: type.label.copyWith(color: c.onPrimary, fontFeatures: SeenFonts.tabular),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                SeenStatusChip(status: status, label: statusLabel, size: SeenStatusChipSize.medium),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(title, style: type.h2.copyWith(color: c.onPrimary)),
                            Text(subtitle, style: type.body.copyWith(color: c.onPrimaryMuted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: _notch,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: CustomPaint(painter: _PerforationPainter(color: SeenBrand.violet40)),
                      ),
                    ),
                    // Half-circle cut-outs on both edges (clipped by the ticket).
                    for (final side in [true, false])
                      Positioned(
                        left: side ? -_notch / 2 : null,
                        right: side ? null : -_notch / 2,
                        top: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: c.card, shape: BoxShape.circle, border: Border.all(color: c.border)),
                          child: const SizedBox(width: _notch, height: _notch),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    stubColumn(dateLabel, dateValue, CrossAxisAlignment.start),
                    stubColumn(travelersLabel, travelersValue, CrossAxisAlignment.center),
                    stubColumn(feeLabel, feeValue, CrossAxisAlignment.end),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed horizontal tear line between the head and the stub.
class _PerforationPainter extends CustomPainter {
  const _PerforationPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    for (var x = 0.0; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, y), Offset((x + 5).clamp(0, size.width), y), paint);
    }
  }

  @override
  bool shouldRepaint(_PerforationPainter old) => old.color != color;
}
