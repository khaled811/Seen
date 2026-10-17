// Requests search (Figma REQ-13): a full-screen search by request number,
// service or traveler name, with the agent's recent searches and the results
// as cards. Results come from the requests already loaded by the dashboard's
// RequestsBloc (debounced `RequestsSearchChanged`); recents live in encrypted
// storage behind RecentSearchesCubit.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/request_summary.dart';
import '../bloc/recent_searches_cubit.dart';
import '../bloc/requests_bloc.dart';
import '../bloc/requests_event.dart';
import '../bloc/requests_state.dart';
import '../widgets/request_status_seen_mapping.dart';
import 'request_detail_screen.dart';

const _gutter = 20.0;

/// Opens the search over the dashboard's [RequestsBloc] (taken from [context]).
Future<void> openRequestsSearch(BuildContext context) {
  final bloc = context.read<RequestsBloc>();
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(value: bloc, child: const RequestsSearchScreen()),
    ),
  );
}

class RequestsSearchScreen extends StatelessWidget {
  const RequestsSearchScreen({super.key, this.createRecents});

  /// Test seam for the recent searches; defaults to the DI container.
  final RecentSearchesCubit Function()? createRecents;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createRecents ?? InjectionContainer.instance.createRecentSearchesCubit)()..load(),
      child: const _SearchView(),
    );
  }
}

class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  // Owned here, disposed in dispose(). Typing dispatches the bloc's debounced
  // search; the bloc is captured so dispose() does not read from a dead context.
  final _controller = TextEditingController();
  late final RequestsBloc _bloc = context.read<RequestsBloc>();

  @override
  void initState() {
    super.initState();
    // A previous search left on the dashboard must not pre-fill the results.
    _bloc.add(const RequestsSearchChanged(''));
  }

  @override
  void dispose() {
    _controller.dispose();
    // Leaving the search clears the query so the dashboard lists everything.
    if (!_bloc.isClosed) _bloc.add(const RequestsSearchChanged(''));
    super.dispose();
  }

  void _onChanged(String value) => _bloc.add(RequestsSearchChanged(value));

  void _applyRecent(String query) {
    _controller.value = TextEditingValue(text: query, selection: TextSelection.collapsed(offset: query.length));
    _onChanged(query);
  }

  void _remember() => context.read<RecentSearchesCubit>().remember(_controller.text);

  void _open(RequestSummary request) {
    _remember();
    _bloc.add(RequestDetailRequested(request.id));
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BlocProvider.value(value: _bloc, child: const RequestDetailScreen())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s3, _gutter, SeenSpace.s3),
                child: Row(
                  children: [
                    Expanded(
                      child: _Field(
                        controller: _controller,
                        hint: l10n.requestsSearchFieldHint,
                        onChanged: _onChanged,
                        onSubmitted: (_) => _remember(),
                      ),
                    ),
                    const SizedBox(width: SeenSpace.s2),
                    SeenTextLink(label: l10n.cancel, onTap: () => Navigator.of(context).maybePop()),
                  ],
                ),
              ),
              Expanded(
                child: BlocBuilder<RequestsBloc, RequestsState>(
                  buildWhen: (previous, current) =>
                      current is RequestsLoaded &&
                      (previous is! RequestsLoaded ||
                          previous.searchQuery != current.searchQuery ||
                          previous.requests != current.requests),
                  builder: (context, state) {
                    final loaded = state is RequestsLoaded ? state : null;
                    return ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s1, _gutter, SeenSpace.s6),
                      children: [
                        _Recents(onPick: _applyRecent),
                        if (loaded != null && loaded.searchQuery.trim().isNotEmpty)
                          ..._results(context, loaded),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _results(BuildContext context, RequestsLoaded state) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final query = state.searchQuery.trim();
    final results = state.searchResults;
    return [
      const SizedBox(height: 12),
      if (results.isNotEmpty) ...[
        Semantics(liveRegion: true, child: Text(s.searchResults(results.length, query), style: t.label)),
        for (final request in results) ...[
          const SizedBox(height: 12),
          _ResultCard(request: request, query: query, onTap: () => _open(request)),
        ],
      ] else
        _NoResults(title: l10n.requestsSearchNoResultsTitle(query)),
    ];
  }
}

/// The search pill: violet border while typing, search glyph at the start.
class _Field extends StatelessWidget {
  const _Field({required this.controller, required this.hint, required this.onChanged, required this.onSubmitted});

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.full),
        border: Border.all(color: c.primary),
      ),
      child: SizedBox(
        height: 44,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 14),
          child: Row(
            children: [
              const SeenSvgIcon(SeenVectors.catalogSearch, size: 18),
              const SizedBox(width: SeenSpace.s2),
              Expanded(
                child: Semantics(
                  label: hint,
                  textField: true,
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                    textInputAction: TextInputAction.search,
                    style: t.body.copyWith(color: c.ink),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: t.body.copyWith(color: c.inkMuted),
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      constraints: const BoxConstraints(),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Recent searches" caption and chips; hidden when there are none.
class _Recents extends StatelessWidget {
  const _Recents({required this.onPick});

  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return BlocBuilder<RecentSearchesCubit, List<String>>(
      builder: (context, recents) {
        if (recents.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(l10n.requestsSearchRecent, style: t.caption.copyWith(color: c.inkMuted)),
              for (final q in recents)
                Material(
                  color: SeenBrand.violet05,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    onTap: () => onPick(q),
                    customBorder: const StadiumBorder(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Text(q, style: t.caption.copyWith(color: c.inkSecondary)),
                    ),
                  ),
                ),
              SeenTextLink(
                label: l10n.requestsSearchClearRecent,
                onTap: () => context.read<RecentSearchesCubit>().clear(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// One result: the matching traveler (else the lead traveler or the service),
/// the status chip and the reference.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.request, required this.query, required this.onTap});

  final RequestSummary request;
  final String query;
  final VoidCallback onTap;

  String get _title {
    final q = query.toLowerCase();
    for (final name in request.travelerNames) {
      if (name.toLowerCase().contains(q)) return name;
    }
    return request.travelerNames.isNotEmpty ? request.travelerNames.first : request.serviceName;
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    final status = request.status.toSeenRequestStatus(slaDeadline: request.slaDeadline);
    return DecoratedBox(
      decoration: const BoxDecoration(boxShadow: SeenShadows.card, borderRadius: BorderRadius.all(SeenRadius.r22)),
      child: Material(
        color: c.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SeenRadius.r22),
          side: BorderSide(color: c.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.r22)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(_title, style: t.label, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: SeenSpace.s2),
                    SeenStatusChip(status: status, label: s.requestStatus(status)),
                  ],
                ),
                const SizedBox(height: 6),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(request.referenceId, style: t.caption.copyWith(color: c.primaryInk)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.all(SeenRadius.r22),
          border: Border.all(color: c.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(SeenRadius.r12)),
                child: SizedBox(width: 40, height: 40, child: Center(child: SeenSvgIcon(SeenVectors.catalogSearch, size: 22))),
              ),
              const SizedBox(height: 6),
              Text(title, textAlign: TextAlign.center, style: t.label),
              const SizedBox(height: 6),
              Text(
                l10n.requestsSearchNoResultsHint,
                textAlign: TextAlign.center,
                style: t.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
