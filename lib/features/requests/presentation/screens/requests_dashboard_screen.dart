import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/filters.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../services/presentation/screens/service_selection_screen.dart';
import '../../../support/presentation/bloc/notifications_bloc.dart';
import '../../../support/presentation/bloc/notifications_state.dart';
import '../../../support/presentation/screens/notifications_screen.dart';
import '../../domain/entities/request_summary.dart';
import '../bloc/requests_bloc.dart';
import '../bloc/requests_event.dart';
import '../bloc/requests_state.dart';
import '../widgets/request_status_seen_mapping.dart';
import '../widgets/seen_request_card.dart';
import 'request_detail_screen.dart';

/// Entry point for the Requests feature: filterable dashboard of every
/// request the current agent/company can see.
class RequestsDashboardScreen extends StatelessWidget {
  const RequestsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createRequestsBloc()
        ..add(const RequestsLoadRequested()),
      child: Scaffold(
        appBar: const _DashboardTopBar(),
        body: BlocBuilder<RequestsBloc, RequestsState>(
          builder: (context, state) {
            return switch (state) {
              RequestsInitial() || RequestsLoading() => const _SkeletonList(),
              RequestsFailure(:final message) => _ErrorView(message: message),
              RequestsLoaded() => _DashboardBody(state: state),
            };
          },
        ),
      ),
    );
  }
}

class _DashboardTopBar extends StatelessWidget implements PreferredSizeWidget {
  const _DashboardTopBar();

  @override
  Size get preferredSize => const Size.fromHeight(SeenSize.appBar);

  @override
  Widget build(BuildContext context) {
    int unread = 0;
    try {
      final notificationsState = context.watch<NotificationsBloc?>()?.state;
      if (notificationsState is NotificationsLoaded) {
        unread = notificationsState.unreadCount;
      }
    } catch (_) {}

    return SeenTopBar.home(
      company: 'شركة الجباري للسفر',
      agentId: 'وكيل رئيسي · AG-10427',
      unread: unread,
      onLanguage: () => context.read<LocaleCubit>().toggleLocale(),
      onNotifications: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
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
      padding: const EdgeInsets.all(SeenSpace.s4),
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
        borderRadius: const BorderRadius.all(SeenRadius.md),
        border: Border.all(color: c.border),
      ),
      padding: const EdgeInsets.all(SeenSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [block(12, 110), const Spacer(), block(24, 90)]),
          const SizedBox(height: SeenSpace.s3),
          block(20, 180),
          const SizedBox(height: SeenSpace.s2),
          block(14, 220),
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

  String _filterLabel(AppLocalizations l10n, RequestsDashboardFilter filter) => switch (filter) {
        RequestsDashboardFilter.all => l10n.requestsFilterAll,
        RequestsDashboardFilter.pendingUnderReview => l10n.requestsFilterPendingUnderReview,
        RequestsDashboardFilter.completed => l10n.requestsFilterCompleted,
        RequestsDashboardFilter.actionRequired => l10n.requestsFilterActionRequired,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    final state = widget.state;
    final requests = state.filteredRequests;

    final allCount = state.requests.length;
    final pendingCount = state.requests.where((r) =>
        r.status == RequestStatus.submitted ||
        r.status == RequestStatus.underReview ||
        r.status == RequestStatus.processing).length;
    final actionRequiredCount =
        state.requests.where((r) => r.status == RequestStatus.infoRequired).length;
    final completedCount =
        state.requests.where((r) => r.status == RequestStatus.completed).length;

    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return RefreshIndicator(
      onRefresh: () async {
        context.read<RequestsBloc>().add(const RequestsLoadRequested());
        await context.read<RequestsBloc>().stream.firstWhere((s) => s is! RequestsLoading);
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(SeenSpace.s4, SeenSpace.s4, SeenSpace.s4, SeenSpace.s3),
            child: Row(
              children: [
                Expanded(child: Text(l10n.requestsDashboardTitle, style: text.displayMedium)),
                SeenIconButton(
                  icon: SeenIcons.search,
                  semanticLabel: l10n.requestsSearchAction,
                  onPressed: () => setState(() => _searchOpen = !_searchOpen),
                ),
              ],
            ),
          ),
          if (_searchOpen)
            Padding(
              padding: const EdgeInsets.fromLTRB(SeenSpace.s4, 0, SeenSpace.s4, SeenSpace.s3),
              child: SeenTextField(
                label: l10n.requestsSearchAction,
                hint: l10n.requestsSearchHint,
                prefixIcon: SeenIcons.search,
                onChanged: (value) => context.read<RequestsBloc>().add(RequestsSearchChanged(value)),
              ),
            ),
          SeenSegmentChips(
            items: [
              for (final filter in RequestsDashboardFilter.values)
                SeenSegment(
                  label: _filterLabel(l10n, filter),
                  count: switch (filter) {
                    RequestsDashboardFilter.all => allCount > 0 ? allCount : null,
                    RequestsDashboardFilter.pendingUnderReview => pendingCount > 0 ? pendingCount : null,
                    RequestsDashboardFilter.actionRequired => actionRequiredCount > 0 ? actionRequiredCount : null,
                    RequestsDashboardFilter.completed => completedCount > 0 ? completedCount : null,
                  },
                  alert: filter == RequestsDashboardFilter.actionRequired,
                ),
            ],
            selectedIndex: RequestsDashboardFilter.values.indexOf(state.filter),
            onSelected: (i) => context
                .read<RequestsBloc>()
                .add(RequestsFilterChanged(RequestsDashboardFilter.values[i])),
          ),
          const SizedBox(height: SeenSpace.s2),
          Expanded(
            child: AnimatedSwitcher(
              duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 200),
              child: KeyedSubtree(
                key: ValueKey('${state.filter}-${state.searchQuery}'),
                child: requests.isEmpty
                    ? _EmptyState(hasQuery: state.searchQuery.trim().isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(SeenSpace.s4, 0, SeenSpace.s4, SeenSpace.s4),
                        itemCount: requests.length,
                        itemBuilder: (context, index) => Padding(
                          padding: const EdgeInsets.only(bottom: SeenSpace.s3),
                          child: _RequestCard(request: requests[index]),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery});

  /// Whether this empty result is from a search/filter combination — the
  /// spec's "no match" copy — vs. simply no data at all yet.
  final bool hasQuery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      // Keeps pull-to-refresh working even when the filtered list is empty.
      padding: const EdgeInsets.fromLTRB(SeenSpace.s4, SeenSpace.s6, SeenSpace.s4, SeenSpace.s4),
      children: [
        Container(
          padding: const EdgeInsets.all(SeenSpace.s6),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.all(SeenRadius.md),
            border: Border.all(color: c.border),
          ),
          child: Column(
            children: [
              Text(l10n.requestsEmptySearchTitle, style: text.titleMedium, textAlign: TextAlign.center),
              const SizedBox(height: SeenSpace.s2),
              Text(
                hasQuery ? l10n.requestsEmptySearchMessage : l10n.requestsEmptyMessage,
                style: text.bodySmall!.copyWith(color: c.inkMuted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: SeenSpace.s4),
              SeenButton.secondary(
                label: l10n.requestsBookNewAction,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ServiceSelectionScreen()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final RequestSummary request;

  @override
  Widget build(BuildContext context) {
    return SeenRequestCard(
      reference: request.referenceId,
      service: request.serviceName,
      travelers: request.travelerCount,
      date: SeenFormat.date(request.submittedAt),
      status: request.status.toSeenStatus,
      slaDeadline: request.slaDeadline,
      amount: request.totalPriceCents / 100,
      note: request.status == RequestStatus.infoRequired
          ? (request.rejectionNote ?? 'صورة الجواز غير واضحة — المسافر 1')
          : null,
      onTap: () {
        final bloc = context.read<RequestsBloc>();
        bloc.add(RequestDetailRequested(request.id));
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: bloc,
              child: const RequestDetailScreen(),
            ),
          ),
        );
      },
    );
  }
}
