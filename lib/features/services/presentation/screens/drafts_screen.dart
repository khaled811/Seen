import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_patterns.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/presentation/widgets/loading/seen_loader.dart';
import '../../../../core/presentation/widgets/loading/seen_wait_policy.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../requests/domain/entities/request_summary.dart';
import '../../domain/entities/service_definition.dart';
import '../bloc/drafts_bloc.dart';
import '../bloc/service_booking_bloc.dart';
import '../bloc/service_booking_event.dart';
import '../widgets/seen_draft_card.dart';
import '../widgets/service_card_copy.dart';
import 'booking_review_screen.dart';
import 'service_selection_screen.dart';

/// Drafts list (Figma REQ-01): the agent's unfinished requests as the server
/// holds them (`portalRequests(group: draft)`), with Continue (opens the review)
/// only: the API cannot cancel or delete a draft. Nothing is kept on the device.
/// Owns a [DraftsBloc].
class DraftsScreen extends StatelessWidget {
  const DraftsScreen({super.key, this.createBloc, this.clock = DateTime.now});

  /// Test seams.
  final DraftsBloc Function()? createBloc;
  final DateTime Function() clock;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createBloc ?? InjectionContainer.instance.createDraftsBloc)()..add(const DraftsLoadRequested()),
      child: _View(clock: clock),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.clock});

  final DateTime Function() clock;

  /// A draft's travelers are the server's and cannot be edited: opening it goes to
  /// the review, where it can be submitted.
  Future<void> _continue(BuildContext context, RequestSummary draft) async {
    final bloc = context.read<DraftsBloc>();
    final validator = ServiceSelectionScreen.buildValidator(AppLocalizations.of(context)!);
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider<ServiceBookingBloc>(
          create: (_) => InjectionContainer.instance.createServiceBookingBloc(validator: validator)
            ..add(BookingDraftOpened(draft.id)),
          child: const BookingReviewScreen(),
        ),
      ),
    );
    // The draft may have been submitted meanwhile.
    bloc.add(const DraftsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    return BlocBuilder<DraftsBloc, DraftsState>(
      builder: (context, state) {
        final now = clock();
        return Scaffold(
          body: SeenScreenBackground(
            washHeight: 320,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SeenScreenHeader(
                    title: l10n.draftsTitle,
                    subtitle: state.status == DraftsStatus.ready && state.drafts.isNotEmpty
                        ? s.draftCount(state.drafts.length)
                        : null,
                  ),
                  Expanded(
                    child: switch (state.status) {
                      DraftsStatus.loading => SeenWaitPolicy.loading(
                        loading: SeenCardsSkeleton(count: 2, label: SeenStrings.of(context).loadingLabel),
                        onRetry: () => context.read<DraftsBloc>().add(const DraftsLoadRequested()),
                      ),
                      DraftsStatus.failed => Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: SeenInlineError(
                              title: l10n.errorSectionLoad,
                              retryLabel: l10n.retry,
                              onRetry: () => context.read<DraftsBloc>().add(const DraftsLoadRequested()),
                            ),
                          ),
                        ),
                      DraftsStatus.ready when state.drafts.isEmpty => SeenEmptyState(
                          iconAsset: SeenVectors.iconRequests,
                          title: l10n.draftsEmptyTitle,
                          message: l10n.draftsEmptyBody,
                          topInset: 80,
                        ),
                      DraftsStatus.ready => ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                          // The info card, then the drafts, then (when the server has more) a
                          // spinner that asks for the next page as it scrolls into view.
                          itemCount: 1 + state.drafts.length + (state.hasMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == 0) return _InfoCard(text: l10n.draftsInfo);
                            if (index > state.drafts.length) return const _LoadMoreTrigger();
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _card(context, state.drafts[index - 1], now, l10n, s,
                                  isLast: state.drafts.length == 1),
                            );
                          },
                        ),
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, RequestSummary d, DateTime now, AppLocalizations l10n, SeenStrings s,
      {required bool isLast}) {
    return SeenDraftCard(
      title: d.serviceName,
      subtitle: s.travelerCount(d.travelerCount),
      chipLabel: l10n.draftChip,
      iconAsset: ServiceCardCopy.forCategory(ServiceCategory.unknown, l10n).iconAsset,
      continueLabel: l10n.draftContinue,
      ageLabel: s.draftAge(d.submittedAt, now: now),
      onContinue: () => _continue(context, d),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    final colors = SeenRequestStatus.underReview.colors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bg, borderRadius: const BorderRadius.all(SeenRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const SeenSvgIcon(SeenVectors.infoReview, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: t.label.copyWith(color: colors.fg))),
          ],
        ),
      ),
    );
  }
}

/// Asks for the next page of drafts once it is built (lazy list end).
class _LoadMoreTrigger extends StatefulWidget {
  const _LoadMoreTrigger();

  @override
  State<_LoadMoreTrigger> createState() => _LoadMoreTriggerState();
}

class _LoadMoreTriggerState extends State<_LoadMoreTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DraftsBloc>().add(const DraftsLoadMoreRequested());
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: SeenLoader()));
}
