// The category picker of a new ticket (design/gaps SUP-07): search, a card of rows with a radio,
// and «Other» always last. The categories come from the server; if they cannot be loaded, «Other»
// is still there.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/utils/arabic_search.dart';
import '../../domain/entities/ticket_category_option.dart';
import '../bloc/ticket_categories_cubit.dart';

/// Opens the sheet; resolves the picked category, or null when it was dismissed. [cubit] is read
/// (and told to load) by the sheet and stays owned by the caller.
Future<TicketCategoryOption?> showTicketCategorySheet(
  BuildContext context, {
  required TicketCategoriesCubit cubit,
  String? selectedCode,
}) {
  final l10n = AppLocalizations.of(context)!;
  if (cubit.state.loading || cubit.state.failed) {
    cubit.load();
  }
  return showSeenSheet<TicketCategoryOption>(
    context: context,
    title: l10n.supCategorySheetTitle,
    subtitle: l10n.supCategorySheetSub,
    builder: (_) => BlocProvider.value(value: cubit, child: _Body(selectedCode: selectedCode)),
  );
}

class _Body extends StatefulWidget {
  const _Body({required this.selectedCode});

  final String? selectedCode;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  // Owned here, disposed in dispose().
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return BlocBuilder<TicketCategoriesCubit, TicketCategoriesState>(
      builder: (context, state) {
        final other = TicketCategoryOption(code: TicketCategoryOption.otherCode, name: l10n.supCategoryOther);
        final matching = [for (final o in state.options) if (ArabicSearch.matches(_query, o.name)) o];
        // «Other» is always offered; it matches a search too, but is never hidden by it entirely.
        final rows = [...matching, other];
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SeenTextField(
                label: '',
                controller: _search,
                hint: l10n.supCategorySearch,
                prefixIcon: SeenIcons.search,
                enabled: !state.loading,
                suffix: _query.isEmpty
                    ? null
                    : Semantics(
                        button: true,
                        label: l10n.commonClose,
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _search.clear();
                            _query = '';
                          }),
                          child: Icon(SeenIcons.x, size: 18, color: c.inkSecondary),
                        ),
                      ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 12),
              if (state.loading)
                for (var i = 0; i < 5; i++) const Padding(padding: EdgeInsets.only(bottom: 8), child: SeenSkeletonBox(height: 52, radius: 16))
              else ...[
                if (state.failed) ...[
                  SeenInlineBanner(
                    tone: SeenBannerTone.error,
                    message: '${l10n.commonErrorTitle}. ${l10n.supCategoryLoadError}',
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SeenButton.outline(label: l10n.commonRetry, size: SeenButtonSize.small, onPressed: context.read<TicketCategoriesCubit>().load),
                  ),
                  const SizedBox(height: 12),
                ] else if (matching.isEmpty && _query.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        Text(l10n.supCategoryNoResultsTitle, style: type.title, textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        Text(l10n.supCategoryNoResultsBody, style: type.caption.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ],
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.card,
                    border: Border.all(color: c.border),
                    borderRadius: const BorderRadius.all(SeenRadius.r22),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        _Row(
                          option: rows[i],
                          query: _query,
                          subtitle: rows[i].isOther ? l10n.supCategoryOtherSub : null,
                          selected: rows[i].code == (widget.selectedCode ?? ''),
                          last: i == rows.length - 1,
                          onTap: () => Navigator.of(context).pop(rows[i]),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.option, required this.query, required this.selected, required this.last, required this.onTap, this.subtitle});

  final TicketCategoryOption option;
  final String query;
  final String? subtitle;
  final bool selected;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final range = ArabicSearch.range(query, option.name);
    Widget title;
    if (range == null) {
      title = Text(option.name, style: type.bodyStrong);
    } else {
      // The match is shown on a soft violet background (mapped back onto the original text).
      title = Text.rich(TextSpan(style: type.bodyStrong, children: [
        TextSpan(text: option.name.substring(0, range.start)),
        TextSpan(
          text: option.name.substring(range.start, range.end),
          style: TextStyle(backgroundColor: c.accentSoft, color: SeenRequestStatus.underReview.colors.fg),
        ),
        TextSpan(text: option.name.substring(range.end)),
      ]));
    }
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.border))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: const BorderRadius.all(SeenRadius.r12)),
                  child: SizedBox(width: 36, height: 36, child: Icon(SeenIcons.tag, size: 20, color: c.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      title,
                      if (subtitle != null) Text(subtitle!, style: type.caption.copyWith(color: c.inkSecondary)),
                    ],
                  ),
                ),
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 22, color: selected ? c.accent : c.borderStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
