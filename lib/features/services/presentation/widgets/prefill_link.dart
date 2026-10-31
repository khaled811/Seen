import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart' show SeenTextLink;
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/prefill.dart';
import '../bloc/prefill_cubit.dart';

/// "Copy the details of an earlier request" under the traveler tabs: shown only when
/// the server lists earlier requests that may be copied for this service (the airline
/// circular from its approval, for example). Owns its [PrefillCubit].
class PrefillLink extends StatefulWidget {
  const PrefillLink({super.key, required this.serviceId, required this.onValues, this.createCubit});

  final String serviceId;

  /// Receives the values the person chose to copy (the form puts them in its fields).
  final void Function(PrefillValues values) onValues;

  /// Test seam; defaults to the DI container.
  final PrefillCubit Function()? createCubit;

  @override
  State<PrefillLink> createState() => _PrefillLinkState();
}

class _PrefillLinkState extends State<PrefillLink> {
  // Created here, closed in dispose().
  late final PrefillCubit _cubit = (widget.createCubit ?? () => InjectionContainer.instance.createPrefillCubit(widget.serviceId))()..load();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  Future<void> _choose(BuildContext context) async {
    final s = SeenStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final picked = await showSeenSheet<PrefillCandidate>(
      context: context,
      title: s.prefillSheetTitle,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final c in _cubit.state.candidates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Directionality(textDirection: TextDirection.ltr, child: Align(alignment: AlignmentDirectional.centerStart, child: Text(c.referenceCode))),
              subtitle: Text([
                if (c.serviceName.isNotEmpty) c.serviceName,
                if (c.createdAt != null) s.dayMonth(c.createdAt!),
                s.prefillTravelers(c.travelerCount),
              ].join(' · ')),
              onTap: () => Navigator.of(sheet).pop(c),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    final values = await _cubit.use(picked.requestId);
    if (!mounted) return;
    if (values == null) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failureTextOr(l10n, _cubit.state.failure, l10n.error))));
      return;
    }
    widget.onValues(values);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(values.isEmpty ? s.prefillNothing : s.prefillApplied)));
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return BlocBuilder<PrefillCubit, PrefillState>(
      bloc: _cubit,
      buildWhen: (a, b) => a.status != b.status,
      builder: (context, state) {
        if (state.status == PrefillStatus.loading || state.status == PrefillStatus.none) return const SizedBox.shrink();
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: state.status == PrefillStatus.using
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(s.prefillReading,
                      style: SeenType.of(context).caption.copyWith(color: SeenColors.of(context).inkMuted)),
                )
              : SeenTextLink(label: s.prefillLink, onTap: () => _choose(context)),
        );
      },
    );
  }
}
