// Change e-mail (Figma ACC-09 form, ACC-10 "check your e-mail"). The server mails a link to the
// NEW address and confirms the change from that link (a web page). It never says whether an
// address is taken and has no "resend" or "pending" read, so neither is offered here.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/email_change.dart';
import '../bloc/email_change_cubit.dart';
import 'forgot_password_flow.dart' show SeenMotionlessEye;
import '../../../../core/presentation/foundation/seen_strings.dart';

class ChangeEmailScreen extends StatelessWidget {
  const ChangeEmailScreen({super.key, this.createCubit, this.openMailApp});

  /// Test seam; defaults to the DI container.
  final EmailChangeCubit Function()? createCubit;

  /// Test seam for "Open email"; defaults to the platform's mail app.
  final Future<void> Function()? openMailApp;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const ChangeEmailScreen());

  static Future<void> _openMail() async {
    await launchUrl(Uri(scheme: 'mailto'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createCubit ?? InjectionContainer.instance.createEmailChangeCubit)()..load(),
      child: _Body(openMailApp: openMailApp ?? _openMail),
    );
  }
}

class _Body extends StatefulWidget {
  const _Body({required this.openMailApp});

  final Future<void> Function() openMailApp;

  @override
  State<_Body> createState() => _BodyState();
}

class _BodyState extends State<_Body> {
  // Owned here, disposed in dispose().
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSend => _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  void _edited() {
    context.read<EmailChangeCubit>().edited();
    setState(() {});
  }

  void _send() => context.read<EmailChangeCubit>().submit(newEmail: _email.text, password: _password.text);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<EmailChangeCubit, EmailChangeState>(
      // The password is sent once: nothing of it stays once the link went out.
      listenWhen: (a, b) => a.sentTo == null && b.sentTo != null,
      listener: (context, state) => _password.clear(),
      builder: (context, state) {
        final sent = state.sentTo != null;
        return Scaffold(
          backgroundColor: SeenColors.of(context).card,
          body: SeenScreenBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SeenScreenHeader(
                    title: l10n.accChangeEmail,
                    // The "check your e-mail" state closes the flow instead of going back a step.
                    showBack: !sent,
                    trailing: sent
                        ? SeenRoundIconButton(
                            icon: SeenIcons.x,
                            semanticLabel: l10n.commonClose,
                            onPressed: () => Navigator.of(context).maybePop(),
                          )
                        : null,
                  ),
                  Expanded(child: sent ? _Sent(email: state.sentTo!) : _Form(state: state, email: _email, password: _password, obscure: _obscure, onEdited: _edited, onToggleEye: () => setState(() => _obscure = !_obscure), onSubmit: _send)),
                  if (sent)
                    SeenActionBar(actions: [
                      SeenButton(label: l10n.accOpenMail, icon: SeenIcons.mail, expand: true, onPressed: widget.openMailApp),
                    ])
                  else
                    SeenActionBar(actions: [
                      SeenButton(
                        label: state.busy ? l10n.accSending : l10n.accSend,
                        expand: true,
                        loading: state.busy,
                        onPressed: state.busy || state.locked || !_canSend ? null : _send,
                      ),
                    ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.state,
    required this.email,
    required this.password,
    required this.obscure,
    required this.onEdited,
    required this.onToggleEye,
    required this.onSubmit,
  });

  final EmailChangeState state;
  final TextEditingController email;
  final TextEditingController password;
  final bool obscure;
  final VoidCallback onEdited;
  final VoidCallback onToggleEye;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final issue = state.issue;
    final kind = issue?.kind;
    final emailError = switch (kind) {
      EmailChangeIssueKind.invalidEmail => l10n.accInvalidEmail,
      EmailChangeIssueKind.sameAsCurrent => l10n.accSameEmail,
      _ => null,
    };
    final wrongPassword = kind == EmailChangeIssueKind.wrongPassword;
    final banner = switch (kind) {
      EmailChangeIssueKind.rateLimited => SeenInlineBanner(
          tone: SeenBannerTone.error,
          message: '${l10n.accTooManyTitle}. ${SeenStrings.of(context).digits(l10n.accTooManyBody(issue?.minutes ?? 10))}',
        ),
      EmailChangeIssueKind.offline => SeenInlineBanner(tone: SeenBannerTone.offline, message: l10n.accSendFailed),
      EmailChangeIssueKind.sendFailed || EmailChangeIssueKind.generic => SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.accSendFailed),
      _ => null,
    };
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(l10n.accFormIntro, style: type.body.copyWith(color: c.inkSecondary)),
        const SizedBox(height: 16),
        SeenTextField(
          key: ValueKey(state.currentEmail),
          label: l10n.accCurrentEmail,
          initialValue: state.currentEmail ?? '',
          readOnly: true,
          ltr: true,
          prefixIcon: SeenIcons.lock,
        ),
        const SizedBox(height: 14),
        SeenTextField(
          label: l10n.accNewEmail,
          controller: email,
          ltr: true,
          enabled: !state.locked,
          hint: 'name@mail.com',
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          showError: emailError != null,
          errorText: emailError,
          onChanged: (_) => onEdited(),
        ),
        const SizedBox(height: 14),
        SeenTextField(
          label: l10n.accCurrentPassword,
          controller: password,
          enabled: !state.locked,
          hint: l10n.accPasswordHint,
          obscureText: obscure,
          suffix: SeenMotionlessEye(
            obscured: obscure,
            onTap: onToggleEye,
            showLabel: l10n.showPasswordAction,
            hideLabel: l10n.hidePasswordAction,
          ),
          autofillHints: const [AutofillHints.password],
          textInputAction: TextInputAction.done,
          showError: wrongPassword,
          // The server does not say how many tries are left, so the plain wording is used.
          errorText: wrongPassword ? l10n.accWrongPassword(0) : null,
          onChanged: (_) => onEdited(),
          onSubmitted: (_) => onSubmit(),
        ),
        if (banner != null) ...[const SizedBox(height: 14), banner],
      ],
    );
  }
}

class _Sent extends StatelessWidget {
  const _Sent({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      children: [
        Center(
          child: DecoratedBox(
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: const BorderRadius.all(SeenRadius.r22)),
            child: SizedBox(width: 72, height: 72, child: Icon(SeenIcons.mail, size: 32, color: c.accent)),
          ),
        ),
        const SizedBox(height: 16),
        Text(l10n.accCheckTitle, style: type.h1, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(l10n.accCheckSentTo, style: type.body.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(email, style: type.bodyStrong, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 12),
        Text(l10n.accCheckNote, style: type.caption.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        Center(
          child: SeenTextLink(
            label: l10n.accEditEmail,
            onTap: () => context.read<EmailChangeCubit>().editAddress(),
          ),
        ),
      ],
    );
  }
}
