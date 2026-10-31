// "Scan the passport to read the details" above the traveler form's first field (design/gaps
// PASS-01), with the manual-entry note under it, or, after values were applied, a note saying how
// many fields were filled and what is still to complete. Nothing is submitted by the scan.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/config/feature_flags.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';
import '../bloc/service_booking_bloc.dart';
import '../bloc/service_booking_event.dart';
import '../bloc/service_booking_state.dart';
import '../screens/passport_scan_screen.dart';

class PassportScanEntry extends StatefulWidget {
  const PassportScanEntry({super.key, required this.state, this.openScan});

  final ServiceBookingInProgress state;

  /// Test seam; defaults to the scan screen.
  final Future<Map<String, String>?> Function(BuildContext context, Map<String, String> fields)? openScan;

  @override
  State<PassportScanEntry> createState() => _PassportScanEntryState();
}

class _PassportScanEntryState extends State<PassportScanEntry> {
  /// How many fields the last scan filled, for the note; null before any scan.
  int? _filled;

  Future<void> _scan() async {
    final fields = {for (final f in widget.state.travelerFields) f.key: f.label};
    final chosen = await (widget.openScan ?? ((c, f) => PassportScanScreen.open(c, fields: f)))(context, fields);
    if (chosen == null || chosen.isEmpty || !mounted) {
      return;
    }
    final active = widget.state.activeTravelerIndex;
    context.read<ServiceBookingBloc>().add(
          TravelerPrefillApplied([for (var i = 0; i <= active; i++) i == active ? chosen : const <String, String>{}]),
        );
    setState(() => _filled = chosen.length);
  }

  @override
  Widget build(BuildContext context) {
    if (!kEnablePassportScan) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final traveler = widget.state.activeTraveler;
    // What the form still needs after a scan: its required, visible fields that are empty.
    final missing = [
      for (final f in widget.state.travelerFields)
        if (f.required && f.isVisible(traveler.fieldValues) && (traveler.fieldValues[f.key] == null || '${traveler.fieldValues[f.key]}'.trim().isEmpty)) f.label,
    ];
    final filled = _filled;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeenButton.secondary(label: l10n.passScanButton, icon: SeenIcons.scan, size: SeenButtonSize.small, expand: true, onPressed: _scan),
        const SizedBox(height: 8),
        if (filled == null)
          Text(l10n.passManualHint, textAlign: TextAlign.center, style: type.caption.copyWith(color: c.inkSecondary))
        else
          SeenInlineBanner(
            tone: SeenBannerTone.ok,
            message: missing.isEmpty ? s.prefillApplied : s.digits(l10n.passApplied(filled, missing.join(s.isArabic ? '، ' : ', '))),
          ),
        const SizedBox(height: 14),
      ],
    );
  }
}
