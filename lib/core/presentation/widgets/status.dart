// StatusBadge · SlaTag
import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';
import '../foundation/seen_status.dart';
import '../foundation/seen_strings.dart';

/// Status pill: icon + fixed word on a tinted fill with a 1px line.
/// 24px tall (20px when [dense]), radius-xs, label-md.
class SeenStatusBadge extends StatelessWidget {
  const SeenStatusBadge({super.key, required this.status, this.label, this.dense = false});

  final SeenStatus status;

  /// Overrides the fixed word — use sparingly (the vocabulary is fixed).
  final String? label;

  /// Compact 20px variant used inside ledger rows.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = SeenColors.of(context).tone(status.tone);
    final text = Theme.of(context).textTheme.labelMedium!;
    return Container(
      height: dense ? 20 : 24,
      padding: EdgeInsetsDirectional.symmetric(horizontal: dense ? 6 : SeenSpace.s2),
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: const BorderRadius.all(SeenRadius.xs),
        border: Border.all(color: t.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: dense ? 12 : 14, color: t.fg),
          const SizedBox(width: SeenSpace.s1),
          Text(label ?? status.label(context),
              style: text.copyWith(color: t.fg, fontSize: dense ? 11 : 12), maxLines: 1),
        ],
      ),
    );
  }
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
