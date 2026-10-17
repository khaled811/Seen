import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/booking_draft.dart';
import '../utils/draft_summary.dart';

/// What the user chose on the leave-form prompt.
enum LeaveFormChoice { save, discard }

/// "Save the request as a draft?" (Figma REQ-04), shown when leaving the
/// traveler form with data entered. Resolves to the choice, or `null` when it is
/// dismissed (the user stays on the form).
///
/// [existingDrafts] is how many drafts are already saved and [isUpdate] says this
/// booking already is one of them (saving overwrites, so the limit does not apply).
Future<LeaveFormChoice?> showSaveDraftSheet(
  BuildContext context, {
  required List<TravelerCompleteness> travelers,
  required int existingDrafts,
  required bool isUpdate,
}) {
  final l10n = AppLocalizations.of(context)!;
  final s = SeenStrings.of(context);
  final c = SeenColors.of(context);
  final t = SeenType.of(context);
  final full = !isUpdate && existingDrafts >= BookingDraft.maxCount;
  final done = completeTravelerCount(travelers);
  final amber = (ok: SeenRequestStatus.completed.colors.fg, warn: SeenRequestStatus.actionRequired.colors.fg);
  return showSeenSheet<LeaveFormChoice>(
    context: context,
    title: l10n.draftSaveTitle,
    subtitle: travelers.length == 1
        ? l10n.draftSaveSubtitleOne
        : l10n.draftSaveSubtitle(s.numeral(done), s.numeral(travelers.length)),
    builder: (_) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.all(SeenRadius.r22),
            border: Border.all(color: c.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final (i, tr) in travelers.indexed) ...[
                  if (i > 0) const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        tr.isComplete ? SeenIcons.check : Icons.info_rounded,
                        size: 16,
                        color: tr.isComplete ? amber.ok : amber.warn,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr.isComplete
                              ? l10n.draftSaveRowComplete(s.numeral(tr.index))
                              : l10n.draftSaveRowMissing(s.numeral(tr.index)),
                          style: t.label.copyWith(color: tr.isComplete ? c.ink : amber.warn),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (existingDrafts >= BookingDraft.maxCount - 2) ...[
          const SizedBox(height: 12),
          Text(
            full
                ? l10n.draftSaveFull(s.numeral(BookingDraft.maxCount))
                : l10n.draftSaveCount(s.numeral(existingDrafts), s.numeral(BookingDraft.maxCount)),
            style: t.caption.copyWith(color: full ? amber.warn : c.inkMuted),
          ),
        ],
      ],
    ),
    footerBuilder: (sheetContext) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeenButton(
          label: l10n.draftSaveAction,
          expand: true,
          onPressed: full ? null : () => Navigator.of(sheetContext).pop(LeaveFormChoice.save),
        ),
        const SizedBox(height: 8),
        Center(
          child: SeenTextLink(
            label: l10n.draftDiscardAction,
            onTap: () => Navigator.of(sheetContext).pop(LeaveFormChoice.discard),
          ),
        ),
      ],
    ),
  );
}
