// Group manifest · summary and per-traveler status (Figma REQ-14b): the manifest as a whole,
// then each traveler with their own status and progress. A rejected traveler can be sent
// again and never holds back the rest.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/manifest.dart';
import '../bloc/manifest_build_cubit.dart' show ManifestLoad;
import '../bloc/manifest_summary_cubit.dart';
import '../widgets/manifest_row_shell.dart';
import '../widgets/manifest_strings.dart';

class ManifestSummaryScreen extends StatelessWidget {
  const ManifestSummaryScreen(
      {super.key, required this.manifestId, this.createCubit});

  final String manifestId;

  /// Test seam: the cubit (defaults to DI).
  final ManifestSummaryCubit Function()? createCubit;

  static Route<void> route(String manifestId) => MaterialPageRoute<void>(
      builder: (_) => ManifestSummaryScreen(manifestId: manifestId));

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createCubit ??
          () => InjectionContainer.instance
              .createManifestSummaryCubit(manifestId))()
        ..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: BlocConsumer<ManifestSummaryCubit, ManifestSummaryState>(
            listenWhen: (p, n) =>
                p.noticeSeq != n.noticeSeq && n.notice != null,
            listener: (context, state) => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                  SnackBar(content: Text(s.summaryNotice(state.notice!)))),
            builder: (context, state) {
              final cubit = context.read<ManifestSummaryCubit>();
              final summary = state.summary;
              return Column(
                children: [
                  SeenScreenHeader(
                    title: s.manifestSummaryTitle,
                    subtitle: summary == null
                        ? null
                        : '${summary.reference} · ${s.travelersCount(summary.travelers.length)}',
                  ),
                  Expanded(
                    child: switch (state.load) {
                      ManifestLoad.loading => const _Loading(),
                      ManifestLoad.failure => Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(s.summaryLoadFailed),
                              const SizedBox(height: SeenSpace.s3),
                              SeenButton(
                                  label: s.retryAction, onPressed: cubit.load),
                            ],
                          ),
                        ),
                      ManifestLoad.loaded =>
                        _Body(summary: summary!, state: state),
                    },
                  ),
                  if (state.load == ManifestLoad.loaded && summary != null)
                    SeenActionBar(
                      actions: [
                        SeenButton.secondary(
                          label: s.downloadIssued(
                              summary.count(ManifestOutcome.issued)),
                          expand: true,
                          loading: state.downloading,
                          onPressed: state.busy ||
                                  summary.count(ManifestOutcome.issued) == 0
                              ? null
                              : cubit.downloadIssued,
                        ),
                      ],
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const SeenSkeletonGroup(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SeenSkeletonBox(height: 150, radius: 24),
              SizedBox(height: 14),
              SeenSkeletonBox(height: 280, radius: 22),
            ],
          ),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({required this.summary, required this.state});

  final ManifestSummary summary;
  final ManifestSummaryState state;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final n = summary.travelers.length;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HeroCard(summary: summary),
                const SizedBox(height: 14),
                Text(s.independentStatusNote,
                    style: t.caption.copyWith(color: c.inkMuted)),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          sliver: SliverList.builder(
            itemCount: n,
            itemBuilder: (context, i) => ManifestRowShell(
              first: i == 0,
              last: i == n - 1,
              child: _StatusRow(
                  traveler: summary.travelers[i],
                  busy: state.busyTravelerId == summary.travelers[i].id,
                  locked: state.busy),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.summary});

  final ManifestSummary summary;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final white = c.onPrimary;
    final inFlight = summary.count(ManifestOutcome.atAuthority) > 0;
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(SeenRadius.r24),
        boxShadow: [
          BoxShadow(
              color: Color(0x142C186A),
              blurRadius: 16,
              spreadRadius: -6,
              offset: Offset(0, 8)),
          BoxShadow(
              color: Color(0x385B36DA),
              blurRadius: 48,
              spreadRadius: -12,
              offset: Offset(0, 24)),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(SeenRadius.r24),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: [SeenBrand.violet, Color(0xFFC3B0FC)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: -80,
                top: -128,
                width: 291,
                height: 419,
                child: ExcludeSemantics(
                    child: SvgPicture.asset(SeenVectors.walletPatternGrid,
                        fit: BoxFit.fill)),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: Text(summary.reference,
                                textDirection: TextDirection.ltr,
                                style: t.label.copyWith(color: white))),
                        SeenStatusChip(
                          status: inFlight
                              ? SeenRequestStatus.processing
                              : SeenRequestStatus.completed,
                          label: inFlight
                              ? s.manifestProcessing
                              : s.manifestCompleted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(summary.title, style: t.h2.copyWith(color: white)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _Stat(
                            count: summary.count(ManifestOutcome.issued),
                            label: s.statusIssued),
                        const SizedBox(width: 8),
                        _Stat(
                            count: summary.count(ManifestOutcome.atAuthority),
                            label: s.statusAtAuthority),
                        const SizedBox(width: 8),
                        _Stat(
                            count: summary.count(ManifestOutcome.rejected),
                            label: s.statusRejected),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.count, required this.label});

  final int count;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final white = SeenColors.of(context).onPrimary;
    return Expanded(
      child: DecoratedBox(
        decoration: const BoxDecoration(
            color: Color(0x2EFFFFFF),
            borderRadius: BorderRadius.all(SeenRadius.r12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Text(s.numeral(count), style: t.h2.copyWith(color: white)),
              Text(label,
                  style: t.caption.copyWith(color: white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow(
      {required this.traveler, required this.busy, required this.locked});

  final ManifestTravelerStatus traveler;
  final bool busy;

  /// Another action is running: nothing else can be started.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final (status, label) = switch (traveler.outcome) {
      ManifestOutcome.issued => (SeenRequestStatus.completed, s.statusIssued),
      ManifestOutcome.atAuthority => (
          SeenRequestStatus.withAuthority,
          s.statusAtAuthority
        ),
      ManifestOutcome.rejected => (
          SeenRequestStatus.rejected,
          s.statusRejected
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
                child: Text(traveler.name,
                    style: t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            SeenStatusChip(status: status, label: label),
          ],
        ),
        const SizedBox(height: 8),
        _Steps(done: traveler.doneSteps),
        if (traveler.outcome == ManifestOutcome.rejected) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.rejectionReason(traveler.rejectionReason ?? '—'),
                  style: t.caption
                      .copyWith(color: SeenRequestStatus.rejected.colors.fg),
                ),
              ),
              SeenButton.ghost(
                label: s.resubmitAction,
                size: SeenButtonSize.small,
                loading: busy,
                onPressed: locked
                    ? null
                    : () => context
                        .read<ManifestSummaryCubit>()
                        .resubmit(traveler.id),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// The journey as [ManifestTravelerStatus.totalSteps] thin segments, done ones first.
class _Steps extends StatelessWidget {
  const _Steps({required this.done});

  final int done;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < ManifestTravelerStatus.totalSteps; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                height: 5,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: i < done
                        ? SeenBrand.progressDone
                        : SeenBrand.progressTodo,
                    borderRadius: const BorderRadius.all(Radius.circular(3)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
