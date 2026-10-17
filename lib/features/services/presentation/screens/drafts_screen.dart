import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/empty_state.dart';
import '../../../../core/presentation/widgets/error_patterns.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/booking_draft.dart';
import '../bloc/drafts_bloc.dart';
import '../utils/draft_summary.dart';
import '../widgets/seen_draft_card.dart';
import '../widgets/service_card_copy.dart';
import 'service_selection_screen.dart';

/// Drafts list (Figma REQ-01): the agent's saved, unfinished bookings with
/// Continue / Delete, a note about the 30-day clean-up, and an undo toast after
/// deleting. Owns a [DraftsBloc].
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

  Future<void> _delete(BuildContext context, BookingDraft draft, bool isLast) async {
    final bloc = context.read<DraftsBloc>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _DeleteDialog(draft: draft, isLast: isLast),
    );
    // The toast comes from the listener, once the delete went through.
    if (confirmed == true) bloc.add(DraftDeleteRequested(draft));
  }

  Future<void> _continue(BuildContext context, BookingDraft draft) async {
    final bloc = context.read<DraftsBloc>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => ServiceSelectionScreen(resumeDraft: draft)),
    );
    // The draft may have been sent (deleted) or saved again meanwhile.
    bloc.add(const DraftsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    return BlocConsumer<DraftsBloc, DraftsState>(
      listenWhen: (previous, current) => previous.deleteSeq != current.deleteSeq,
      listener: (context, state) {
        final bloc = context.read<DraftsBloc>();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(l10n.draftDeletedToast),
            action: SnackBarAction(label: l10n.draftUndo, onPressed: () => bloc.add(const DraftDeleteUndone())),
          ));
      },
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
                      DraftsStatus.loading => const Center(child: SeenLoader()),
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
                      DraftsStatus.ready => ListView(
                          padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: SeenRequestStatus.underReview.colors.bg,
                                borderRadius: const BorderRadius.all(SeenRadius.lg),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    const SeenSvgIcon(SeenVectors.infoReview, size: 20),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        l10n.draftsInfo,
                                        style: t.label.copyWith(color: SeenRequestStatus.underReview.colors.fg),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            for (final d in state.drafts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _card(context, d, now, l10n, s, isLast: state.drafts.length == 1),
                              ),
                          ],
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

  Widget _card(BuildContext context, BookingDraft d, DateTime now, AppLocalizations l10n, SeenStrings s,
      {required bool isLast}) {
    final daysLeft = d.daysLeft(now);
    return SeenDraftCard(
      title: d.serviceName,
      subtitle: s.travelerCount(d.travelers.length),
      chipLabel: l10n.draftChip,
      iconAsset: ServiceCardCopy.forCategory(d.category, l10n).iconAsset,
      continueLabel: l10n.draftContinue,
      deleteLabel: l10n.draftDelete,
      ageLabel: s.draftAge(d.updatedAt, now: now),
      missingLine: draftMissingLine(d, l10n, s),
      expiryLabel: daysLeft <= 3 ? s.draftDeletesIn(daysLeft) : null,
      onContinue: () => _continue(context, d),
      onDelete: () => _delete(context, d, isLast),
    );
  }
}

/// Delete confirmation (Figma REQ-03).
class _DeleteDialog extends StatelessWidget {
  const _DeleteDialog({required this.draft, required this.isLast});

  final BookingDraft draft;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final bad = SeenRequestStatus.rejected.colors;
    final body = l10n.draftDeleteBody(draft.serviceName, s.travelerCount(draft.travelers.length));
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 30),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: const BorderRadius.all(SeenRadius.r28),
          boxShadow: const [
            BoxShadow(color: Color(0x142C186A), blurRadius: 16, offset: Offset(0, 8)),
            BoxShadow(color: Color(0x385B36DA), blurRadius: 48, offset: Offset(0, 24)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(color: bad.bg, borderRadius: const BorderRadius.all(Radius.circular(17))),
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: Center(child: SeenSvgIcon(SeenVectors.notifAlert, size: 31)),
                ),
              ),
              const SizedBox(height: 12),
              Text(l10n.draftDeleteTitle, textAlign: TextAlign.center, style: t.h2),
              const SizedBox(height: 12),
              Text(
                isLast ? '$body ${l10n.draftDeleteLast}' : body,
                textAlign: TextAlign.center,
                style: t.body.copyWith(color: c.inkSecondary),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SeenButton.outline(
                      label: l10n.transferCancel,
                      expand: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: SeenSpace.s3),
                  Expanded(
                    child: Semantics(
                      button: true,
                      label: l10n.draftDelete,
                      excludeSemantics: true,
                      child: Material(
                        color: bad.bg,
                        borderRadius: const BorderRadius.all(SeenRadius.lg),
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(true),
                          borderRadius: const BorderRadius.all(SeenRadius.lg),
                          child: SizedBox(
                            height: 52,
                            child: Center(child: Text(l10n.draftDelete, style: t.bodyStrong.copyWith(color: bad.fg))),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
