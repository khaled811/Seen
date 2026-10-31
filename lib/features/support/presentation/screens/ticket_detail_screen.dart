// Ticket thread (Figma SUP-03): the agent's messages on the start side, support's
// on the other, a day separator, messages still being sent or failed (with a
// resend), and a closed ticket that is read-only.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/presentation/widgets/loading/seen_wait_policy.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../domain/entities/support_ticket.dart';
import '../../domain/entities/ticket_message.dart';
import '../../../requests/presentation/bloc/staged_attachment_cubit.dart';
import '../../../services/presentation/widgets/seen_attachment_slot.dart'
    show showAttachmentSourceSheet;
import '../../../wallet/presentation/widgets/seen_receipt_slot.dart';
import '../bloc/support_bloc.dart';
import '../bloc/support_event.dart';
import '../bloc/support_state.dart';
import '../bloc/ticket_actions_cubit.dart';
import '../bloc/ticket_rating_cubit.dart';
import '../widgets/ticket_rating_card.dart';

/// Chat-style ticket thread, reactive to the same [SupportBloc] the list
/// screen owns — a reply posted here shows up immediately, and re-opening
/// the ticket from the list reflects any change without a separate fetch.
class TicketDetailScreen extends StatelessWidget {
  const TicketDetailScreen(
      {super.key,
      required this.ticketId,
      this.createActionsCubit,
      this.createAttachment,
      this.createRating});

  /// Test seam for the rating cubit; defaults to the DI container.
  final TicketRatingCubit Function()? createRating;

  /// Test seam for the reply attachment cubit; defaults to the DI container.
  final StagedAttachmentCubit Function()? createAttachment;

  final String ticketId;

  /// Test seam for the mark-read cubit; defaults to the DI container.
  final TicketActionsCubit Function()? createActionsCubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createActionsCubit ??
          InjectionContainer.instance.createTicketActionsCubit)(),
      child: _ThreadView(
          ticketId: ticketId,
          createAttachment: createAttachment,
          createRating: createRating),
    );
  }
}

class _ThreadView extends StatefulWidget {
  const _ThreadView(
      {required this.ticketId, this.createAttachment, this.createRating});

  final String ticketId;
  final StagedAttachmentCubit Function()? createAttachment;
  final TicketRatingCubit Function()? createRating;

  @override
  State<_ThreadView> createState() => _ThreadViewState();
}

class _ThreadViewState extends State<_ThreadView> {
  // Owned here, disposed in dispose().
  final _messageController = TextEditingController();

  /// The file for the next reply: created here, closed in dispose(); it is sent when picked.
  late final StagedAttachmentCubit _attachment = (widget.createAttachment ??
      InjectionContainer.instance.createStagedAttachmentCubit)();

  /// The rating of this ticket (a resolved or closed one): created here, closed in dispose().
  TicketRatingCubit? _ratingCubit;

  /// Created the first time it is needed (a rateable ticket), never otherwise.
  TicketRatingCubit get _rating => _ratingCubit ??= (widget.createRating ??
      () => InjectionContainer.instance
          .createTicketRatingCubit(widget.ticketId))();

  /// How many messages were unread when the thread was opened: the "new messages" divider stays
  /// where it was until the screen is left, even though opening marks them read.
  int _unreadAtOpen = 0;

  @override
  void initState() {
    super.initState();
    // Opening the thread reads it: clear the marker here and on the server.
    final bloc = context.read<SupportBloc>()
      ..add(SupportTicketOpened(widget.ticketId));
    final state = bloc.state;
    _unreadAtOpen = state is SupportLoaded
        ? (state.ticketById(widget.ticketId)?.unreadCount ?? 0)
        : 0;
    if (state is SupportLoaded &&
        (state.ticketById(widget.ticketId)?.hasUnreadReply ?? false)) {
      bloc.add(SupportTicketMarkedRead(widget.ticketId));
      context.read<TicketActionsCubit>().markRead(widget.ticketId);
    }
  }

  @override
  void dispose() {
    _ratingCubit?.close();
    _attachment.close();
    _messageController.dispose();
    super.dispose();
  }

  void _send(BuildContext context) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    if (_attachment.state.uploading) return; // the file is still on its way
    context.read<SupportBloc>().add(SupportTicketReplySubmitted(
        ticketId: widget.ticketId,
        message: text,
        attachmentFileId: _attachment.state.fileId));
    _messageController.clear();
    _attachment.remove();
  }

  Future<void> _attach() async {
    final source = await showAttachmentSourceSheet(context);
    if (source != null) await _attachment.pick(source);
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return MultiBlocListener(
      listeners: [
        BlocListener<SupportBloc, SupportState>(
          listenWhen: (previous, current) =>
              current is SupportLoaded &&
              current.replyStatus == ReplyStatus.failure,
          listener: (context, state) {
            final loaded = state as SupportLoaded;
            _toast(failureTextOr(
                l10n, loaded.replyFailure, loaded.replyError ?? l10n.error));
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: c.card,
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: BlocBuilder<SupportBloc, SupportState>(
              builder: (context, state) {
                final ticket = state is SupportLoaded
                    ? state.ticketById(widget.ticketId)
                    : null;
                if (ticket == null) {
                  return Column(
                    children: [
                      SeenScreenHeader(title: l10n.ticketDetailTitle),
                      Expanded(
                        child: SeenWaitPolicy.loading(
                          loading: const _ThreadSkeleton(),
                          onRetry: () => context
                              .read<SupportBloc>()
                              .add(const SupportTicketsLoadRequested()),
                        ),
                      ),
                    ],
                  );
                }
                final outbox =
                    (state as SupportLoaded).outboxFor(widget.ticketId);
                return Column(
                  children: [
                    SeenScreenHeader(
                        title: ticket.referenceId, subtitle: ticket.subject),
                    Expanded(
                      child: ticket.messagesLoaded
                          ? _Thread(
                              ticket: ticket,
                              outbox: outbox,
                              unreadAtOpen: _unreadAtOpen,
                              rating: () => _rating)
                          : _ThreadLoading(
                              failure: state.openingTicketId == null
                                  ? state.openFailure
                                  : null,
                              onRetry: () => context
                                  .read<SupportBloc>()
                                  .add(SupportTicketOpened(ticket.id)),
                            ),
                    ),
                    if (ticket.isFinal)
                      const _ClosedBar()
                    else
                      BlocProvider<StagedAttachmentCubit>.value(
                        value: _attachment,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Shows only once a file was picked: its state, replace and remove.
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: SeenReceiptSlot(
                                title: '',
                                caption: '',
                                attachedText:
                                    SeenStrings.of(context).attachmentAttached,
                                uploadingText:
                                    SeenStrings.of(context).attachmentUploading,
                                emptyBuilder: (_) => const SizedBox.shrink(),
                              ),
                            ),
                            _Composer(
                              controller: _messageController,
                              onSend: () => _send(context),
                              onAttach: _attach,
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The thread of a ticket that was read from the list: loading from the server,
/// or the reason it could not be.
/// A conversation while it loads: alternating message bubbles under one sweep.
class _ThreadSkeleton extends StatelessWidget {
  const _ThreadSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bubble(double width, double height, AlignmentGeometry align) =>
        Align(
            alignment: align,
            child: SeenSkeletonBox(width: width, height: height, radius: 18));
    return SeenSkeletonGroup(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          children: [
            bubble(240, 64, AlignmentDirectional.centerStart),
            const SizedBox(height: 12),
            bubble(190, 48, AlignmentDirectional.centerEnd),
            const SizedBox(height: 12),
            bubble(260, 80, AlignmentDirectional.centerStart),
          ],
        ),
      ),
    );
  }
}

class _ThreadLoading extends StatelessWidget {
  const _ThreadLoading({required this.failure, required this.onRetry});

  final Failure? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (failure == null) {
      return SeenWaitPolicy.loading(
          loading: const _ThreadSkeleton(), onRetry: onRetry);
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(localizedFailureMessage(l10n, failure!),
              textAlign: TextAlign.center),
          const SizedBox(height: SeenSpace.s3),
          SeenButton(label: l10n.retry, onPressed: onRetry),
        ],
      ),
    );
  }
}

class _Thread extends StatelessWidget {
  const _Thread(
      {required this.ticket,
      required this.outbox,
      required this.unreadAtOpen,
      required this.rating});

  final SupportTicket ticket;
  final List<OutboxMessage> outbox;
  final int unreadAtOpen;
  final TicketRatingCubit Function() rating;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final now = DateTime.now();

    String dayLabel(DateTime d) {
      final today = DateTime(now.year, now.month, now.day);
      final day = DateTime(d.year, d.month, d.day);
      final diff = today.difference(day).inDays;
      if (diff == 0) return l10n.ticketToday;
      if (diff == 1) return l10n.ticketYesterday;
      return s.dayMonth(d);
    }

    // Oldest first, then reversed for the bottom-anchored list.
    final entries = <({DateTime at, Widget bubble})>[
      for (final m in ticket.messages)
        (at: m.sentAt, bubble: _Bubble.sent(message: m)),
      for (final m in outbox)
        (at: m.sentAt, bubble: _Bubble.pending(message: m)),
    ];
    final children = <Widget>[];
    DateTime? lastDay;
    // The first unread message: the divider goes right before it.
    final firstUnread =
        unreadAtOpen > 0 && unreadAtOpen <= ticket.messages.length
            ? ticket.messages.length - unreadAtOpen
            : -1;
    var index = 0;
    for (final entry in entries) {
      final day = DateTime(entry.at.year, entry.at.month, entry.at.day);
      if (lastDay != day) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Center(
                child: Text(dayLabel(entry.at),
                    style: t.caption.copyWith(color: c.inkMuted))),
          ),
        );
        lastDay = day;
      }
      if (index == firstUnread) {
        children.add(_NewMessagesDivider(count: unreadAtOpen));
      }
      children.add(entry.bubble);
      index++;
    }
    // A resolved or closed ticket ends with the closing line (closed only) and the rating card.
    final rateable = ticket.status == SupportTicketStatus.closed ||
        ticket.status == SupportTicketStatus.resolved;
    if (rateable && ticket.messagesLoaded) {
      if (ticket.status == SupportTicketStatus.closed) {
        children.add(_ClosedLine(when: ticket.lastActivityAt));
      }
      children.add(Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: BlocProvider<TicketRatingCubit>.value(
            value: rating(), child: const TicketRatingCard()),
      ));
    }
    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(20, SeenSpace.s1, 20, SeenSpace.s3),
      children: children.reversed.toList(),
    );
  }
}

/// One message: the agent's (white, start side), support's (violet, end side), or
/// the agent's still being sent / failed.
class _Bubble extends StatelessWidget {
  const _Bubble.sent({required TicketMessage message})
      : sent = message,
        pending = null;

  const _Bubble.pending({required OutboxMessage message})
      : sent = null,
        pending = message;

  final TicketMessage? sent;
  final OutboxMessage? pending;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final fromSupport = sent?.isSupportReply ?? false;
    final text = sent?.body ?? pending!.body;
    final at = sent?.sentAt ?? pending!.sentAt;
    final failed = pending?.status == OutboxStatus.failed;
    final time = SeenFormat.time(at);
    final meta = switch ((sent, pending)) {
      (final m?, _) when fromSupport => '$time · ${m.authorName}',
      (_, final p?) => p.status == OutboxStatus.failed
          ? '$time · ${l10n.ticketSendFailed}'
          : '$time · ${l10n.ticketSending}',
      _ => time,
    };
    final metaColor = failed ? SeenColors.of(context).dangerFg : c.inkMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: fromSupport
                ? AlignmentDirectional.centerEnd
                : AlignmentDirectional.centerStart,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: fromSupport ? SeenBrand.violet10 : c.card,
                  borderRadius: const BorderRadius.all(SeenRadius.r18),
                  border: fromSupport ? null : Border.all(color: c.border),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(text, style: t.body.copyWith(color: c.ink)),
                      const SizedBox(height: 4),
                      Text(meta,
                          textDirection: null,
                          style: t.caption.copyWith(color: metaColor)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (failed)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: SeenTextLink(
                label: l10n.ticketResend,
                onTap: () => context
                    .read<SupportBloc>()
                    .add(SupportOutboxRetryRequested(pending!.localId)),
              ),
            ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer(
      {required this.controller, required this.onSend, required this.onAttach});

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration:
          BoxDecoration(color: c.card, boxShadow: SeenShadows.stickyBar),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: SeenBrand.violet05,
                    borderRadius: BorderRadius.all(SeenRadius.full),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 14),
                      Semantics(
                        button: true,
                        label: l10n.ticketAttachOptional,
                        excludeSemantics: true,
                        child: InkResponse(
                          onTap: onAttach,
                          radius: 20,
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: SeenSvgIcon(SeenVectors.authUpload,
                                size: 18, color: c.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          style: t.body.copyWith(color: c.ink),
                          decoration: InputDecoration(
                            hintText: l10n.ticketReplyHint,
                            hintStyle: t.body.copyWith(color: c.inkMuted),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Semantics(
                button: true,
                label: l10n.ticketSendMessageTooltip,
                excludeSemantics: true,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                      gradient: SeenBrand.gradientCta, shape: BoxShape.circle),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: onSend,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                          width: 44,
                          height: 44,
                          child: Icon(SeenIcons.send,
                              size: 20, color: c.onPrimary)),
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

/// A closed or cancelled ticket is final and read-only: say so.
class _ClosedBar extends StatelessWidget {
  const _ClosedBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration:
          BoxDecoration(color: c.card, boxShadow: SeenShadows.stickyBar),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: DecoratedBox(
            decoration: const BoxDecoration(
                color: SeenBrand.violet05,
                borderRadius: BorderRadius.all(SeenRadius.r12)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(l10n.ticketClosedNote,
                  style: t.caption.copyWith(color: c.inkMuted)),
            ),
          ),
        ),
      ),
    );
  }
}

/// "New messages (n)": a pill with a hairline on each side, before the first message that was
/// unread when the thread was opened (design/gaps SUP-09).
class _NewMessagesDivider extends StatelessWidget {
  const _NewMessagesDivider({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tone = SeenRequestStatus.underReview.colors;
    final type = SeenType.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          const Expanded(
              flex: 1, child: Divider(color: SeenBrand.violet40, height: 1)),
          Flexible(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: tone.bg,
                      borderRadius: const BorderRadius.all(SeenRadius.full)),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(SeenStrings.of(context).digits(l10n.supNewMessagesDivider(count)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: type.chipS.copyWith(color: tone.fg)),
                  ),
                ),
              )),
          const Expanded(
              flex: 1, child: Divider(color: SeenBrand.violet40, height: 1)),
        ],
      ),
    );
  }
}

/// "Ticket closed . date time": the system line before the rating card.
class _ClosedLine extends StatelessWidget {
  const _ClosedLine({required this.when});

  final DateTime when;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final tone = SeenRequestStatus.newRequest.colors;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        children: [
          Expanded(flex: 1, child: Divider(color: c.border, height: 1)),
          Flexible(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: tone.bg,
                      borderRadius: const BorderRadius.all(SeenRadius.full)),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Text(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        l10n.supTicketClosedLine(
                            '${s.dayMonth(when)} ${SeenFormat.time(when)}'),
                        style: type.chipS.copyWith(color: tone.fg)),
                  ),
                ),
              )),
          Expanded(flex: 1, child: Divider(color: c.border, height: 1)),
        ],
      ),
    );
  }
}
