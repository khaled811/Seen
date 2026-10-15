// DeadlineCard — Figma "Deadline": the remaining time of the 72h SLA as a big
// HH:MM:SS counter on a soft violet panel. Ticks once a second.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';

class SeenDeadlineCard extends StatefulWidget {
  const SeenDeadlineCard({
    super.key,
    required this.deadline,
    required this.title,
    required this.subtitle,
    required this.expiredLabel,
    this.amber = false,
    this.clock = DateTime.now,
  });

  final DateTime deadline;
  final String title;
  final String subtitle;

  /// Shown instead of the counter once the deadline has passed.
  final String expiredLabel;

  /// Figma REQ-05 variant: amber "action required" panel with a smaller counter.
  final bool amber;

  /// Time source; tests inject a controllable clock.
  @visibleForTesting
  final DateTime Function() clock;

  @override
  State<SeenDeadlineCard> createState() => _SeenDeadlineCardState();
}

class _SeenDeadlineCardState extends State<SeenDeadlineCard> {
  // Owned here: created in initState, cancelled in dispose. Only the counter
  // text listens to [_left], so a tick rebuilds one Text, not the card.
  late final ValueNotifier<Duration> _left = ValueNotifier(_remaining());
  Timer? _timer;

  Duration _remaining() => widget.deadline.difference(widget.clock());

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _left.value = _remaining();
    });
  }

  @override
  void didUpdateWidget(covariant SeenDeadlineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deadline != widget.deadline) _left.value = _remaining();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _left.dispose();
    super.dispose();
  }

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final amberColors = SeenRequestStatus.actionRequired.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: widget.amber ? amberColors.bg : null,
        gradient: widget.amber ? null : SeenBrand.gradientSoft,
        borderRadius: const BorderRadius.all(SeenRadius.r18),
        border: widget.amber ? null : Border.all(color: c.border),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: widget.amber ? 16 : SeenSpace.s4, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: widget.amber ? type.label.copyWith(color: amberColors.fg) : type.bodyStrong),
                  Text(
                    widget.subtitle,
                    style: type.caption.copyWith(color: widget.amber ? amberColors.fg : c.inkSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: SeenSpace.s3),
            ValueListenableBuilder<Duration>(
              valueListenable: _left,
              builder: (context, left, _) {
                final expired = left <= Duration.zero;
                final urgent = !expired && left.inHours < 24;
                final color = widget.amber ? amberColors.fg : (expired || urgent ? c.slaFg : SeenBrand.violet);
                final style = widget.amber ? type.h2 : type.display;
                if (expired) return Text(widget.expiredLabel, style: type.h2.copyWith(color: color));
                return Semantics(
                  label: '${widget.title} ${left.inHours} h ${left.inMinutes.remainder(60)} min',
                  excludeSemantics: true,
                  child: Directionality(
                    textDirection: TextDirection.ltr, // "46:12:08" never reorders
                    child: Text(
                      '${_two(left.inHours)}:${_two(left.inMinutes.remainder(60))}:${_two(left.inSeconds.remainder(60))}',
                      style: style.copyWith(color: color, fontFeatures: SeenFonts.tabular),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
