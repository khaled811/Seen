import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_motion_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/motion_icon.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/steppers.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../support/presentation/screens/support_tickets_screen.dart';
import '../../domain/entities/request_detail.dart';
import '../../domain/entities/request_traveler_status.dart';
import '../bloc/requests_bloc.dart';
import '../bloc/requests_event.dart';
import '../bloc/requests_state.dart';
import '../widgets/request_documents_sheet.dart';
import '../widgets/request_status_labels.dart';
import '../widgets/request_status_seen_mapping.dart';
import '../widgets/seen_deadline_card.dart';
import 'upload_missing_document_screen.dart';
import '../widgets/seen_request_ticket.dart';

const _gutter = 20.0;

void _openSupport(BuildContext context) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportTicketsScreen()));

/// Request tracking (Figma 07): ticket, deadline counter, 5-stage stepper,
/// travelers, and sticky Support / View documents actions.
class RequestDetailScreen extends StatelessWidget {
  const RequestDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return BlocListener<RequestsBloc, RequestsState>(
      listenWhen: (previous, current) =>
          current is RequestsLoaded && current.cancelStatus == RequestCancelStatus.failure,
      listener: (context, state) {
        final message = (state as RequestsLoaded).cancelError ?? l10n.error;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      child: Scaffold(
        backgroundColor: c.card,
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const _Header(),
                Expanded(
                  child: BlocBuilder<RequestsBloc, RequestsState>(
                    builder: (context, state) {
                      if (state is! RequestsLoaded || state.detail == null) {
                        if (state is RequestsLoaded && state.detailStatus == RequestDetailStatus.failure) {
                          return _DetailErrorView(message: state.detailError ?? l10n.error);
                        }
                        return const _DetailSkeleton();
                      }
                      return _DetailBody(state: state, detail: state.detail!);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomNavigationBar: BlocBuilder<RequestsBloc, RequestsState>(
          buildWhen: (previous, current) => current is RequestsLoaded && current.detail != null,
          builder: (context, state) {
            if (state is! RequestsLoaded || state.detail == null) return const SizedBox.shrink();
            return _ActionsBar(detail: state.detail!);
          },
        ),
      ),
    );
  }
}

/// Back · title · support (Figma header).
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final type = SeenType.of(context);
    final c = SeenColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s3, _gutter, SeenSpace.s3),
      child: Row(
        children: [
          SeenRoundIconButton(
            icon: SeenIcons.back(context),
            semanticLabel: SeenStrings.of(context).back,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(child: Text(l10n.requestTrackingTitle, textAlign: TextAlign.center, style: type.title)),
          Semantics(
            button: true,
            label: l10n.requestDetailContactSupportAction,
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: const BoxDecoration(shape: BoxShape.circle, boxShadow: SeenShadows.card),
              child: Material(
                color: c.card,
                shape: CircleBorder(side: BorderSide(color: c.border)),
                child: InkWell(
                  onTap: () => _openSupport(context),
                  customBorder: const CircleBorder(),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: SeenSvgIcon(SeenVectors.accountSupport, size: 22, color: c.primary)),
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

/// Sticky bottom actions: Support (outline) and View documents (primary).
class _ActionsBar extends StatelessWidget {
  const _ActionsBar({required this.detail});

  final RequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.card, boxShadow: SeenShadows.stickyBar),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(_gutter, 14, _gutter, 14),
          child: Row(
            children: [
              Expanded(
                child: SeenButton(
                  label: l10n.requestViewDocumentsAction,
                  expand: true,
                  onPressed: () => showRequestDocumentsSheet(context, detail),
                ),
              ),
              const SizedBox(width: SeenSpace.s3),
              Expanded(
                child: SeenButton.outline(
                  label: l10n.requestSupportAction,
                  expand: true,
                  onPressed: () => _openSupport(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.state, required this.detail});

  final RequestsLoaded state;
  final RequestDetail detail;

  Future<void> _confirmCancel(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showSeenSheet<bool>(
      context: context,
      title: l10n.requestDetailCancelConfirmTitle,
      subtitle: l10n.requestDetailCancelConfirmMessage,
      builder: (_) => const SizedBox.shrink(),
      footerBuilder: (sheetContext) => Row(
        children: [
          Expanded(
            child: SeenButton.secondary(
              label: l10n.no,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ),
          const SizedBox(width: SeenSpace.s3),
          Expanded(
            child: SeenButton.destructive(
              label: l10n.yes,
              expand: true,
              onPressed: () => Navigator.of(sheetContext).pop(true),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<RequestsBloc>().add(RequestCancelSubmitted(detail.id));
    }
  }

  Future<void> _openUpload(BuildContext context) async {
    final bloc = context.read<RequestsBloc>();
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UploadMissingDocumentScreen(requestId: detail.id, referenceId: detail.referenceId),
      ),
    );
    // The request leaves "info required" once the document is accepted.
    if (sent == true) bloc.add(RequestDetailRequested(detail.id));
  }

  Future<void> _copyReference(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: detail.referenceId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(l10n.requestDetailReferenceCopiedMessage)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final isCancelling = state.cancelStatus == RequestCancelStatus.submitting;
    final status = detail.status.toSeenRequestStatus(slaDeadline: detail.slaDeadline);
    final leadTraveler = detail.travelers.isNotEmpty ? detail.travelers.first.name : null;
    final showDeadline = detail.status == RequestStatus.infoRequired && detail.slaDeadline != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(_gutter, SeenSpace.s1, _gutter, SeenSpace.s6),
      children: [
        SeenRequestTicket(
          status: status,
          statusLabel: s.requestStatus(status),
          reference: detail.referenceId,
          title: leadTraveler ?? detail.serviceName,
          subtitle: leadTraveler != null ? detail.serviceName : s.travelerCount(detail.travelers.length),
          feeLabel: l10n.requestTicketFees,
          feeValue: SeenFormat.usd(detail.totalPriceCents / 100),
          travelersLabel: l10n.requestTicketTravelers,
          travelersValue: s.numeral(detail.travelers.length),
          dateLabel: l10n.requestTicketDate,
          dateValue: SeenFormat.date(detail.submittedAt),
          onReferenceTap: () => _copyReference(context),
        ),
        if (showDeadline) ...[
          const SizedBox(height: 18),
          SeenDeadlineCard(
            deadline: detail.slaDeadline!,
            title: l10n.requestDeadlineTitle,
            subtitle: l10n.requestDeadlineSubtitle,
            expiredLabel: l10n.requestDeadlineExpired,
          ),
          const SizedBox(height: 12),
          SeenButton(
            label: l10n.uploadFromRequestAction,
            expand: true,
            onPressed: () => _openUpload(context),
          ),
        ],
        const SizedBox(height: 18),
        _StagesCard(detail: detail),
        if (detail.travelers.isNotEmpty) ...[
          SeenSectionHeader(
            title: l10n.requestDetailTravelersSection,
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          _TravelersCard(travelers: detail.travelers),
        ],
        if (detail.isCancellable) ...[
          const SizedBox(height: SeenSpace.s6),
          SeenButton.destructive(
            label: isCancelling ? l10n.loading : l10n.requestDetailCancelAction,
            icon: SeenIcons.x,
            expand: true,
            loading: isCancelling,
            onPressed: () => _confirmCancel(context),
          ),
        ],
      ],
    );
  }
}

DecoratedBox _card(SeenColors c, Widget child) => DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: child,
    );

/// "Request stages": the 5-step journey with timestamps where the timeline has
/// them. Statuses with no meaningful progress (rejected, cancelled) fall back
/// to the raw timeline entries.
class _StagesCard extends StatelessWidget {
  const _StagesCard({required this.detail});

  final RequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final progress = detail.status.progress;

    String stamp(DateTime at) => SeenFormat.isolate('${SeenFormat.date(at)} · ${SeenFormat.time(at)}');

    final List<SeenStep> steps;
    final int current;
    if (progress.isVisible) {
      steps = [
        for (var i = 1; i <= progress.total; i++)
          SeenStep(
            title: s.requestStepTitle(i),
            meta: () {
              // The latest timeline entry that belongs to this stage.
              final entries = detail.timeline.where((e) => e.status.progress.step == i);
              if (entries.isEmpty) return null;
              final entry = entries.last;
              return (i == progress.step ? entry.note : null) ?? stamp(entry.occurredAt);
            }(),
          ),
      ];
      current = detail.status == RequestStatus.completed ? progress.total : progress.step - 1;
    } else {
      steps = [
        for (final e in detail.timeline)
          SeenStep(title: RequestStatusLabels.of(l10n, e.status), meta: e.note ?? stamp(e.occurredAt)),
      ];
      current = steps.length - 1;
    }

    return _card(
      c,
      Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.requestTrackingSteps, style: type.title),
            const SizedBox(height: SeenSpace.s3),
            SeenStatusStepper(steps: steps, current: current),
          ],
        ),
      ),
    );
  }
}

class _TravelersCard extends StatelessWidget {
  const _TravelersCard({required this.travelers});

  final List<RequestTravelerStatus> travelers;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return _card(
      c,
      Column(
        children: [
          for (var i = 0; i < travelers.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: c.border),
            _TravelerRow(traveler: travelers[i], number: i + 1),
          ],
        ],
      ),
    );
  }
}

class _TravelerRow extends StatelessWidget {
  const _TravelerRow({required this.traveler, required this.number});

  final RequestTravelerStatus traveler;

  /// This traveler's 1-based position in the request (a running passenger
  /// number, not initials).
  final int number;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final approved = traveler.status == TravelerApprovalStatus.approved;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: 14),
      child: Row(children: [
        DecoratedBox(
          decoration: BoxDecoration(color: c.primarySoft, shape: BoxShape.circle),
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: Text(SeenStrings.of(context).numeral(number), style: type.label.copyWith(color: c.primary)),
            ),
          ),
        ),
        const SizedBox(width: SeenSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(traveler.name, style: type.bodyStrong),
              if (traveler.passportNumber != null)
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    traveler.passportNumber!,
                    style: type.caption.copyWith(color: c.inkMuted, fontFeatures: SeenFonts.tabular),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: SeenSpace.s2),
        SeenStatusBadge(status: traveler.status.toSeenStatus, dense: true),
        // Per-traveler download — still mocked (no real document storage
        // yet), so tapping only plays the acknowledgment animation.
        if (approved) ...[
          const SizedBox(width: SeenSpace.s1),
          SeenMotionIcon(
            asset: SeenMotionIcons.download,
            fallbackIcon: SeenIcons.download,
            size: 20,
            color: c.inkMuted,
            semanticLabel: l10n.requestDetailDownloadAction,
            onTap: () {},
          ),
        ],
      ]),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);

    Widget block(double height, double width) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: c.surfaceSunken, borderRadius: BorderRadius.circular(4)),
        );

    Widget panel(Widget child) => Container(
          padding: const EdgeInsets.all(SeenSpace.s4),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: const BorderRadius.all(SeenRadius.r22),
            border: Border.all(color: c.border),
          ),
          child: child,
        );

    return Padding(
      padding: const EdgeInsets.all(_gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          panel(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [block(14, 90), block(28, 90)]),
              const SizedBox(height: SeenSpace.s3),
              block(20, 200),
              const SizedBox(height: SeenSpace.s2),
              block(14, 140),
            ],
          )),
          const SizedBox(height: 18),
          panel(Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: SeenSpace.s4),
                Row(
                  children: [
                    Container(width: 26, height: 26, decoration: BoxDecoration(color: c.surfaceSunken, shape: BoxShape.circle)),
                    const SizedBox(width: SeenSpace.s3),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [block(16, 160), const SizedBox(height: 4), block(12, 100)],
                    ),
                  ],
                ),
              ],
            ],
          )),
        ],
      ),
    );
  }
}

class _DetailErrorView extends StatelessWidget {
  const _DetailErrorView({required this.message});

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
            onPressed: () {
              final state = context.read<RequestsBloc>().state;
              if (state is RequestsLoaded && state.requests.isNotEmpty) {
                context.read<RequestsBloc>().add(RequestDetailRequested(state.requests.first.id));
              }
            },
          ),
        ],
      ),
    );
  }
}
