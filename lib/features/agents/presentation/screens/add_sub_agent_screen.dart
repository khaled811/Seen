import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/failure_message.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../../core/presentation/widgets/loading/seen_blocking_overlay.dart';
import '../../../../core/presentation/widgets/loading/loading_strings.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../auth/presentation/utils/phone_identifier.dart';
import '../../domain/entities/new_sub_agent.dart';
import '../bloc/sub_agent_management_bloc.dart';

/// Add sub-agent (Figma AGT-01) and its success page (AGT-01b). Owns an
/// [AddSubAgentBloc]; pops with `true` when the user leaves after adding one,
/// so the agents list reloads.
class AddSubAgentScreen extends StatelessWidget {
  const AddSubAgentScreen({super.key, this.createBloc});

  /// Test seam; defaults to the DI container.
  final AddSubAgentBloc Function()? createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          (createBloc ?? InjectionContainer.instance.createAddSubAgentBloc)(),
      child: const _View(),
    );
  }
}

class _View extends StatefulWidget {
  const _View();

  @override
  State<_View> createState() => _ViewState();
}

class _ViewState extends State<_View> {
  // Owned here, disposed in dispose().
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _manager = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _addedAny = false;

  @override
  void dispose() {
    _name.dispose();
    _manager.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _clear() {
    for (final c in [_name, _manager, _email, _password]) {
      c.clear();
    }
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AddSubAgentBloc>().add(AddSubAgentSubmitted(NewSubAgent(
          agencyName: _name.text.trim(),
          managerName: _manager.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
        )));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<AddSubAgentBloc, AddSubAgentState>(
      listenWhen: (previous, current) =>
          previous.created == null && current.created != null,
      listener: (context, state) => _addedAny = true,
      builder: (context, state) {
        final created = state.created;
        if (created != null) {
          return _Success(
            agentName: created.name,
            invited: created.invitePending,
            onAnother: () {
              context.read<AddSubAgentBloc>().add(const AddSubAgentReset());
              _clear();
            },
            onBack: () => Navigator.of(context).pop(true),
          );
        }
        final issue = state.issue;
        final emailTaken = issue?.kind == SubAgentIssueKind.emailTaken;
        String? required(String? v) =>
            FormValidators.required(v, message: l10n.validationRequired);
        void dismiss() {
          if (issue != null) {
            context
                .read<AddSubAgentBloc>()
                .add(const AddSubAgentIssueDismissed());
          }
        }

        return PopScope(
          canPop: !_addedAny,
          onPopInvoked: (didPop) {
            if (!didPop) Navigator.of(context).pop(true);
          },
          child: SeenBlockingOverlay(
            visible: state.submitting,
            title: SeenStrings.of(context).submittingSubAgent,
            child: Scaffold(
            body: SeenScreenBackground(
              washHeight: 320,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    SeenScreenHeader(title: l10n.agentAddTitle),
                    Expanded(
                      child: Form(
                        key: _formKey,
                        child: ListView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                          children: [
                            SeenTextField(
                              label: l10n.agentAddName,
                              isRequired: true,
                              controller: _name,
                              textInputAction: TextInputAction.next,
                              validator: required,
                            ),
                            const SizedBox(height: 14),
                            SeenTextField(
                              label: l10n.agentAddManager,
                              isRequired: true,
                              controller: _manager,
                              textInputAction: TextInputAction.next,
                              validator: required,
                            ),
                            const SizedBox(height: 14),
                            SeenTextField(
                              label: l10n.agentAddEmail,
                              isRequired: true,
                              controller: _email,
                              ltr: true,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              errorText: emailTaken ? l10n.agentAddEmailTaken : null,
                              onChanged: (_) => dismiss(),
                              validator: (v) {
                                final value = (v ?? '').trim();
                                if (value.isEmpty) return l10n.validationRequired;
                                return value.contains('@') && PhoneIdentifier.isValidIdentifier(value)
                                    ? null
                                    : l10n.validationInvalidEmail;
                              },
                            ),
                            const SizedBox(height: 14),
                            SeenTextField(
                              label: l10n.agentAddPassword,
                              isRequired: true,
                              controller: _password,
                              ltr: true,
                              obscureText: true,
                              helper: l10n.agentAddPasswordHint,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => dismiss(),
                              validator: (v) => (v ?? '').length >= 12 ? null : l10n.agentAddPasswordShort,
                            ),
                            const SizedBox(height: 14),
                            if (issue != null && issue.kind != SubAgentIssueKind.emailTaken) ...[
                              const SizedBox(height: 14),
                              SeenInlineBanner(
                                tone: issue.kind == SubAgentIssueKind.offline
                                    ? SeenBannerTone.offline
                                    : SeenBannerTone.error,
                                message: switch (issue.kind) {
                                  SubAgentIssueKind.offline => l10n.recoveryOffline,
                                  SubAgentIssueKind.weakPassword => passwordRuleMessage(l10n, issue.passwordRule),
                                  SubAgentIssueKind.notAllowed => l10n.agentAddNotAllowed,
                                  _ => l10n.recoveryServerError,
                                },
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    SeenActionBar(
                      actions: [
                        SeenButton(
                          label: state.submitting
                              ? l10n.loading
                              : l10n.agentAddSubmit,
                          loading: state.submitting,
                          expand: true,
                          onPressed: state.submitting ? null : _submit,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}

class _Success extends StatelessWidget {
  const _Success(
      {required this.agentName,
      required this.invited,
      required this.onAnother,
      required this.onBack});

  final String agentName;
  final bool invited;
  final VoidCallback onAnother;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final ok = SeenRequestStatus.completed.colors;
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) onBack();
      },
      child: Scaffold(
        body: SeenScreenBackground(
          washHeight: 320,
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: ok.bg,
                                shape: BoxShape.circle,
                                border: Border.all(color: c.border)),
                            child: SizedBox(
                              width: 128,
                              height: 128,
                              child: Center(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: c.card,
                                    borderRadius:
                                        const BorderRadius.all(SeenRadius.r20),
                                    boxShadow: SeenShadows.stickyBar,
                                  ),
                                  child: const SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: Center(
                                        child: SeenSvgIcon(
                                            SeenVectors.agentAdded,
                                            size: 36)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(l10n.agentAddDoneTitle,
                            textAlign: TextAlign.center, style: t.h1),
                        const SizedBox(height: 12),
                        Text(
                          invited
                              ? l10n.agentAddDoneInvited(agentName)
                              : l10n.agentAddDoneNoInvite(agentName),
                          textAlign: TextAlign.center,
                          style: t.body.copyWith(color: c.inkSecondary),
                        ),
                        if (invited) ...[
                          const SizedBox(height: 12),
                          SeenStatusChip(
                              status: SeenRequestStatus.underReview,
                              label: l10n.agentAddPending),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              SeenActionBar(
                actions: [
                  SeenButton(
                      label: l10n.agentAddBackToList,
                      expand: true,
                      onPressed: onBack),
                  SeenButton.secondary(
                      label: l10n.agentAddAnother,
                      expand: true,
                      onPressed: onAnother),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
