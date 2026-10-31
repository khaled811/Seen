// Branches (Figma ACC-07): the "view requests by branch" choice, the branch tree with
// staff and request counts, the people of the selected branch, and (owner) add a branch,
// assign a staff member, move one.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/selection.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/state/branch_scope.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/presentation/widgets/loading/seen_refresh.dart';
import '../../../../core/presentation/widgets/loading/seen_wait_policy.dart';
import '../../../auth/domain/entities/role_permissions.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/team_member.dart';
import '../bloc/branches_cubit.dart';
import '../bloc/profile_cubits.dart' show LoadStatus;
import '../widgets/branch_strings.dart';
import '../widgets/profile_strings.dart';
import '../widgets/session_role.dart';

class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key, this.createCubit, this.permissions, this.scope});

  /// Test seams: the cubit, the role, and the app-wide scope (default to DI, the session and the shared one).
  final BranchesCubit Function()? createCubit;
  final RolePermissions? permissions;
  final BranchScope? scope;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const BranchesScreen());

  @override
  Widget build(BuildContext context) {
    final perms = permissions ?? permissionsOf(context);
    return BlocProvider(
      create: (_) => (createCubit ?? InjectionContainer.instance.createBranchesCubit)()..load(),
      child: _View(canManage: perms.can(Capability.branches), scope: scope ?? BranchScope.shared),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.canManage, required this.scope});

  final bool canManage;
  final BranchScope scope;

  Future<void> _pickScope(BuildContext context, BranchesState state) async {
    final cubit = context.read<BranchesCubit>();
    final s = SeenStrings.of(context);
    final picked = await showSeenSheet<_Pick>(
      context: context,
      title: s.requestsByBranch,
      builder: (sheet) => _OptionList(
        options: [
          (value: const _Pick(null), label: s.allBranches, selected: scope.value == null),
          for (final b in state.branches) (value: _Pick(b.id), label: b.name, selected: scope.value == b.id),
        ],
      ),
    );
    if (picked != null) {
      cubit.setScope(picked.id);
    }
  }

  Future<void> _addBranch(BuildContext context) async {
    final cubit = context.read<BranchesCubit>();
    final name = await showSeenSheet<String>(
      context: context,
      title: SeenStrings.of(context).addBranch,
      builder: (_) => const _NameForm(),
    );
    if (name != null) {
      await cubit.create(name);
    }
  }

  /// Picks a branch other than [except]; null = dismissed.
  Future<String?> _chooseBranch(BuildContext context, BranchesState state, {String? except}) async {
    final s = SeenStrings.of(context);
    final picked = await showSeenSheet<_Pick>(
      context: context,
      title: s.chooseBranch,
      builder: (_) => _OptionList(
        options: [
          for (final b in state.branches)
            if (b.id != except) (value: _Pick(b.id), label: b.name, selected: false),
        ],
      ),
    );
    return picked?.id;
  }

  Future<void> _assign(BuildContext context, BranchesState state) async {
    final cubit = context.read<BranchesCubit>();
    final s = SeenStrings.of(context);
    final members = await cubit.assignableMembers();
    if (!context.mounted) {
      return;
    }
    if (members.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(s.noOneToAssign)));
      return;
    }
    final who = await showSeenSheet<_Pick>(
      context: context,
      title: s.chooseStaff,
      builder: (_) => _OptionList(
        options: [for (final m in members) (value: _Pick(m.id), label: '${m.name} · ${s.roleName(m.role)}', selected: false)],
      ),
    );
    if (who?.id == null || !context.mounted) {
      return;
    }
    final branch = await _chooseBranch(context, state);
    if (branch != null) {
      await cubit.assign(memberId: who!.id!, branchId: branch);
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
          child: BlocConsumer<BranchesCubit, BranchesState>(
            listenWhen: (p, n) => p.noticeSeq != n.noticeSeq && n.notice != null,
            listener: (context, state) => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(s.branchNotice(state.notice!)))),
            builder: (context, state) {
              return Column(
                children: [
                  SeenScreenHeader(
                    title: s.branchesTitle,
                    trailing: canManage
                        ? SeenRoundIconButton(
                            icon: SeenIcons.plus,
                            tonal: true,
                            semanticLabel: s.addBranch,
                            onPressed: state.status == LoadStatus.loaded ? () => _addBranch(context) : null,
                          )
                        : null,
                  ),
                  Expanded(child: _Body(state: state, canManage: canManage, scope: scope, view: this)),
                  if (canManage && state.status == LoadStatus.loaded)
                    SeenActionBar(
                      actions: [
                        SeenButton(
                          label: s.assignStaffToBranch,
                          expand: true,
                          loading: state.busy,
                          onPressed: state.busy ? null : () => _assign(context, state),
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

class _Pick {
  const _Pick(this.id);
  final String? id;
}

typedef _Option = ({_Pick value, String label, bool selected});

class _OptionList extends StatelessWidget {
  const _OptionList({required this.options});

  final List<_Option> options;

  @override
  Widget build(BuildContext context) {
    final t = SeenType.of(context);
    final c = SeenColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final o in options)
          InkWell(
            onTap: () => Navigator.of(context).pop(o.value),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SeenRadioDot(selected: o.selected),
                  const SizedBox(width: 12),
                  Expanded(child: Text(o.label, style: t.body.copyWith(color: o.selected ? c.primary : c.ink))),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _NameForm extends StatefulWidget {
  const _NameForm();

  @override
  State<_NameForm> createState() => _NameFormState();
}

class _NameFormState extends State<_NameForm> {
  // Owned here, disposed in dispose().
  final _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _name.text.trim();
    if (v.isEmpty) {
      setState(() => _error = SeenStrings.of(context).branchNameRequired);
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeenTextField(
          label: s.branchNameLabel,
          controller: _name,
          errorText: _error,
          onChanged: (_) => _error == null ? null : setState(() => _error = null),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: SeenSpace.s4),
        SeenButton(label: s.createAction, expand: true, onPressed: _submit),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.canManage, required this.scope, required this.view});

  final BranchesState state;
  final bool canManage;
  final BranchScope scope;
  final _View view;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final cubit = context.read<BranchesCubit>();
    if (state.branches.isEmpty) {
      if (state.status == LoadStatus.failure) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.branchesLoadFailed()),
              const SizedBox(height: SeenSpace.s3),
              SeenButton(label: s.retryAction, onPressed: cubit.load),
            ],
          ),
        );
      }
      return SeenWaitPolicy.loading(loading: SeenCardsSkeleton(label: s.loadingLabel, count: 2), onRetry: cubit.load);
    }
    final scopeName = scope.value == null
        ? s.allBranches
        : (state.branches.where((b) => b.id == scope.value).firstOrNull?.name ?? s.allBranches);
    final focus = state.focus;
    return SeenRefresh(
      onRefresh: cubit.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, SeenSpace.s6),
        children: [
          ListenableBuilder(
            listenable: scope,
            builder: (context, _) => Semantics(
              button: true,
              label: '${s.requestsByBranch}: ${scope.value == null ? s.allBranches : scopeName}',
              excludeSemantics: true,
              child: Material(
                color: SeenBrand.violet05,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                  side: BorderSide(color: SeenBrand.violet40),
                ),
                child: InkWell(
                  onTap: () => view._pickScope(context, state),
                  customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.requestsByBranch, style: t.caption.copyWith(color: c.inkMuted)),
                              Text(scope.value == null ? s.allBranches : scopeName, style: t.label),
                            ],
                          ),
                        ),
                        Icon(SeenIcons.forward(context), size: 16, color: c.inkMuted),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.all(SeenRadius.r22),
              border: Border.all(color: c.border),
              boxShadow: SeenShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  for (final b in state.branches)
                    _BranchRow(branch: b, focused: b.id == state.focusId, onTap: () => cubit.focus(b.id)),
                ],
              ),
            ),
          ),
          if (focus != null) ...[
            const SizedBox(height: 18),
            Text(s.branchStaffTitle(focus.name), style: t.title),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: const BorderRadius.all(SeenRadius.r22),
                border: Border.all(color: c.border),
                boxShadow: SeenShadows.card,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: state.staffLoading
                    ? const Padding(padding: EdgeInsets.all(16), child: SeenSkeletonGroup(child: SeenSkeletonBox(height: 40, radius: 12)))
                    : state.staff.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(s.noStaffInBranch, style: t.caption.copyWith(color: c.inkMuted)),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < state.staff.length; i++)
                                _StaffRow(
                                  person: state.staff[i],
                                  last: i == state.staff.length - 1,
                                  onMove: canManage && state.staff[i].role != TeamRole.owner
                                      ? () async {
                                          final target = await view._chooseBranch(context, state, except: focus.id);
                                          if (target != null) {
                                            await cubit.assign(memberId: state.staff[i].id, branchId: target);
                                          }
                                        }
                                      : null,
                                ),
                            ],
                          ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({required this.branch, required this.focused, required this.onTap});

  final Branch branch;
  final bool focused;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    final main = branch.isMain;
    return Semantics(
      button: true,
      selected: focused,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(color: focused ? SeenBrand.violet05 : null),
          child: Padding(
            // Sub-branches sit one level in from the main branch.
            padding: EdgeInsetsDirectional.fromSTEB(main ? 14 : 36, 10, 14, 10),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: SeenBrand.violet10,
                    borderRadius: BorderRadius.all(Radius.circular(main ? 11 : 9)),
                  ),
                  child: SizedBox(
                    width: main ? 36 : 30,
                    height: main ? 36 : 30,
                    child: Icon(main ? SeenIcons.bank : SeenIcons.users, size: main ? 20 : 17, color: SeenBrand.violet),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(branch.name, style: main ? t.bodyStrong : t.body)),
                if (branch.staffCount != null && branch.requestCount != null)
                  Text(
                    '${s.staffCountLabel(branch.staffCount!)} · ${s.requestCountLabel(branch.requestCount!)}',
                    style: t.caption.copyWith(color: c.inkMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.person, required this.last, required this.onMove});

  final BranchStaff person;
  final bool last;
  final VoidCallback? onMove;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.border))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: SeenBrand.violet10, shape: BoxShape.circle),
              child: SizedBox(
                width: 32,
                height: 32,
                child: Center(
                  child: Text(person.name.isEmpty ? '' : person.name.substring(0, 1), style: t.label.copyWith(color: SeenBrand.violet)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name, style: t.label),
                  Text(s.roleName(person.role), style: t.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
            if (onMove != null) SeenTextLink(label: s.moveToBranch, onTap: onMove),
          ],
        ),
      ),
    );
  }
}
