// Group manifest · build (Figma REQ-14): import a spreadsheet or add travelers one by one,
// see which lines are ready and which are not, save as a draft or review and send. Works for
// lists larger than the 9 travelers of a normal request.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/avatar.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/dashed_border.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/manifest.dart';
import '../bloc/manifest_build_cubit.dart';
import '../widgets/manifest_row_shell.dart';
import '../widgets/manifest_strings.dart';
import 'manifest_summary_screen.dart';

class ManifestBuildScreen extends StatelessWidget {
  const ManifestBuildScreen(
      {super.key,
      required this.serviceId,
      required this.serviceLabel,
      this.createCubit});

  final String serviceId;
  final String serviceLabel;

  /// Test seam: the cubit (defaults to DI).
  final ManifestBuildCubit Function()? createCubit;

  static Route<void> route(
          {required String serviceId, required String serviceLabel}) =>
      MaterialPageRoute<void>(
          builder: (_) => ManifestBuildScreen(
              serviceId: serviceId, serviceLabel: serviceLabel));

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createCubit ??
          () => InjectionContainer.instance
              .createManifestBuildCubit(serviceId, serviceLabel))()
        ..load(),
      child: const _View(),
    );
  }
}

class _View extends StatelessWidget {
  const _View();

  Future<void> _add(BuildContext context) async {
    final cubit = context.read<ManifestBuildCubit>();
    final s = SeenStrings.of(context);
    final result = await showSeenSheet<({String name, String? passport})>(
      context: context,
      title: s.addTravelerAction,
      builder: (_) => const _AddTravelerForm(),
    );
    if (result != null) {
      await cubit.addTraveler(
          name: result.name, passportNumber: result.passport);
    }
  }

  Future<void> _review(BuildContext context, ManifestDraft draft) async {
    final cubit = context.read<ManifestBuildCubit>();
    final s = SeenStrings.of(context);
    final send = await showSeenSheet<bool>(
      context: context,
      title: s.sendManifestTitle,
      builder: (_) => Text(
        draft.readyCount == 0
            ? s.nothingToSend
            : s.sendManifestBody(draft.readyCount, draft.incompleteCount),
        style: SeenType.of(context).body,
      ),
      footerBuilder: (sheet) => SeenButton(
        label: s.sendManifestAction,
        expand: true,
        onPressed:
            draft.readyCount == 0 ? null : () => Navigator.of(sheet).pop(true),
      ),
    );
    if (send == true) {
      await cubit.submit();
    }
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
              BlocListener<ManifestBuildCubit, ManifestBuildState>(
                listenWhen: (p, n) =>
                    p.noticeSeq != n.noticeSeq && n.notice != null,
                listener: (context, state) => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                      SnackBar(content: Text(s.manifestNotice(state.notice!)))),
              ),
              BlocListener<ManifestBuildCubit, ManifestBuildState>(
                listenWhen: (p, n) =>
                    p.submittedId == null && n.submittedId != null,
                listener: (context, state) => Navigator.of(context)
                    .pushReplacement(
                        ManifestSummaryScreen.route(state.submittedId!)),
              ),
            ],
            child: BlocBuilder<ManifestBuildCubit, ManifestBuildState>(
              builder: (context, state) {
                final cubit = context.read<ManifestBuildCubit>();
                final draft = state.draft;
                return Column(
                  children: [
                    SeenScreenHeader(
                        title: s.manifestTitle,
                        subtitle: draft?.serviceLabel ?? cubit.serviceLabel),
                    Expanded(
                      child: switch (state.load) {
                        ManifestLoad.loading => const _Loading(),
                        ManifestLoad.failure => _Failure(onRetry: cubit.load, unsupported: state.unsupported),
                        ManifestLoad.loaded =>
                          _List(state: state, onAdd: () => _add(context)),
                      },
                    ),
                    if (state.load == ManifestLoad.loaded && draft != null)
                      SeenActionBar(
                        actions: [
                          SeenButton(
                            label: s.reviewManifest,
                            expand: true,
                            loading: state.busy,
                            onPressed: state.busy
                                ? null
                                : () => _review(context, draft),
                          ),
                          SeenButton.outline(
                            label: s.saveAsDraft,
                            expand: true,
                            onPressed: state.busy ? null : cubit.saveDraft,
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
              SeenSkeletonBox(height: 26, radius: 13),
              SizedBox(height: 14),
              SeenSkeletonBox(height: 280, radius: 22),
            ],
          ),
        ),
      );
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry, this.unsupported = false});

  final VoidCallback onRetry;

  /// The API has no group manifest: say so and offer no retry.
  final bool unsupported;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    if (unsupported) {
      return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(s.featureUnavailable, textAlign: TextAlign.center)));
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(s.manifestLoadFailed),
          const SizedBox(height: SeenSpace.s3),
          SeenButton(label: s.retryAction, onPressed: onRetry),
        ],
      ),
    );
  }
}

class _List extends StatelessWidget {
  const _List({required this.state, required this.onAdd});

  final ManifestBuildState state;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final cubit = context.read<ManifestBuildCubit>();
    final draft = state.draft!;
    final visible = state.visibleCount;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ImportCard(busy: state.busy, onImport: cubit.import),
                const SizedBox(height: 14),
                // Reading order: total, complete, incomplete.
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SeenStatusChip(
                        status: SeenRequestStatus.newRequest,
                        label: s.travelersCount(draft.travelers.length)),
                    SeenStatusChip(
                        status: SeenRequestStatus.completed,
                        label: s.completeChip(draft.readyCount)),
                    if (draft.incompleteCount > 0)
                      SeenStatusChip(
                          status: SeenRequestStatus.actionRequired,
                          label: s.incompleteChip(draft.incompleteCount)),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: visible,
            itemBuilder: (context, i) => ManifestRowShell(
              first: i == 0,
              last: i == visible - 1,
              child: _TravelerRow(index: i, traveler: draft.travelers[i]),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (state.hiddenCount > 0 ||
                    state.showAll &&
                        draft.travelers.length > manifestPreviewRows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Center(
                      child: InkWell(
                        onTap: cubit.toggleShowAll,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 8),
                          child: Text(
                            state.showAll
                                ? s.showFewer
                                : s.moreTravelers(state.hiddenCount),
                            style: t.caption.copyWith(color: c.inkMuted),
                          ),
                        ),
                      ),
                    ),
                  ),
                SeenDashedBorder(
                  color: c.borderStrong,
                  radius: 16,
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(16)),
                    onTap: state.busy ? null : onAdd,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                          child: Text(s.addTravelerAction,
                              style: t.label.copyWith(color: c.primary))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ImportCard extends StatelessWidget {
  const _ImportCard({required this.busy, required this.onImport});

  final bool busy;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return SeenDashedBorder(
      color: SeenBrand.violet40,
      radius: 16,
      strokeWidth: 1,
      child: DecoratedBox(
        decoration: const BoxDecoration(
            color: SeenBrand.violet05,
            borderRadius: BorderRadius.all(Radius.circular(16))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.importListTitle, style: t.label),
                    Text(s.importListCaption,
                        style: t.caption.copyWith(color: c.inkMuted)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SeenButton.secondary(
                label: s.importAction,
                size: SeenButtonSize.small,
                loading: busy,
                onPressed: busy ? null : onImport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TravelerRow extends StatelessWidget {
  const _TravelerRow({required this.index, required this.traveler});

  final int index;
  final ManifestTraveler traveler;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final (status, label) = switch (traveler.problem) {
      ManifestProblem.none => (SeenRequestStatus.completed, s.travelerReady),
      ManifestProblem.missingPassport => (
          SeenRequestStatus.actionRequired,
          s.missingPassport
        ),
      ManifestProblem.passportExpiring => (
          SeenRequestStatus.rejected,
          s.passportExpiresIn(traveler.monthsLeft)
        ),
    };
    return Row(
      children: [
        SeenAvatar(initial: '${index + 1}', size: 32),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(traveler.name,
                  style: t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                traveler.passportNumber ?? '—',
                textDirection: TextDirection.ltr,
                style: t.caption.copyWith(color: c.inkMuted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // A long reason shrinks the chip rather than overflowing a narrow row.
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerEnd,
            child: SeenStatusChip(status: status, label: label),
          ),
        ),
      ],
    );
  }
}

class _AddTravelerForm extends StatefulWidget {
  const _AddTravelerForm();

  @override
  State<_AddTravelerForm> createState() => _AddTravelerFormState();
}

class _AddTravelerFormState extends State<_AddTravelerForm> {
  // Owned here, disposed in dispose().
  final _name = TextEditingController();
  final _passport = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _passport.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = SeenStrings.of(context).travelerNameRequired);
      return;
    }
    final passport = _passport.text.trim();
    Navigator.of(context)
        .pop((name: name, passport: passport.isEmpty ? null : passport));
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeenTextField(
          label: s.travelerNameLabel,
          controller: _name,
          errorText: _error,
          textInputAction: TextInputAction.next,
          onChanged: (_) =>
              _error == null ? null : setState(() => _error = null),
        ),
        const SizedBox(height: SeenSpace.s3),
        SeenTextField(
          label: s.passportNumberOptional,
          controller: _passport,
          mono: true,
          ltr: true,
          textCapitalization: TextCapitalization.characters,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: SeenSpace.s4),
        SeenButton(
            label: s.addTravelerAction, expand: true, onPressed: _submit),
      ],
    );
  }
}
