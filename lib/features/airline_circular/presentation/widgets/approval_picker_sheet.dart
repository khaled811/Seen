// Choose the issued security approval a circular is linked to (Figma REQ-15). The newest is
// pre-selected; the list can be searched by reference or by the lead traveler.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/search_field.dart';
import '../../../../core/presentation/widgets/selection.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/airline_circular.dart';
import '../bloc/approval_picker_cubit.dart';
import 'circular_strings.dart';

/// Opens the picker; resolves the chosen approval or null. [createCubit] is a test seam.
Future<ApprovedSecurityRequest?> showApprovalPickerSheet(
  BuildContext context, {
  ApprovalPickerCubit Function()? createCubit,
}) {
  return showModalBottomSheet<ApprovedSecurityRequest>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => BlocProvider(
      create: (_) => (createCubit ??
          InjectionContainer.instance.createApprovalPickerCubit)()
        ..load(),
      child: const _Body(),
    ),
  );
}

class _Body extends StatefulWidget {
  const _Body();

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  // Owned here, disposed in dispose().
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final c = SeenColors.of(context);
    return BlocBuilder<ApprovalPickerCubit, ApprovalPickerState>(
      builder: (context, state) {
        final cubit = context.read<ApprovalPickerCubit>();
        final visible = state.visible;
        return Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.pickApprovalTitle, style: t.h2),
                          Text(s.pickApprovalCaption,
                              style: t.caption.copyWith(color: c.inkMuted)),
                        ],
                      ),
                    ),
                    SeenIconButton(
                        icon: SeenIcons.x,
                        semanticLabel: s.close,
                        onPressed: () => Navigator.of(context).maybePop()),
                  ],
                ),
              ),
              if (state.status == ApprovalsStatus.loaded &&
                  state.items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SeenSearchField(
                      hint: s.approvalSearchHint,
                      controller: _search,
                      onChanged: cubit.search),
                ),
              Flexible(
                child: switch (state.status) {
                  ApprovalsStatus.loading => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Semantics(
                        label: s.loadingLabel,
                        child: const ExcludeSemantics(
                          child: SeenSkeletonGroup(
                            child: Column(children: [
                              SeenSkeletonBox(height: 86, radius: 16),
                              SizedBox(height: 12),
                              SeenSkeletonBox(height: 86, radius: 16),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ApprovalsStatus.failure => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(s.approvalsLoadFailed,
                              textAlign: TextAlign.center, style: t.body),
                          const SizedBox(height: 12),
                          SeenButton(
                              label: s.retryAction, onPressed: cubit.load),
                        ],
                      ),
                    ),
                  ApprovalsStatus.loaded when visible.isEmpty => Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Text(
                        state.items.isEmpty
                            ? s.noApprovals
                            : s.noApprovalMatches,
                        textAlign: TextAlign.center,
                        style: t.body.copyWith(color: c.inkMuted),
                      ),
                    ),
                  ApprovalsStatus.loaded => ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _ApprovalRow(
                        approval: visible[i],
                        selected: visible[i].id == state.selectedId,
                        onTap: () => cubit.select(visible[i].id),
                      ),
                    ),
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                child: SeenButton(
                  label: s.linkAndContinue,
                  expand: true,
                  onPressed: state.selected == null
                      ? null
                      : () => Navigator.of(context).pop(state.selected),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ApprovalRow extends StatelessWidget {
  const _ApprovalRow(
      {required this.approval, required this.selected, required this.onTap});

  final ApprovedSecurityRequest approval;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    const radius = BorderRadius.all(Radius.circular(16));
    return Semantics(
      button: true,
      selected: selected,
      label:
          '${s.approvalTitle(approval.reference)}, ${s.approvalLine(approval.leadName, approval.travelerCount)}',
      excludeSemantics: true,
      child: Material(
        color: selected ? SeenBrand.violet05 : c.card,
        shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(color: selected ? SeenBrand.violet : c.border)),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(borderRadius: radius),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(
                      color: SeenBrand.violet10,
                      borderRadius: BorderRadius.all(Radius.circular(11))),
                  child: SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(SeenIcons.shield,
                          size: 20, color: SeenBrand.violet)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.approvalTitle(approval.reference), style: t.label),
                      Text(
                          s.approvalLine(
                              approval.leadName, approval.travelerCount),
                          style: t.caption.copyWith(color: c.inkSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(s.approvalIssued(approval.issuedAt),
                          style: t.caption.copyWith(
                              color: SeenRequestStatus.completed.colors.fg)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SeenRadioDot(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
