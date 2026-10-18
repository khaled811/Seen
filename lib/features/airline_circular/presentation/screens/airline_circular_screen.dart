// Airline circular (Figma REQ-15 and REQ-15b): pick an issued security approval, then the
// circular is filled in from it (travelers locked); only the flight ticket and the flight
// are entered by the agent.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/dropzone.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../requests/domain/entities/missing_document.dart';
import '../../../services/presentation/widgets/seen_attachment_slot.dart'
    show showAttachmentSourceSheet;
import '../../../services/presentation/widgets/seen_date_sheet.dart';
import '../../../system_status/presentation/widgets/permission_denied_sheet.dart';
import '../../domain/entities/airline_circular.dart';
import '../bloc/airline_circular_cubit.dart';
import '../bloc/approval_picker_cubit.dart';
import '../widgets/approval_picker_sheet.dart';
import '../widgets/circular_strings.dart';

class AirlineCircularScreen extends StatelessWidget {
  const AirlineCircularScreen(
      {super.key, this.createCubit, this.createPickerCubit, this.now});

  /// Test seams: the cubits (default to DI) and the clock.
  final AirlineCircularCubit Function()? createCubit;
  final ApprovalPickerCubit Function()? createPickerCubit;
  final DateTime Function()? now;

  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (_) => const AirlineCircularScreen());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createCubit ??
          InjectionContainer.instance.createAirlineCircularCubit)(),
      child: _View(createPickerCubit: createPickerCubit, now: now),
    );
  }
}

class _View extends StatefulWidget {
  const _View({this.createPickerCubit, this.now});

  final ApprovalPickerCubit Function()? createPickerCubit;
  final DateTime Function()? now;

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  // Owned here, disposed in dispose().
  final _flightNumber = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Nothing is linked yet: the picker opens over the screen, as in the design.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _choose(first: true);
    });
  }

  @override
  void dispose() {
    _flightNumber.dispose();
    super.dispose();
  }

  Future<void> _choose({bool first = false}) async {
    final cubit = context.read<AirlineCircularCubit>();
    final picked = await showApprovalPickerSheet(context,
        createCubit: widget.createPickerCubit);
    if (!mounted) return;
    if (picked != null) {
      await cubit.link(picked.id);
    } else if (first) {
      Navigator.of(context).maybePop(); // Nothing chosen: nothing to fill in.
    }
  }

  Future<void> _ticket() async {
    final cubit = context.read<AirlineCircularCubit>();
    final source = await showAttachmentSourceSheet(context);
    if (source != null) await cubit.pickTicket(source);
  }

  Future<void> _date(AirlineCircularState state) async {
    final cubit = context.read<AirlineCircularCubit>();
    final s = SeenStrings.of(context);
    final n = (widget.now ?? DateTime.now)();
    final today = DateTime(n.year, n.month, n.day);
    final d = await showSeenDateSheet(
      context: context,
      title: s.flightDateLabel,
      firstDate: today,
      lastDate: DateTime(today.year + 1, today.month, today.day),
      initial: state.flightDate,
      rule: s.flightDateRule,
    );
    if (d != null) cubit.setFlightDate(d);
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: MultiBlocListener(
            listeners: [
              BlocListener<AirlineCircularCubit, AirlineCircularState>(
                listenWhen: (p, n) =>
                    p.noticeSeq != n.noticeSeq && n.notice != null,
                listener: (context, state) => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(SnackBar(content: Text(s.circularFailed))),
              ),
              BlocListener<AirlineCircularCubit, AirlineCircularState>(
                listenWhen: (p, n) => !p.submitted && n.submitted,
                listener: (context, state) {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.of(context).pop();
                  messenger
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(s.circularSent)));
                },
              ),
              // A permission refused for good opens the explanation (Figma SYS-07).
              BlocListener<AirlineCircularCubit, AirlineCircularState>(
                listenWhen: (p, n) =>
                    p.ticketError != n.ticketError &&
                    (n.ticketError == TicketError.cameraDenied ||
                        n.ticketError == TicketError.photosDenied),
                listener: (context, state) async {
                  final cubit = context.read<AirlineCircularCubit>();
                  final choice = await showPermissionDeniedSheet(
                    context,
                    permission: state.ticketError == TicketError.cameraDenied
                        ? DeniedPermission.camera
                        : DeniedPermission.photos,
                  );
                  if (choice == PermissionSheetChoice.chooseFile) {
                    await cubit.pickTicket(DocumentSource.file);
                  }
                },
              ),
            ],
            child: BlocBuilder<AirlineCircularCubit, AirlineCircularState>(
              builder: (context, state) {
                final cubit = context.read<AirlineCircularCubit>();
                final prefill = state.prefill;
                return Column(
                  children: [
                    SeenScreenHeader(
                      title: s.circularTitle,
                      subtitle: prefill == null
                          ? null
                          : s.linkedTo(prefill.approval.reference),
                    ),
                    Expanded(
                      child: switch (state.stage) {
                        CircularStage.choosing => const SizedBox.shrink(),
                        CircularStage.loading => const _Loading(),
                        CircularStage.failure => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(s.circularPrefillFailed),
                                const SizedBox(height: SeenSpace.s3),
                                SeenButton(
                                    label: s.changeAction, onPressed: _choose),
                              ],
                            ),
                          ),
                        CircularStage.ready => _Form(
                            state: state,
                            cubit: cubit,
                            flightNumber: _flightNumber,
                            onChange: _choose,
                            onTicket: _ticket,
                            onDate: () => _date(state),
                          ),
                      },
                    ),
                    if (state.stage == CircularStage.ready)
                      SeenActionBar(
                        actions: [
                          SeenButton(
                            label: s.sendCircular,
                            expand: true,
                            loading: state.busy,
                            onPressed: state.busy ? null : cubit.submit,
                          ),
                        ],
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

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const SeenSkeletonGroup(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SeenSkeletonBox(height: 66, radius: 16),
              SizedBox(height: 14),
              SeenSkeletonBox(height: 54, radius: 16),
              SizedBox(height: 14),
              SeenSkeletonBox(height: 54, radius: 16),
            ],
          ),
        ),
      );
}

class _Form extends StatelessWidget {
  const _Form({
    required this.state,
    required this.cubit,
    required this.flightNumber,
    required this.onChange,
    required this.onTicket,
    required this.onDate,
  });

  final AirlineCircularState state;
  final AirlineCircularCubit cubit;
  final TextEditingController flightNumber;
  final VoidCallback onChange;
  final VoidCallback onTicket;
  final VoidCallback onDate;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final prefill = state.prefill!;
    final travelers = prefill.travelers;
    final ticket = state.ticket;
    final showErrors = state.showErrors;
    final dateText =
        state.flightDate == null ? null : s.dayMonth(state.flightDate!);
    final dateError = !showErrors
        ? null
        : (state.flightDate == null
            ? s.flightDateRequired
            : (cubit.dateOk(state.flightDate) ? null : s.flightDatePast));
    final numberError =
        showErrors && !state.flightNumberValid ? s.flightNumberInvalid : null;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child:
                _LinkedBanner(approval: prefill.approval, onChange: onChange),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          sliver: SliverList.separated(
            itemCount: travelers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, i) => _LockedTraveler(
              key: ValueKey('${prefill.approval.id}-$i'),
              traveler: travelers[i],
              index: i,
              count: travelers.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.lockedFieldsNote,
                    style: t.caption.copyWith(color: c.inkMuted)),
                const SizedBox(height: 14),
                if (ticket == null)
                  SeenDropzone(
                      title: s.ticketTitle,
                      caption: s.ticketCaption,
                      onTap: onTicket)
                else
                  _TicketTile(ticket: ticket, onReplace: onTicket),
                if (state.ticketError != null) ...[
                  const SizedBox(height: 6),
                  Text(s.ticketError(state.ticketError!),
                      style: t.caption.copyWith(
                          color: SeenRequestStatus.rejected.colors.fg)),
                ] else if (showErrors && ticket == null) ...[
                  const SizedBox(height: 6),
                  Text(s.ticketRequired,
                      style: t.caption.copyWith(
                          color: SeenRequestStatus.rejected.colors.fg)),
                ],
                const SizedBox(height: 14),
                SeenTextField(
                  label: s.flightNumberLabel,
                  controller: flightNumber,
                  hint: s.flightNumberHint,
                  mono: true,
                  ltr: true,
                  textCapitalization: TextCapitalization.characters,
                  success: state.flightNumberValid,
                  errorText: numberError,
                  onChanged: cubit.setFlightNumber,
                ),
                const SizedBox(height: 14),
                SeenTextField(
                  key: ValueKey(dateText),
                  label: s.flightDateLabel,
                  initialValue: dateText,
                  picker: true,
                  readOnly: true,
                  suffix: Icon(SeenIcons.calendar, size: 20, color: c.inkMuted),
                  errorText: dateError,
                  onTap: onDate,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LinkedBanner extends StatelessWidget {
  const _LinkedBanner({required this.approval, required this.onChange});

  final ApprovedSecurityRequest approval;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final ok = SeenRequestStatus.completed.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
          color: ok.bg,
          borderRadius: const BorderRadius.all(Radius.circular(16))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(SeenIcons.check, size: 20, color: ok.fg),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.linkedApproval(approval.reference),
                      style: t.label.copyWith(color: ok.fg)),
                  Text(s.travelersFilled,
                      style: t.caption.copyWith(color: ok.fg)),
                ],
              ),
            ),
            SeenTextLink(label: s.changeAction, onTap: onChange),
          ],
        ),
      ),
    );
  }
}

/// A traveler copied from the approval: name and passport, read-only.
class _LockedTraveler extends StatelessWidget {
  const _LockedTraveler(
      {super.key,
      required this.traveler,
      required this.index,
      required this.count});

  final CircularTraveler traveler;
  final int index;
  final int count;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final eye = Icon(SeenIcons.eye, size: 20, color: c.inkMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeenTextField(
          label: count > 1
              ? '${s.travelerField} ${s.numeral(index + 1)}'
              : s.travelerField,
          initialValue: traveler.name,
          readOnly: true,
          suffix: eye,
        ),
        const SizedBox(height: 14),
        SeenTextField(
          label: s.passportField,
          initialValue: traveler.passportNumber,
          readOnly: true,
          ltr: true,
          mono: true,
          suffix: eye,
        ),
      ],
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, required this.onReplace});

  final CircularTicket ticket;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r14),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(SeenIcons.file, color: c.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ticket.fileName,
                      style: t.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text('${(ticket.sizeBytes / 1024).ceil()} KB',
                      style: t.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
            SeenTextLink(label: s.attachReplace, onTap: onReplace),
          ],
        ),
      ),
    );
  }
}
