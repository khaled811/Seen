// Users and permissions (Figma ACC-03): the agency's team with role and status,
// the roles explained, and invite / change role / disable. Owner only.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/navigation/shell_tab_request.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/selection.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/presentation/widgets/loading/seen_refresh.dart';
import '../../../../core/presentation/widgets/loading/seen_loader.dart';
import '../../../../core/presentation/widgets/loading/seen_wait_policy.dart';
import '../../../auth/domain/entities/role_permissions.dart';
import '../../../system_status/presentation/widgets/access_denied_view.dart';
import '../../domain/entities/branch.dart';
import '../../domain/entities/team_member.dart';
import '../widgets/branch_strings.dart' show BranchStrings;
import '../bloc/profile_cubits.dart';
import '../widgets/profile_strings.dart';
import '../widgets/session_role.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key, this.createCubit, this.canManage, this.loadBranches});

  /// Test seams: default to the DI container and the signed-in position.
  final TeamCubit Function()? createCubit;
  final bool? canManage;

  /// The branches offered when inviting; defaults to the server's list.
  final Future<List<Branch>> Function()? loadBranches;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const TeamScreen());

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final allowed = canManage ?? permissionsOf(context).can(Capability.team);
    return Scaffold(
      backgroundColor: SeenColors.of(context).card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: allowed
              ? BlocProvider(
                  create: (_) => (createCubit ?? InjectionContainer.instance.createTeamCubit)()..load(),
                  child: _Allowed(loadBranches: loadBranches),
                )
              : Column(
                  children: [
                    SeenScreenHeader(title: s.teamTitle),
                    Expanded(
                      child: AccessDeniedView(
                        area: 'team',
                        message: s.teamForbidden,
                        onBack: () {
                          Navigator.of(context).maybePop();
                          ShellTabRequest.show(0);
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Allowed extends StatelessWidget {
  const _Allowed({this.loadBranches});

  final Future<List<Branch>> Function()? loadBranches;

  Future<void> _invite(BuildContext context) async {
    final cubit = context.read<TeamCubit>();
    // The real branches when the server has them; otherwise the branch is typed.
    final branches = await (loadBranches ??
        () async => (await InjectionContainer.instance.branchRepository.list()).getOrElse((_) => const <Branch>[]))();
    if (!context.mounted) {
      return;
    }
    final draft = await showSeenSheet<InviteDraft>(
      context: context,
      title: SeenStrings.of(context).inviteUser,
      builder: (_) => _InviteForm(branches: branches),
    );
    if (draft != null) {
      await cubit.invite(draft);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return BlocConsumer<TeamCubit, TeamState>(
      listenWhen: (p, c) => p.noticeSeq != c.noticeSeq && c.notice != null,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(state.notice == TeamNotice.failed && state.failure != null
              ? failureTextOr(AppLocalizations.of(context)!, state.failure, s.teamNotice(state.notice!))
              : s.teamNotice(state.notice!)),
        )),
      builder: (context, state) {
        return Column(
          children: [
            SeenScreenHeader(
              title: s.teamTitle,
              trailing: SeenRoundIconButton(
                icon: SeenIcons.plus,
                tonal: true,
                semanticLabel: s.inviteUser,
                onPressed: state.status == LoadStatus.loaded ? () => _invite(context) : null,
              ),
            ),
            Expanded(child: _Body(state: state)),
            if (state.status == LoadStatus.loaded)
              SeenActionBar(
                actions: [SeenButton(label: s.inviteUser, expand: true, onPressed: () => _invite(context))],
              ),
          ],
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final TeamState state;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final c = SeenColors.of(context);
    final cubit = context.read<TeamCubit>();
    if (state.members.isEmpty) {
      if (state.status == LoadStatus.failure) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.loadFailedTitle),
              const SizedBox(height: SeenSpace.s3),
              SeenButton(label: s.retry, onPressed: cubit.load),
            ],
          ),
        );
      }
      return SeenWaitPolicy.loading(
        loading: SeenCardsSkeleton(label: SeenStrings.of(context).loadingLabel),
        onRetry: cubit.load,
      );
    }
    return SeenRefresh(
      onRefresh: cubit.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, SeenSpace.s6),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.all(SeenRadius.r22),
              border: Border.all(color: c.border),
              boxShadow: SeenShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < state.members.length; i++)
                    _MemberRow(member: state.members[i], last: i == state.members.length - 1, busy: state.busyId == state.members[i].id),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(s.rolesTitle, style: t.title),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.all(SeenRadius.r22),
              border: Border.all(color: c.border),
              boxShadow: SeenShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final r in TeamRole.values)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s.roleName(r), style: t.body.copyWith(color: c.inkSecondary)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(s.roleDescription(r), textAlign: TextAlign.end, style: t.caption.copyWith(color: c.inkSecondary)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) {
    return '';
  }
  final latin = RegExp(r'^[A-Za-z]');
  if (parts.length > 1 && latin.hasMatch(parts.first)) {
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }
  return parts.first.substring(0, 1);
}

SeenRequestStatus _chip(TeamMemberStatus s) => switch (s) {
      TeamMemberStatus.active => SeenRequestStatus.completed,
      TeamMemberStatus.invited => SeenRequestStatus.underReview,
      TeamMemberStatus.disabled => SeenRequestStatus.cancelled,
    };

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member, required this.last, required this.busy});

  final TeamMember member;
  final bool last;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    return Semantics(
      button: !member.isOwner,
      child: InkWell(
        onTap: member.isOwner || busy ? null : () => _showActions(context, member),
        child: DecoratedBox(
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.border))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: const BoxDecoration(color: SeenBrand.violet10, shape: BoxShape.circle),
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: Center(child: Text(_initials(member.name), style: t.label.copyWith(color: SeenBrand.violet))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member.name, style: t.label),
                      Text(s.memberSubtitle(member), style: t.caption.copyWith(color: c.inkMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (busy)
                  const SeenLoader(size: 20)
                else
                  SeenStatusChip(status: _chip(member.status), label: s.memberStatus(member.status)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Action { changeRole }

Future<void> _showActions(BuildContext context, TeamMember m) async {
  final cubit = context.read<TeamCubit>();
  final s = SeenStrings.of(context);
  // The API can change a user's role only: it has no disabling, enabling or invitations.
  const actions = [_Action.changeRole];
  String label(_Action a) => switch (a) {
        _Action.changeRole => s.changeRoleAction,
      };
  final picked = await showSeenSheet<_Action>(
    context: context,
    title: m.name,
    subtitle: s.memberSubtitle(m),
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final a in actions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(label(a)),
            onTap: () => Navigator.of(sheet).pop(a),
          ),
      ],
    ),
  );
  if (picked == null || !context.mounted) {
    return;
  }
  switch (picked) {
    case _Action.changeRole:
      final role = await showSeenSheet<TeamRole>(
        context: context,
        title: s.changeRoleAction,
        builder: (_) => _RolePicker(current: m.role),
      );
      if (role != null && role != m.role) {
        await cubit.changeRole(m.id, role);
      }

  }
}

/// The owner role is not assignable here: there is one owner.
const _assignable = [TeamRole.branchManager, TeamRole.staff];

class _RolePicker extends StatelessWidget {
  const _RolePicker({required this.current});

  final TeamRole current;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final c = SeenColors.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final r in _assignable)
          InkWell(
            onTap: () => Navigator.of(context).pop(r),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  SeenRadioDot(selected: r == current),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.roleName(r), style: t.body),
                        Text(s.roleDescription(r), style: t.caption.copyWith(color: c.inkMuted)),
                      ],
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

/// The invite sheet's body. Owns its controllers (created here, disposed here).
class _InviteForm extends StatefulWidget {
  const _InviteForm({this.branches = const []});

  /// Branches to pick from; empty = a text field.
  final List<Branch> branches;

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _branch = TextEditingController();
  TeamRole _role = TeamRole.staff;
  Branch? _picked;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _branch.dispose();
    super.dispose();
  }

  Future<void> _pickBranch() async {
    final s = SeenStrings.of(context);
    final picked = await showSeenSheet<Branch>(
      context: context,
      title: s.chooseBranch,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final b in widget.branches)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(b.name),
              trailing: SeenRadioDot(selected: b.id == _picked?.id),
              onTap: () => Navigator.of(sheet).pop(b),
            ),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        _picked = picked;
        _branch.text = picked.name;
      });
    }
  }

  void _submit() {
    final s = SeenStrings.of(context);
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    setState(() {
      _nameError = name.isEmpty ? s.fieldRequired : null;
      _emailError = email.isEmpty ? s.fieldRequired : (email.contains('@') && email.contains('.') ? null : s.emailInvalid);
      _passwordError = password.length >= 12 ? null : s.passwordTooShort;
    });
    if (_nameError != null || _emailError != null || _passwordError != null) {
      return;
    }
    Navigator.of(context).pop(InviteDraft(
      name: name,
      email: email,
      password: password,
      role: _role,
      branchName: _picked?.name ?? '',
      branchId: _picked?.id,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeenTextField(label: s.inviteName, controller: _name, errorText: _nameError, textInputAction: TextInputAction.next),
        const SizedBox(height: 12),
        SeenTextField(
          label: s.inviteEmail,
          controller: _email,
          ltr: true,
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        SeenTextField(
          label: s.invitePassword,
          controller: _password,
          ltr: true,
          obscureText: true,
          helper: s.invitePasswordHint,
          errorText: _passwordError,
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 12),
        Text(s.inviteRole, style: t.label),
        for (final r in _assignable)
          InkWell(
            onTap: () => setState(() => _role = r),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  SeenRadioDot(selected: r == _role),
                  const SizedBox(width: 12),
                  Text(s.roleName(r), style: t.body),
                ],
              ),
            ),
          ),
        const SizedBox(height: 4),
        // The branch is optional, and only a real one (picked from the list) can be sent.
        if (widget.branches.isNotEmpty)
          SeenTextField(
            label: s.inviteBranch,
            controller: _branch,
            readOnly: true,
            picker: true,
            onTap: _pickBranch,
            suffix: Icon(SeenIcons.forward(context), size: 16),
          ),
        const SizedBox(height: SeenSpace.s4),
        SeenButton(label: s.inviteSend, expand: true, onPressed: _submit),
      ],
    );
  }
}
