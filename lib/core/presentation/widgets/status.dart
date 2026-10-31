// StatusBadge · SlaTag
import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';
import '../foundation/seen_status.dart';
import '../foundation/seen_strings.dart';
import 'svg_icon.dart';

enum SeenStatusChipSize { small, medium }

/// Icon shown by the size-M chip. Provisional: Figma draws custom icons per
/// status that are not exported yet, so these are Phosphor stand-ins.
extension SeenRequestStatusIcon on SeenRequestStatus {
  IconData get icon => switch (this) {
        SeenRequestStatus.newRequest => SeenIcons.file,
        SeenRequestStatus.submitted => SeenIcons.send,
        SeenRequestStatus.underReview => SeenIcons.search,
        SeenRequestStatus.processing => SeenIcons.refresh,
        SeenRequestStatus.withAuthority => SeenIcons.building,
        SeenRequestStatus.actionRequired => SeenIcons.alert,
        SeenRequestStatus.deadlineUnder24h ||
        SeenRequestStatus.expired =>
          SeenIcons.clock,
        SeenRequestStatus.completed || SeenRequestStatus.confirmed => SeenIcons.check,
        SeenRequestStatus.rejected || SeenRequestStatus.cancelled => SeenIcons.x,
      };
}

/// Figma request-status chip (pill, no border). Colors come from
/// [SeenRequestStatus.colors] (soft background + readable label, >= 4.5:1).
/// Never color alone: [label] is always shown, plus an icon at size M.
///
///  * small  — 28px, 12/20 label, 6px dot
///  * medium — 32px, 13/20 label, 16px icon
class SeenStatusChip extends StatelessWidget {
  const SeenStatusChip({
    super.key,
    required this.status,
    required this.label,
    this.size = SeenStatusChipSize.small,
  });

  final SeenRequestStatus status;

  /// Localized status word (the vocabulary is fixed per locale).
  final String label;
  final SeenStatusChipSize size;

  @override
  Widget build(BuildContext context) {
    final type = SeenType.of(context);
    final colors = status.colors;
    final small = size == SeenStatusChipSize.small;
    final style = (small ? type.chipS : type.chipM).copyWith(color: colors.fg);

    return Container(
      height: small ? 28 : 32,
      padding: small
          ? const EdgeInsetsDirectional.symmetric(horizontal: 10)
          : const EdgeInsetsDirectional.only(start: 12, end: 10),
      decoration: BoxDecoration(color: colors.bg, borderRadius: const BorderRadius.all(SeenRadius.full)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Leading in reading order: right in RTL, left in LTR.
          small
              ? DecoratedBox(
                  decoration: BoxDecoration(color: colors.fg, shape: BoxShape.circle),
                  child: const SizedBox(width: 6, height: 6),
                )
              : (status == SeenRequestStatus.completed || status == SeenRequestStatus.confirmed
                  ? SeenCheckGlyph(size: 16, color: colors.fg)
                  : Icon(status.icon, size: 16, color: colors.fg)),
          const SizedBox(width: 6),
          Text(label, style: style, maxLines: 1),
        ],
      ),
    );
  }
}

/// Legacy status pill kept for existing call sites: maps the 8-member
/// [SeenStatus] vocabulary onto the Figma [SeenRequestStatus] chip (size S).
/// Prefer [SeenStatusChip] in new code. Mapping notes: `action` was a danger
/// tone but Figma's "action required" is amber; `pending`/`hold` map to
/// processing / action-required.
class SeenStatusBadge extends StatelessWidget {
  const SeenStatusBadge({super.key, required this.status, this.label, this.dense = false});

  final SeenStatus status;

  /// Overrides the fixed word — use sparingly (the vocabulary is fixed).
  final String? label;

  /// Kept for API compatibility; the Figma chip has a single small size.
  final bool dense;

  SeenRequestStatus get _requestStatus => switch (status) {
        SeenStatus.review => SeenRequestStatus.underReview,
        SeenStatus.pending => SeenRequestStatus.processing,
        SeenStatus.hold || SeenStatus.action => SeenRequestStatus.actionRequired,
        SeenStatus.rejected => SeenRequestStatus.rejected,
        SeenStatus.completed || SeenStatus.approved || SeenStatus.posted => SeenRequestStatus.completed,
      };

  @override
  Widget build(BuildContext context) =>
      SeenStatusChip(status: _requestStatus, label: label ?? status.label(context));
}

/// Countdown to the processing deadline, toned by the time left:
/// >= 24h neutral, < 24h burnt orange (sla), <= 0 terracotta "SLA exceeded".
/// Refreshes once a minute. Never animates or blinks.
class SeenSlaTag extends StatefulWidget {
  /// Live countdown to [deadline].
  const SeenSlaTag({super.key, required DateTime this.deadline, this.totalHours}) : remaining = null;

  /// Static value (previews, tests, server-computed remaining time).
  const SeenSlaTag.fixed({super.key, required Duration this.remaining, this.totalHours}) : deadline = null;

  final DateTime? deadline;
  final Duration? remaining;

  /// SLA length, e.g. 72 → shows "52 hours of 72".
  final int? totalHours;

  @override
  State<SeenSlaTag> createState() => _SeenSlaTagState();
}

class _SeenSlaTagState extends State<SeenSlaTag> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant SeenSlaTag oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (widget.deadline == null) return;
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Duration get _left => widget.remaining ?? widget.deadline!.difference(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final s = SeenStrings.of(context);
    final left = _left;
    final tone = left <= Duration.zero
        ? SeenTone.danger
        : left.inHours < 24
            ? SeenTone.sla
            : SeenTone.neutral;
    final t = c.tone(tone);
    final value = left <= Duration.zero
        ? s.slaExceeded
        : left.inHours >= 24
            ? s.hours(left.inHours)
            : s.hoursMinutes(left.inHours, left.inMinutes.remainder(60));
    final style = Theme.of(context).textTheme.labelMedium!.copyWith(color: t.fg, fontFeatures: SeenFonts.tabular);

    return Semantics(
      label: s.slaLeft,
      child: Container(
        height: 26,
        padding: const EdgeInsetsDirectional.symmetric(horizontal: SeenSpace.s2),
        decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.all(SeenRadius.xs)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(SeenIcons.clock, size: 14, color: t.fg),
            const SizedBox(width: SeenSpace.s1),
            Text(value, style: style),
            if (widget.totalHours != null && left > Duration.zero) ...[
              const SizedBox(width: SeenSpace.s1),
              Text(s.ofTotal(widget.totalHours!), style: style.copyWith(fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }
}

enum SeenCountdownState { warm, urgent, expired }

/// Figma "Countdown pill": clock + remaining time on the status colors of the
/// deadline (warm = action required, urgent = under 24h, expired). The caller
/// supplies the localized [label]; pass [ltrLabel] for clock-style values such
/// as "0:42" so their digits are never reordered inside Arabic text.
class SeenCountdownPill extends StatelessWidget {
  const SeenCountdownPill({
    super.key,
    required this.label,
    this.state = SeenCountdownState.warm,
    this.ltrLabel = false,
    this.semanticLabel,
  });

  final String label;
  final SeenCountdownState state;
  final bool ltrLabel;
  final String? semanticLabel;

  SeenRequestStatus get _status => switch (state) {
        SeenCountdownState.warm => SeenRequestStatus.actionRequired,
        SeenCountdownState.urgent => SeenRequestStatus.deadlineUnder24h,
        SeenCountdownState.expired => SeenRequestStatus.expired,
      };

  @override
  Widget build(BuildContext context) {
    final colors = _status.colors;
    final style = SeenType.of(context).chipM.copyWith(color: colors.fg, fontFeatures: SeenFonts.tabular);
    Widget text = Text(label, style: style, maxLines: 1);
    if (ltrLabel) text = Directionality(textDirection: TextDirection.ltr, child: text);
    return Semantics(
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: colors.bg, borderRadius: const BorderRadius.all(SeenRadius.full)),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12, end: 10, top: 5, bottom: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(SeenIcons.clock, size: 16, color: colors.fg),
              const SizedBox(width: 6),
              Flexible(child: text),
            ],
          ),
        ),
      ),
    );
  }
}
