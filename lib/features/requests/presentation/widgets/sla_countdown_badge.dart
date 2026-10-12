import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// Visual countdown to [deadline] — the 72-hour SLA for
/// `RequestStatus.infoRequired`. Ticks every minute (a countdown badge
/// doesn't need second-level precision) via its own `Timer`, created in
/// `initState` and cancelled in `dispose` — an ephemeral UI concern, not
/// Bloc state, mirroring `OtpVerificationScreen`'s resend countdown.
class SlaCountdownBadge extends StatefulWidget {
  const SlaCountdownBadge({super.key, required this.deadline});

  final DateTime deadline;

  @override
  State<SlaCountdownBadge> createState() => _SlaCountdownBadgeState();
}

class _SlaCountdownBadgeState extends State<SlaCountdownBadge> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final remaining = widget.deadline.difference(DateTime.now());
    final isOverdue = remaining.isNegative;
    final color = isOverdue
        ? Theme.of(context).colorScheme.error
        : (remaining.inHours < 12 ? Colors.orange : Colors.blueGrey);

    final label = isOverdue
        ? l10n.slaOverdue
        : l10n.slaTimeRemaining(_formatDuration(remaining));

    return Chip(
      avatar: Icon(Icons.timer_outlined, size: 18, color: color),
      label: Text(label),
      labelStyle: TextStyle(color: color, fontWeight: FontWeight.w600),
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.4)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}
