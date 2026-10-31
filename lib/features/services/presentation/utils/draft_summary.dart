import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';
import '../../domain/entities/traveler_info.dart';

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
            if (f.isRequiredFor(t.fieldValues) && _blank(t.fieldValues[f.key])) f.label,
        ]),
    ];

/// Number of travelers whose required fields are all filled.
int completeTravelerCount(List<TravelerCompleteness> list) => list.where((t) => t.isComplete).length;
