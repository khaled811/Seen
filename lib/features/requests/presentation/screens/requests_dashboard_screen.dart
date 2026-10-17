import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/error_patterns.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/filters.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/stat_card.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../services/presentation/screens/service_selection_screen.dart';
import '../../../services/presentation/screens/drafts_screen.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';
import '../../domain/entities/request_summary.dart';
import '../bloc/requests_bloc.dart';
import '../bloc/requests_event.dart';
import '../bloc/requests_state.dart';
import '../widgets/request_status_seen_mapping.dart';
import '../widgets/seen_request_summary_card.dart';
import 'request_detail_screen.dart';
import 'requests_search_screen.dart';

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
                RequestsFailure() => Column(
                    children: [const _Header(), Expanded(child: _ErrorView(failure: state))],
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

/// Figma 06 header: the title at the start and a violet "new request" button
/// at the end.
class _Header extends StatelessWidget {
  const _Header({this.onSearch});

  /// null hides the search button (loading, error, or nothing to search yet).
  final VoidCallback? onSearch;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 12, _gutter, 12),
      child: Row(
        children: [
          Expanded(child: Text(l10n.requestsDashboardTitle, style: type.h1)),
          const _DraftsButton(),
          const SizedBox(width: SeenSpace.s2),
          // Product decision: reference / traveler search stays available
          // (the Figma header has only the plus button).
          if (onSearch != null) ...[
            Semantics(
              button: true,
              label: l10n.requestsSearchAction,
              excludeSemantics: true,
              child: DecoratedBox(
                decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: SeenShadows.card),
                child: Material(
                  color: c.card,
                  shape: CircleBorder(side: BorderSide(color: c.border)),
                  child: InkWell(
                    onTap: onSearch,
                    customBorder: const CircleBorder(),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SeenSvgIcon(SeenVectors.agentsSearch, size: 22, color: c.primary),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: SeenSpace.s2),
          ],
          Semantics(
            button: true,
            label: l10n.requestsBookNewAction,
            excludeSemantics: true,
            child: Material(
              color: SeenBrand.violet10,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => _openCatalog(context),
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: SeenSvgIcon(SeenVectors.requestsPlus, size: 22, color: c.primary)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// SYS-02: offline / timeout → an inline error with retry; a server error →
/// the full-screen pattern (SYS-02b) with the error code and reference.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.failure});

  final RequestsFailure failure;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    void retry() => context.read<RequestsBloc>().add(const RequestsLoadRequested());
    if (failure.offline) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Align(
          alignment: Alignment.topCenter,
          child: SeenInlineError(title: l10n.errorSectionLoad, retryLabel: l10n.retry, onRetry: retry),
        ),
      );
    }
    final ref = failure.reference;
    return SeenFullScreenError(
      title: l10n.errorUnexpectedTitle,
      body: ref == null ? l10n.errorUnexpectedBody : '${l10n.errorUnexpectedBody} ${l10n.errorReference(ref)}',
      retryLabel: l10n.retry,
      onRetry: retry,
      supportLabel: l10n.errorContactSupport,
      onSupport: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportTicketsScreen())),
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
            child: _Header(onSearch: noData ? null : () => openRequestsSearch(context)),
          ),
          if (!noData) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 18),
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
                    SeenSegment(label: _filterLabel(l10n, f), count: countOf(f)),
                ],
                selectedIndex: _filterOrder.indexOf(state.filter),
                onSelected: (i) => context.read<RequestsBloc>().add(RequestsFilterChanged(_filterOrder[i])),
              ),
            ),
            if (actionRequired.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(_gutter, 18, _gutter, 0),
                  child: _ActionBanner(count: actionRequired.length, earliestDeadline: earliest),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 18)),
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
                        topInset: 104,
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
                separatorBuilder: (_, __) => const SizedBox(height: 18),
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

/// Opens the drafts list (Figma REQ-01) with the number saved as a badge; hidden
/// when there are none. Counts through the use case (the list screen owns its
/// own bloc) and recounts when the user comes back.
class _DraftsButton extends StatefulWidget {
  const _DraftsButton();

  @override
  State<_DraftsButton> createState() => _DraftsButtonState();
}

class _DraftsButtonState extends State<_DraftsButton> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final result = await InjectionContainer.instance.getBookingDraftsUseCase();
    if (!mounted) return;
    setState(() => _count = result.fold((_) => 0, (list) => list.length));
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    return Semantics(
      button: true,
      label: '${l10n.draftsOpenAction} ${s.draftCount(_count)}',
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: SeenShadows.card),
            child: Material(
              color: c.card,
              shape: CircleBorder(side: BorderSide(color: c.border)),
              child: InkWell(
                onTap: () async {
                  await Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => const DraftsScreen()));
                  if (mounted) _refresh();
                },
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(child: Icon(Icons.edit_note_rounded, size: 24, color: c.primary)),
                ),
              ),
            ),
          ),
          PositionedDirectional(
            top: -2,
            end: -2,
            child: DecoratedBox(
              decoration: const BoxDecoration(color: SeenBrand.violet, borderRadius: BorderRadius.all(SeenRadius.full)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                child: Text(s.numeral(_count), style: SeenType.of(context).caption.copyWith(color: Colors.white)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
