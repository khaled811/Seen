import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_typography.dart';

enum SuggestionConfidence { high, low }

/// One value read from a passport, offered for the person to accept (design/gaps SPEC §3.2): a
/// checkbox, the field's name, the value, and a chip when the reading is doubtful or was applied.
///
/// A doubtful row sits on a soft violet background and starts unchecked. An applied row shows its
/// own chip. The value is shown left to right unless it is Arabic text ([ltr] = false).
class SuggestionRow extends StatelessWidget {
  const SuggestionRow({
    super.key,
    required this.field,
    required this.value,
    required this.checked,
    required this.onChanged,
    required this.lowConfidenceLabel,
    required this.appliedLabel,
    this.confidence = SuggestionConfidence.high,
    this.applied = false,
    this.ltr = true,
    this.first = false,
  });

  final String field;
  final String value;
  final bool checked;

  /// Null = the row cannot be changed (it was applied already).
  final ValueChanged<bool>? onChanged;
  final SuggestionConfidence confidence;
  final bool applied;
  final bool ltr;

  /// The first row of a card has no divider above it.
  final bool first;

  final String lowConfidenceLabel;
  final String appliedLabel;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final low = confidence == SuggestionConfidence.low && !applied;
    final chip = applied ? SeenRequestStatus.completed.colors : SeenRequestStatus.actionRequired.colors;
    return Semantics(
      container: true,
      checked: checked,
      label: '$field $value',
      onTap: onChanged == null ? null : () => onChanged!(!checked),
      excludeSemantics: true,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!checked),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: low ? SeenBrand.violet05 : (applied ? c.card : null),
            border: first ? null : Border(top: BorderSide(color: c.border)),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  _Check(checked: checked),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(field, style: type.caption.copyWith(color: c.inkSecondary)),
                        const SizedBox(height: 2),
                        // The row's start edge (the right in Arabic) even when the value itself reads left to right.
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Directionality(textDirection: ltr ? TextDirection.ltr : Directionality.of(context), child: Text(value, style: type.bodyStrong)),
                        ),
                      ],
                    ),
                  ),
                  if (low || applied) ...[
                    const SizedBox(width: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(color: applied ? c.card : chip.bg, borderRadius: const BorderRadius.all(Radius.circular(999)), border: applied ? Border.all(color: chip.bg) : null),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        child: Text(applied ? appliedLabel : lowConfidenceLabel, style: type.chipS.copyWith(color: chip.fg)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? SeenBrand.violet : null,
        borderRadius: BorderRadius.circular(7),
        border: checked ? null : Border.all(color: c.borderStrong, width: 1.5),
      ),
      child: checked ? Icon(Icons.check, size: 16, color: c.onPrimary) : null,
    );
  }
}
