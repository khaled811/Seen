// Users and permissions (Figma ACC-03): the agency's team with role and status,
// the roles explained, and invite / change role / disable. Owner only.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/navigation/shell_tab_request.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/selection.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/system_state.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/utils/latin_digits.dart';
import '../../../system_status/presentation/bloc/access_request_cubit.dart';
import '../../domain/entities/team_member.dart';
import '../bloc/profile_cubits.dart';
import '../widgets/profile_strings.dart';
import '../widgets/session_role.dart';

class TeamScreen extends StatelessWidget {
  const TeamScreen({super.key, this.createCubit, this.canManage});

  /// Test seams: default to the DI container and the signed-in position.
  final TeamCubit Function()? createCubit;
  final bool? canManage;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const TeamScreen());

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final allowed = canManage ?? canManageAgency(context);
    return Scaffold(
      backgroundColor: SeenColors.of(context).card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: allowed
              ? BlocProvider(
                  create: (_) => (createCubit ?? InjectionContainer.instance.createTeamCubit)()..load(),
                  child: const _Allowed(),
                )
              : Column(
                  children: [
                    SeenScreenHeader(title: s.teamTitle),
                    const Expanded(child: _Forbidden()),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Branch managers and staff do not manage users (Figma SYS-03 pattern).
class _Forbidden extends StatelessWidget {
  const _Forbidden();

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return BlocProvider(
      create: (_) => InjectionContainer.instance.createAccessRequestCubit('team'),
      child: BlocConsumer<AccessRequestCubit, AccessRequestState>(
        listenWhen: (p, c) => p.status != c.status,
        listener: (context, state) {
          final message = switch (state.status) {
            AccessRequestStatus.sent => s.accessRequestSent,
            AccessRequestStatus.failed => s.accessRequestFailed,
            _ => null,
          };
          if (message != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          }
        },
        builder: (context, state) => SeenForbiddenView(
          icon: SeenIcons.gear,
          title: s.forbiddenTitle,
          message: s.teamForbidden,
          requestLabel: s.requestAccess,
          requesting: state.status == AccessRequestStatus.sending,
          requested: state.status == AccessRequestStatus.sent,
          onRequest: () => context.read<AccessRequestCubit>().send(),
          backLabel: s.backToHome,
          onBack: () {
            Navigator.of(context).maybePop();
            ShellTabRequest.show(0);
          },
        ),
      ),
    );
  }
}

class _Allowed extends StatelessWidget {
  const _Allowed();

  Future<void> _invite(BuildContext context) async {
    final cubit = context.read<TeamCubit>();
    final draft = await showSeenSheet<InviteDraft>(
      context: context,
      title: SeenStrings.of(context).inviteUser,
      builder: (_) => const _InviteForm(),
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
        ..showSnackBar(SnackBar(content: Text(s.teamNotice(state.notice!)))),
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
      return const Center(child: SeenLoader());
    }
    return RefreshIndicator(
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
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
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

enum _Action { changeRole, disable, enable, resend, cancelInvite }

Future<void> _showActions(BuildContext context, TeamMember m) async {
  final cubit = context.read<TeamCubit>();
  final s = SeenStrings.of(context);
  final actions = switch (m.status) {
    TeamMemberStatus.active => [_Action.changeRole, _Action.disable],
    TeamMemberStatus.disabled => [_Action.changeRole, _Action.enable],
    TeamMemberStatus.invited => [_Action.resend, _Action.cancelInvite],
  };
  String label(_Action a) => switch (a) {
        _Action.changeRole => s.changeRoleAction,
        _Action.disable => s.disableUserAction,
        _Action.enable => s.enableUserAction,
        _Action.resend => s.resendInviteAction,
        _Action.cancelInvite => s.cancelInviteAction,
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
    case _Action.disable:
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.disableTitle(m.name)),
          content: Text(s.disableBody),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.keepEditing)),
            TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.disableUserAction)),
          ],
        ),
      );
      if (ok == true) {
        await cubit.setActive(m.id, active: false);
      }
    case _Action.enable:
      await cubit.setActive(m.id, active: true);
    case _Action.resend:
      await cubit.resendInvite(m.id);
    case _Action.cancelInvite:
      await cubit.cancelInvite(m.id);
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
  const _InviteForm();

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _branch = TextEditingController();
  TeamRole _role = TeamRole.staff;
  String? _nameError;
  String? _phoneError;
  String? _branchError;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _branch.dispose();
    super.dispose();
  }

  void _submit() {
    final s = SeenStrings.of(context);
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    final branch = _branch.text.trim();
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    setState(() {
      _nameError = name.isEmpty ? s.fieldRequired : null;
      _phoneError = phone.isEmpty ? s.fieldRequired : (digits.length < 7 ? s.phoneInvalid : null);
      _branchError = branch.isEmpty ? s.fieldRequired : null;
    });
    if (_nameError != null || _phoneError != null || _branchError != null) {
      return;
    }
    Navigator.of(context).pop(InviteDraft(name: name, phone: phone, role: _role, branchName: branch));
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
          label: s.invitePhone,
          controller: _phone,
          ltr: true,
          errorText: _phoneError,
          keyboardType: TextInputType.phone,
          inputFormatters: const [LatinDigitsFormatter()],
          textInputAction: TextInputAction.next,
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
        SeenTextField(label: s.inviteBranch, controller: _branch, errorText: _branchError, onSubmitted: (_) => _submit()),
        const SizedBox(height: SeenSpace.s4),
        SeenButton(label: s.inviteSend, expand: true, onPressed: _submit),
      ],
    );
  }
}
