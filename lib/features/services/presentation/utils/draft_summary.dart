import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';
import '../../domain/entities/booking_draft.dart';
import '../../domain/entities/traveler_info.dart';
import '../widgets/service_traveler_fields.dart';

/// What is still missing for one traveler: the labels of the required fields
/// with no value yet.
class TravelerCompleteness {
  const TravelerCompleteness(this.index, this.missingLabels);

  /// 1-based, as shown to the user.
  final int index;
  final List<String> missingLabels;

  bool get isComplete => missingLabels.isEmpty;
}

bool _blank(Object? v) => v == null || (v is String && v.trim().isEmpty);

/// Whether the user typed anything at all (a booking with nothing entered is not
/// worth a "save as draft" prompt).
bool hasAnyTravelerData(List<TravelerInfo> travelers) =>
    travelers.any((t) => t.fieldValues.values.any((v) => !_blank(v)));

List<TravelerCompleteness> travelerCompleteness(List<TravelerInfo> travelers, List<DynamicFormField> fields) => [
      for (final (i, t) in travelers.indexed)
        TravelerCompleteness(i + 1, [
          for (final f in fields)
            if (f.required && _blank(t.fieldValues[f.key])) f.label,
        ]),
    ];

/// Number of travelers whose required fields are all filled.
int completeTravelerCount(List<TravelerCompleteness> list) => list.where((t) => t.isComplete).length;

/// The "Missing: …" line of a draft card, or null when the draft is complete:
/// the field name when exactly one thing is missing, else which travelers.
String? draftMissingLine(BookingDraft draft, AppLocalizations l10n, SeenStrings s) {
  final fields = ServiceTravelerFields.forCategory(draft.category, l10n);
  final incomplete = travelerCompleteness(draft.travelers, fields).where((t) => !t.isComplete).toList();
  if (incomplete.isEmpty) return null;
  if (incomplete.length == 1) {
    final t = incomplete.single;
    final what = t.missingLabels.length == 1 ? t.missingLabels.single : l10n.draftMissingTraveler(s.numeral(t.index));
    return l10n.draftMissing(what);
  }
  return l10n.draftMissing(l10n.draftMissingTravelers(s.numeral(incomplete.length)));
}
