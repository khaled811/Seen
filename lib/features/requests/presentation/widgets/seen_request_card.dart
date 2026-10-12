// RequestCard — a request in lists: reference, status, service, travelers,
// date, and an SLA or action note. status == action -> danger-line border
// and a [note] saying exactly what to fix.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_status.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenRequestCard extends StatefulWidget {
  const SeenRequestCard({
    super.key,
    required this.reference,
    required this.service,
    required this.travelers,
    required this.date,
    required this.status,
    this.slaDeadline,
    this.slaRemaining,
    this.amount,
    this.note,
    this.onTap,
  });

  final String reference;
  final String service;
  final int travelers;

  /// Pre-formatted, e.g. SeenFormat.date(submittedAt) → "27/09/2026".
  final String date;
  final SeenStatus status;

  /// Live SLA countdown (preferred) …
  final DateTime? slaDeadline;

  /// … or a static remaining time.
  final Duration? slaRemaining;
  final num? amount;

  /// Required when status == action.
  final String? note;
  final VoidCallback? onTap;

  @override
  State<SeenRequestCard> createState() => _SeenRequestCardState();
}

class _SeenRequestCardState extends State<SeenRequestCard> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final s = SeenStrings.of(context);
    final text = Theme.of(context).textTheme;
    final urgent = widget.status == SeenStatus.action;
    final meta = text.bodySmall!.copyWith(color: c.inkSecondary);
    final hasSla = widget.slaDeadline != null || widget.slaRemaining != null;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget metaItem(IconData icon, String label, {bool ltr = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: c.inkSecondary),
          const SizedBox(width: SeenSpace.s1),
          Text(label, style: meta.copyWith(fontFeatures: SeenFonts.tabular), textDirection: ltr ? TextDirection.ltr : null),
        ]);

    return AnimatedScale(
      scale: !reduceMotion && _pressed ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 100),
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SeenRadius.md),
          side: BorderSide(color: urgent ? c.dangerLine : c.border),
        ),
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: widget.onTap == null ? null : (_) => _setPressed(true),
          onTapCancel: () => _setPressed(false),
          onTapUp: (_) => _setPressed(false),
          customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.md)),
          child: Padding(
            padding: const EdgeInsets.all(SeenSpace.s4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(widget.reference,
                          textDirection: TextDirection.ltr, style: SeenType.of(context).refMono.copyWith(fontSize: 12)),
                    ),
                  ),
                  SeenStatusBadge(status: widget.status),
                ]),
                const SizedBox(height: SeenSpace.s2),
                Text(widget.service, style: text.titleMedium),
                const SizedBox(height: SeenSpace.s2),
                Wrap(spacing: SeenSpace.s4, runSpacing: SeenSpace.s1, children: [
                  metaItem(SeenIcons.users, s.travelers(widget.travelers)),
                  metaItem(SeenIcons.calendar, widget.date, ltr: true),
                  if (widget.amount != null)
                    Text(SeenFormat.usd(widget.amount!), style: meta.copyWith(fontFeatures: SeenFonts.tabular)),
                ]),
                if (hasSla || widget.note != null) ...[
                  const SizedBox(height: SeenSpace.s3),
                  Divider(height: 1, color: c.border),
                  const SizedBox(height: SeenSpace.s3),
                  Row(children: [
                    Expanded(
                      child: widget.note != null
                          ? Text(widget.note!, style: text.bodySmall!.copyWith(color: c.dangerFg))
                          : Text(s.slaLeft, style: text.labelSmall),
                    ),
                    const SizedBox(width: SeenSpace.s2),
                    if (widget.slaDeadline != null)
                      SeenSlaTag(deadline: widget.slaDeadline!)
                    else if (widget.slaRemaining != null)
                      SeenSlaTag.fixed(remaining: widget.slaRemaining!)
                    else
                      Icon(SeenIcons.forward(context), size: 18, color: c.inkMuted),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
