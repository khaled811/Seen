import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/filters.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/stat_card.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../services/presentation/screens/service_selection_screen.dart';
import '../../domain/entities/request_summary.dart';
import '../bloc/requests_bloc.dart';
import '../bloc/requests_event.dart';
import '../bloc/requests_state.dart';
import '../widgets/request_status_seen_mapping.dart';
import '../widgets/seen_request_summary_card.dart';
import 'request_detail_screen.dart';

const _gutter = 14.0;

/// Requests dashboard (Figma 06, with the empty state of Figma 18): stats,
/// status filters, the 72h action banner and the request cards. The filter and
/// debounced search are still bloc state; this screen only renders them.
class RequestsDashboardScreen extends StatelessWidget {
  const RequestsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createRequestsBloc()..add(const RequestsLoadRequested()),
      child: Scaffold(
        backgroundColor: c.card,
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: BlocBuilder<RequestsBloc, RequestsState>(
              builder: (context, state) => switch (state) {
                RequestsInitial() || RequestsLoading() => const Column(
                    children: [_Header(), Expanded(child: _SkeletonList())],
                  ),
                RequestsFailure(:final message) => Column(
                    children: [const _Header(), Expanded(child: _ErrorView(message: message))],
                  ),
                RequestsLoaded() => _DashboardBody(state: state),
              },
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openCatalog(BuildContext context) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServiceSelectionScreen()));
  if (!context.mounted) return;
  context.read<RequestsBloc>().add(const RequestsLoadRequested());
}

/// Title row: back (when pushed), title, optional search toggle, new request.
class _Header extends StatelessWidget {
  const _Header({this.onSearch, this.searchOpen = false});

  final VoidCallback? onSearch;
  final bool searchOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final type = SeenType.of(context);
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s3, _gutter, SeenSpace.s3),
      child: Row(
        children: [
          if (canPop) ...[
            SeenRoundIconButton(
              icon: SeenIcons.back(context),
              semanticLabel: SeenStrings.of(context).back,
              tonal: true,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            const SizedBox(width: SeenSpace.s3),
          ],
          Expanded(child: Text(l10n.requestsDashboardTitle, style: type.h1)),
          if (onSearch != null) ...[
            SeenRoundIconButton(
              icon: searchOpen ? SeenIcons.x : SeenIcons.search,
              semanticLabel: l10n.requestsSearchAction,
              onPressed: onSearch,
            ),
            const SizedBox(width: SeenSpace.s2),
          ],
          SeenRoundIconButton(
            icon: SeenIcons.plus,
            semanticLabel: l10n.requestsBookNewAction,
            tonal: true,
            onPressed: () => _openCatalog(context),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: SeenSpace.s3),
          SeenButton(
            label: l10n.retry,
            onPressed: () => context.read<RequestsBloc>().add(const RequestsLoadRequested()),
          ),
        ],
      ),
    );
  }
}

/// First-load placeholder: 3 skeleton cards with a soft opacity pulse (no
/// shimmer), honouring `MediaQuery.disableAnimations`.
class _SkeletonList extends StatefulWidget {
  const _SkeletonList();

  @override
  State<_SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<_SkeletonList> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
  late final Animation<double> _opacity =
      Tween(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final content = Padding(
      padding: const EdgeInsets.all(_gutter),
      child: Column(children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < 2 ? SeenSpace.s3 : 0),
            child: const _SkeletonCard(),
          ),
      ]),
    );
    if (reduceMotion) return Opacity(opacity: 0.7, child: content);
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) => Opacity(opacity: _opacity.value, child: child),
      child: content,
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);

    Widget block(double height, double width) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(4)),
        );

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.all(SeenSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [block(44, 44), const SizedBox(width: SeenSpace.s3), block(16, 140), const Spacer(), block(28, 80)]),
          const SizedBox(height: SeenSpace.s3),
          block(5, 160),
          const SizedBox(height: SeenSpace.s2),
          block(12, 120),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatefulWidget {
  const _DashboardBody({required this.state});

  final RequestsLoaded state;

  @override
  State<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends State<_DashboardBody> {
  bool _searchOpen = false;

  /// Chip order from Figma (the enum order is the bloc's concern).
  static const _filterOrder = [
    RequestsDashboardFilter.all,
    RequestsDashboardFilter.pendingUnderReview,
    RequestsDashboardFilter.actionRequired,
    RequestsDashboardFilter.completed,
  ];

  String _filterLabel(AppLocalizations l10n, RequestsDashboardFilter filter) => switch (filter) {
        RequestsDashboardFilter.all => l10n.requestsFilterAll,
        RequestsDashboardFilter.pendingUnderReview => l10n.requestsFilterPendingUnderReview,
        RequestsDashboardFilter.completed => l10n.requestsFilterCompleted,
        RequestsDashboardFilter.actionRequired => l10n.requestsFilterActionRequired,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final state = widget.state;
    final requests = state.filteredRequests;

    final all = state.requests;
    final pendingCount = all
        .where((r) =>
            r.status == RequestStatus.submitted ||
            r.status == RequestStatus.underReview ||
            r.status == RequestStatus.processing)
        .length;
    final actionRequired = all.where((r) => r.status == RequestStatus.infoRequired).toList();
    final completedCount = all.where((r) => r.status == RequestStatus.completed).length;
    final noData = all.isEmpty;

    int? countOf(RequestsDashboardFilter f) {
      final n = switch (f) {
        RequestsDashboardFilter.all => all.length,
        RequestsDashboardFilter.pendingUnderReview => pendingCount,
        RequestsDashboardFilter.actionRequired => actionRequired.length,
        RequestsDashboardFilter.completed => completedCount,
      };
      return n > 0 ? n : null;
    }

    // Earliest SLA deadline among action-required requests drives the banner.
    final deadlines = [for (final r in actionRequired) if (r.slaDeadline != null) r.slaDeadline!]
      ..sort();
    final earliest = deadlines.isEmpty ? null : deadlines.first;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<RequestsBloc>().add(const RequestsLoadRequested());
        await context.read<RequestsBloc>().stream.firstWhere((s) => s is! RequestsLoading);
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              onSearch: noData ? null : () => setState(() => _searchOpen = !_searchOpen),
              searchOpen: _searchOpen,
            ),
          ),
          if (_searchOpen && !noData)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, SeenSpace.s3),
                child: SeenTextField(
                  label: l10n.requestsSearchAction,
                  hint: l10n.requestsSearchHint,
                  prefixIcon: SeenIcons.search,
                  onChanged: (value) => context.read<RequestsBloc>().add(RequestsSearchChanged(value)),
                ),
              ),
            ),
          if (!noData) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, SeenSpace.s3),
                child: Row(
                  children: [
                    Expanded(
                      child: SeenStatCard(
                        label: l10n.requestsStatAll,
                        value: s.numeral(all.length),
                        dotColor: c.inkMuted,
                      ),
                    ),
                    const SizedBox(width: SeenSpace.s2),
                    Expanded(
                      child: SeenStatCard(
                        label: l10n.requestsStatProcessing,
                        value: s.numeral(pendingCount),
                        dotColor: SeenBrand.violet,
                      ),
                    ),
                    const SizedBox(width: SeenSpace.s2),
                    Expanded(
                      child: SeenStatCard(
                        label: l10n.requestsStatActionRequired,
                        value: s.numeral(actionRequired.length),
                        dotColor: SeenBrand.progressWaiting,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SeenSegmentChips(
                padding: const EdgeInsets.symmetric(horizontal: _gutter),
                items: [
                  for (final f in _filterOrder)
                    SeenSegment(label: _filterLabel(l10n, f), count: countOf(f), alert: f == RequestsDashboardFilter.actionRequired),
                ],
                selectedIndex: _filterOrder.indexOf(state.filter),
                onSelected: (i) => context.read<RequestsBloc>().add(RequestsFilterChanged(_filterOrder[i])),
              ),
            ),
            if (actionRequired.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s3, _gutter, 0),
                  child: _ActionBanner(count: actionRequired.length, earliestDeadline: earliest),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: SeenSpace.s3)),
          ],
          if (requests.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(_gutter),
                child: noData
                    // Figma 18: nothing at all yet — invite the first request.
                    ? SeenEmptyState(
                        iconAsset: SeenVectors.iconRequests,
                        title: l10n.requestsEmptyTitle,
                        message: l10n.requestsEmptyBody,
                        actionLabel: l10n.homeRequestServiceAction,
                        onAction: () => _openCatalog(context),
                      )
                    // Filter / search produced nothing.
                    : SeenEmptyState(
                        iconAsset: SeenVectors.iconRequests,
                        title: l10n.requestsEmptySearchTitle,
                        message: state.searchQuery.trim().isNotEmpty
                            ? l10n.requestsEmptySearchMessage
                            : l10n.requestsEmptyMessage,
                      ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, SeenSpace.s6),
              sliver: SliverList.separated(
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: SeenSpace.s3),
                itemBuilder: (context, index) => _RequestCard(request: requests[index]),
              ),
            ),
        ],
      ),
    );
  }
}

/// "N requests awaiting documents" with the time left on the earliest 72h window.
class _ActionBanner extends StatelessWidget {
  const _ActionBanner({required this.count, required this.earliestDeadline});

  final int count;
  final DateTime? earliestDeadline;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final colors = SeenRequestStatus.actionRequired.colors;
    final type = SeenType.of(context);
    final state = seenCountdownState(earliestDeadline);
    final left = earliestDeadline?.difference(DateTime.now());

    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bg, borderRadius: const BorderRadius.all(SeenRadius.r18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.all(SeenRadius.r12)),
              child: SizedBox(width: 36, height: 36, child: Icon(SeenIcons.alert, size: 20, color: colors.fg)),
            ),
            const SizedBox(width: SeenSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.actionBannerTitle(count), style: type.bodyStrong.copyWith(color: colors.fg)),
                  Text(
                    l10n.requestsActionBannerBody,
                    style: type.caption.copyWith(color: colors.fg.withAlpha(0xD9)),
                  ),
                ],
              ),
            ),
            if (state != null && left != null && left > Duration.zero) ...[
              const SizedBox(width: SeenSpace.s3),
              SeenCountdownPill(label: s.clockHm(left.inHours, left.inMinutes.remainder(60)), state: state),
            ],
          ],
        ),
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final RequestSummary request;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final isAction = request.status == RequestStatus.infoRequired;
    return SeenRequestSummaryCard(
      title: request.serviceName,
      subtitle: s.travelerCount(request.travelerCount),
      status: request.status.toSeenRequestStatus(slaDeadline: request.slaDeadline),
      progress: request.status.progress,
      reference: request.referenceId,
      dateLabel: SeenFormat.date(request.submittedAt),
      slaDeadline: isAction ? request.slaDeadline : null,
      note: isAction ? request.rejectionNote : null,
      onTap: () {
        final bloc = context.read<RequestsBloc>();
        bloc.add(RequestDetailRequested(request.id));
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(value: bloc, child: const RequestDetailScreen()),
          ),
        );
      },
    );
  }
}
