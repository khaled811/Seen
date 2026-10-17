// Date picker sheet (Figma BOOK-04): calendar within the field's allowed range, the
// rule that applies (e.g. 6 months of passport validity) and a confirm button.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';

Future<DateTime?> showSeenDateSheet({
  required BuildContext context,
  required String title,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initial,
  String? rule,
}) {
  return showSeenSheet<DateTime>(
    context: context,
    title: title,
    subtitle: rule,
    builder: (_) => _DateBody(firstDate: firstDate, lastDate: lastDate, initial: initial),
  );
}

class _DateBody extends StatefulWidget {
  const _DateBody({required this.firstDate, required this.lastDate, this.initial});

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initial;

  @override
  State<_DateBody> createState() => _DateBodyState();
}

class _DateBodyState extends State<_DateBody> {
  late DateTime _value = _clamp(widget.initial ?? DateTime.now());

  DateTime _clamp(DateTime d) =>
      d.isBefore(widget.firstDate) ? widget.firstDate : (d.isAfter(widget.lastDate) ? widget.lastDate : d);

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalendarDatePicker(
          initialDate: _value,
          firstDate: widget.firstDate,
          lastDate: widget.lastDate,
          onDateChanged: (d) => setState(() => _value = d),
        ),
        Text('${s.dateSelected}: ${s.dayMonth(_value)} ${s.numeral(_value.year)}',
            style: t.caption.copyWith(color: c.inkMuted), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        SeenButton(
          label: s.dateConfirm,
          expand: true,
          onPressed: () => Navigator.of(context).pop(_value),
        ),
      ],
    );
  }
}
