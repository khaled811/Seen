// Searchable options sheet (Figma BOOK-03 nationality, BOOK-05 select): search box,
// recents, selected mark, "no results" state. Returns the picked option value.
import 'package:flutter/material.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/selection.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../dynamic_forms/domain/entities/dynamic_form_field.dart';

/// Picks made in this app session, newest first, per field key. Local only.
abstract final class RecentOptions {
  static final _byKey = <String, List<String>>{};
  static const max = 3;

  static List<String> of(String key) => List.unmodifiable(_byKey[key] ?? const <String>[]);

  static void remember(String key, String value) {
    final list = _byKey.putIfAbsent(key, () => <String>[]);
    list
      ..remove(value)
      ..insert(0, value);
    if (list.length > max) list.removeRange(max, list.length);
  }
}

/// Options shown without a search box up to this count.
const seenOptionsSearchThreshold = 7;

Future<String?> showSeenOptionsSheet({
  required BuildContext context,
  required String title,
  required String recentsKey,
  required List<FieldOption> options,
  String? selected,
}) async {
  final picked = await showSeenSheet<String>(
    context: context,
    title: title,
    builder: (ctx) => _OptionsBody(recentsKey: recentsKey, options: options, selected: selected),
  );
  if (picked != null) RecentOptions.remember(recentsKey, picked);
  return picked;
}

class _OptionsBody extends StatefulWidget {
  const _OptionsBody({required this.recentsKey, required this.options, this.selected});

  final String recentsKey;
  final List<FieldOption> options;
  final String? selected;

  @override
  State<_OptionsBody> createState() => _OptionsBodyState();
}

class _OptionsBodyState extends State<_OptionsBody> {
  // Owned here, disposed in dispose().
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(FieldOption o) {
    final q = _query.trim().toLowerCase();
    return q.isEmpty || o.label.toLowerCase().contains(q) || (o.description?.toLowerCase().contains(q) ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    final searchable = widget.options.length >= seenOptionsSearchThreshold;
    final filtered = widget.options.where(_matches).toList();
    final recents = _query.trim().isEmpty
        ? [
            for (final v in RecentOptions.of(widget.recentsKey))
              ...widget.options.where((o) => o.value == v),
          ]
        : const <FieldOption>[];

    Widget row(FieldOption o) {
      final active = o.value == widget.selected;
      return InkWell(
        onTap: () => Navigator.of(context).pop(o.value),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              SeenRadioDot(selected: active),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(o.label, style: t.body.copyWith(color: active ? c.primary : c.ink)),
                    if (o.description != null)
                      Text(o.description!, style: t.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget header(String text) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(text, style: t.caption.copyWith(color: c.inkMuted)),
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (searchable) ...[
          SeenTextField(
            label: s.optionsSearchHint,
            controller: _search,
            prefixIcon: SeenIcons.search,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
        ],
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Icon(SeenIcons.search, size: 28, color: c.inkMuted),
                const SizedBox(height: 8),
                Text(s.optionsNoMatch(_query.trim()), style: t.body, textAlign: TextAlign.center),
                Text(s.optionsNoMatchHint, style: t.caption.copyWith(color: c.inkMuted), textAlign: TextAlign.center),
              ],
            ),
          )
        else ...[
          if (recents.isNotEmpty) ...[header(s.optionsRecent), for (final o in recents) row(o), header(s.optionsAll)],
          for (final o in filtered) row(o),
        ],
      ],
    );
  }
}
