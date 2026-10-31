import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/password_recovery.dart';
import '../bloc/password_recovery_bloc.dart';

/// "Forgot password" (Figma AUTH-01): ask for the link, then the confirmation.
/// The server e-mails a link that opens a web page where the new password is
/// chosen (contract 3.3): the app has no code and no new-password step. Owns a
/// [PasswordRecoveryBloc]; the system back gesture goes from the confirmation
/// back to the form and leaves the flow from the form.
class ForgotPasswordFlow extends StatelessWidget {
  const ForgotPasswordFlow({
    super.key,
    required this.onExit,
    this.onCreateAccount,
    this.onContactSupport,
    this.createBloc,
  });

  /// Leaves the flow (back to Login).
  final VoidCallback onExit;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onContactSupport;

  /// Test seam; defaults to the DI container.
  final PasswordRecoveryBloc Function()? createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createBloc ?? InjectionContainer.instance.createPasswordRecoveryBloc)(),
      child: BlocBuilder<PasswordRecoveryBloc, PasswordRecoveryState>(
        buildWhen: (previous, current) => previous.step != current.step,
        builder: (context, state) {
          final bloc = context.read<PasswordRecoveryBloc>();
          return PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (didPop) return;
              if (state.step == RecoveryStep.request) {
                onExit();
              } else {
                bloc.add(const RecoveryBackPressed());
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (state.step) {
                RecoveryStep.request => _RequestLinkScreen(
                    key: const ValueKey('recovery-request'),
                    onBack: onExit,
                    onCreateAccount: onCreateAccount,
                    onContactSupport: onContactSupport,
                  ),
                RecoveryStep.linkSent => _LinkSentScreen(
                    key: const ValueKey('recovery-link-sent'),
                    onDone: onExit,
                    onOtherAddress: () => bloc.add(const RecoveryBackPressed()),
                  ),
              },
            ),
          );
        },
      ),
    );
  }
}

/// Shared frame: gradient wash, centred title with a back button, scrolling body
/// starting 128 px from the top, and a sticky action bar.
class _Frame extends StatelessWidget {
  const _Frame({required this.title, required this.onBack, required this.children, required this.actions});

  final String title;
  final VoidCallback onBack;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SeenScreenBackground(
        washHeight: 320,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SeenScreenHeader(title: title, onBack: onBack),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                  children: children,
                ),
              ),
              SeenActionBar(actions: actions),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(17))),
        child: SizedBox(width: 56, height: 56, child: Center(child: SeenSvgIcon(asset, size: 31))),
      ),
    );
  }
}

// ---------------------------------------------------------------- AUTH-01

class _RequestLinkScreen extends StatefulWidget {
  const _RequestLinkScreen({super.key, required this.onBack, this.onCreateAccount, this.onContactSupport});

  final VoidCallback onBack;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onContactSupport;

  @override
  State<_RequestLinkScreen> createState() => _RequestLinkScreenState();
}

class _RequestLinkScreenState extends State<_RequestLinkScreen> {
  // Owned here, disposed in dispose().
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<PasswordRecoveryBloc>().add(RecoveryLinkRequested(_email.text));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return BlocBuilder<PasswordRecoveryBloc, PasswordRecoveryState>(
      builder: (context, state) {
        final issue = state.issue;
        final rateLimited = issue?.kind == RecoveryIssueKind.rateLimited;
        return _Frame(
          title: l10n.recoveryTitle,
          onBack: widget.onBack,
          actions: [
            SeenButton(
              label: state.busy ? l10n.loading : l10n.recoverySendCode,
              loading: state.busy,
              expand: true,
              onPressed: state.busy ? null : _submit,
            ),
          ],
          children: [
            const _IconTile(asset: SeenVectors.accountSettings),
            const SizedBox(height: 18),
            Text(l10n.recoveryForgotHeading, style: t.h1),
            const SizedBox(height: 18),
            Text(l10n.recoveryRequestBody, style: t.body.copyWith(color: c.inkSecondary)),
            const SizedBox(height: 18),
            if (issue?.kind == RecoveryIssueKind.offline) ...[
              SeenInlineBanner(
                tone: SeenBannerTone.offline,
                message: l10n.recoveryOffline,
                actionLabel: l10n.recoveryRetry,
                onAction: _submit,
              ),
              const SizedBox(height: 16),
            ],
            if (issue?.kind == RecoveryIssueKind.generic) ...[
              SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.recoveryServerError),
              const SizedBox(height: 16),
            ],
            if (issue?.kind == RecoveryIssueKind.emailRequired) ...[
              SeenInlineBanner(tone: SeenBannerTone.warn, message: l10n.recoveryNeedsEmail),
              const SizedBox(height: 16),
            ],
            Form(
              key: _formKey,
              child: SeenTextField(
                key: const ValueKey('recovery-email'),
                label: l10n.recoveryMethodEmail,
                helper: l10n.recoveryRequestHelper,
                controller: _email,
                ltr: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                onChanged: (_) {
                  if (issue != null) context.read<PasswordRecoveryBloc>().add(const RecoveryIssueDismissed());
                },
                validator: (v) => (v ?? '').trim().contains('@') ? null : l10n.validationInvalidEmail,
              ),
            ),
            if (rateLimited) ...[
              const SizedBox(height: 16),
              // The server throttles by address and by IP (3 per hour per address).
              SeenInlineBanner(tone: SeenBannerTone.warn, message: l10n.errorTooManyAttempts('${issue?.minutes ?? 60}')),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  SeenTextLink(label: l10n.recoveryContactSupport, onTap: widget.onContactSupport),
                  SeenTextLink(label: l10n.welcomeCreateAgency, onTap: widget.onCreateAccount),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Eye toggle for password fields (the Figma "Icon/eye" at the field's end).
class SeenMotionlessEye extends StatelessWidget {
  const SeenMotionlessEye({
    super.key,
    required this.obscured,
    required this.onTap,
    required this.showLabel,
    required this.hideLabel,
  });

  final bool obscured;
  final VoidCallback onTap;
  final String showLabel;
  final String hideLabel;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Semantics(
      button: true,
      label: obscured ? showLabel : hideLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(obscured ? SeenIcons.eye : SeenIcons.eyeSlash, size: 20, color: c.inkMuted),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- AUTH-04

class _LinkSentScreen extends StatelessWidget {
  const _LinkSentScreen({super.key, required this.onDone, required this.onOtherAddress});

  final VoidCallback onDone;
  final VoidCallback onOtherAddress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final done = SeenRequestStatus.completed.colors;
    final email = context.select<PasswordRecoveryBloc, String?>((b) => b.state.email);
    return Scaffold(
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
                            color: done.bg,
                            shape: BoxShape.circle,
                            border: Border.all(color: c.border),
                          ),
                          child: SizedBox(
                            width: 128,
                            height: 128,
                            child: Center(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: c.card,
                                  borderRadius: const BorderRadius.all(SeenRadius.r20),
                                  boxShadow: const [
                                    BoxShadow(color: Color(0x1F2C186A), blurRadius: 16, offset: Offset(0, 12)),
                                  ],
                                ),
                                child: const SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: Center(child: SeenSvgIcon(SeenVectors.notifCheck, size: 36)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(l10n.recoveryLinkSentTitle, textAlign: TextAlign.center, style: t.h1),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 310),
                        child: Text(
                          l10n.recoveryLinkSentBody(email ?? ''),
                          textAlign: TextAlign.center,
                          style: t.body.copyWith(color: c.inkSecondary),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SeenTextLink(label: l10n.recoveryRetry, onTap: onOtherAddress),
                    ],
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                child: SeenButton(label: l10n.recoveryBackToLogin, expand: true, onPressed: onDone),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
