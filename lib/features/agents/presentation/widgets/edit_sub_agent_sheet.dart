import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../domain/entities/new_sub_agent.dart' show SubAgentIssue, SubAgentIssueKind;
import '../../domain/entities/sub_agent.dart';
import '../bloc/edit_sub_agent_cubit.dart';

/// Edits a sub-agency's name and its owner's name / sign-in e-mail (`updateAgentProfile`).
/// Resolves to true when something was saved (the caller reads the profile again).
Future<bool?> showEditSubAgentSheet(BuildContext context, {required SubAgent subAgent, EditSubAgentCubit Function()? createCubit}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => EditSubAgentSheet(subAgent: subAgent, createCubit: createCubit),
  );
}

class EditSubAgentSheet extends StatefulWidget {
  const EditSubAgentSheet({super.key, required this.subAgent, this.createCubit});

  final SubAgent subAgent;

  /// Test seam; defaults to the DI container.
  final EditSubAgentCubit Function()? createCubit;

  @override
  State<EditSubAgentSheet> createState() => _EditSubAgentSheetState();
}

class _EditSubAgentSheetState extends State<EditSubAgentSheet> {
  // Owned here, disposed in dispose().
  late final _name = TextEditingController(text: widget.subAgent.name);
  late final _owner = TextEditingController(text: widget.subAgent.ownerName ?? '');
  final _email = TextEditingController();
  late final EditSubAgentCubit _cubit = (widget.createCubit ??
      () => InjectionContainer.instance.createEditSubAgentCubit(widget.subAgent.id, name: widget.subAgent.name, ownerName: widget.subAgent.ownerName ?? ''))();

  @override
  void dispose() {
    _cubit.close();
    _name.dispose();
    _owner.dispose();
    _email.dispose();
    super.dispose();
  }

  String? _emailError() {
    final v = _email.text.trim();
    return v.isEmpty || (v.contains('@') && v.contains('.')) ? null : AppLocalizations.of(context)!.validationInvalidEmail;
  }

  void _submit() {
    if (_emailError() != null || _name.text.trim().isEmpty) {
      setState(() {});
      return;
    }
    _cubit.submit(name: _name.text, ownerName: _owner.text, ownerEmail: _email.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    return BlocListener<EditSubAgentCubit, EditAgentState>(
      bloc: _cubit,
      listenWhen: (p, n) => p.status != n.status,
      listener: (context, state) {
        if (state.status == EditAgentStatus.done) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(s.editAgentDone)));
          Navigator.of(context).pop(true);
        } else if (state.status == EditAgentStatus.failed) {
          final f = state.failure;
          final taken = f != null && SubAgentIssue.from(f).kind == SubAgentIssueKind.emailTaken;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(taken ? l10n.agentAddEmailTaken : failureTextOr(l10n, f, l10n.error))));
        }
      },
      child: SeenSheet(
        title: s.editAgentTitle,
        footer: BlocBuilder<EditSubAgentCubit, EditAgentState>(
          bloc: _cubit,
          builder: (context, state) {
            final busy = state.status == EditAgentStatus.submitting;
            return SeenButton(label: busy ? l10n.loading : s.editAgentSave, expand: true, onPressed: busy ? null : _submit);
          },
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SeenTextField(label: l10n.agentAddName, controller: _name, errorText: _name.text.trim().isEmpty ? l10n.validationRequired : null, onChanged: (_) => setState(() {})),
            const SizedBox(height: 12),
            SeenTextField(label: l10n.agentAddManager, controller: _owner),
            const SizedBox(height: 12),
            SeenTextField(
              label: l10n.agentAddEmail,
              controller: _email,
              ltr: true,
              keyboardType: TextInputType.emailAddress,
              helper: s.editAgentEmailHint,
              errorText: _emailError(),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
    );
  }
}
