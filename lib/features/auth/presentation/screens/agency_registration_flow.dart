import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/feedback.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/agency_registration.dart';
import '../bloc/agency_registration_bloc.dart';
import 'forgot_password_flow.dart' show SeenMotionlessEye;

/// Registration after the agency form (Figma AUTH-05 … AUTH-07, steps 2–4 of 4):
/// create a password, verify the phone with a code, accept the terms. Owns an
/// [AgencyRegistrationBloc]; the system back gesture steps back inside the flow
/// and leaves it (to the form, with its data kept) from the first step.
class AgencyRegistrationFlow extends StatelessWidget {
  const AgencyRegistrationFlow({
    super.key,
    required this.draft,
    required this.onExit,
    required this.onCompleted,
    this.onSignIn,
    this.createBloc,
  });

  final AgencyRegistrationDraft draft;

  /// Back to the form (step 1).
  final VoidCallback onExit;

  /// Registration submitted for review → pending approval.
  final VoidCallback onCompleted;

  /// "Sign in" from the phone-already-registered banner.
  final VoidCallback? onSignIn;

  /// Test seam; defaults to the DI container.
  final AgencyRegistrationBloc Function()? createBloc;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createBloc ?? () => InjectionContainer.instance.createAgencyRegistrationBloc(draft))(),
      child: BlocConsumer<AgencyRegistrationBloc, AgencyRegistrationState>(
        listenWhen: (previous, current) => previous.step != current.step && current.step == RegistrationStep.done,
        listener: (context, state) => onCompleted(),
        buildWhen: (previous, current) => previous.step != current.step,
        builder: (context, state) {
          final bloc = context.read<AgencyRegistrationBloc>();
          final step = state.step == RegistrationStep.done ? RegistrationStep.terms : state.step;
          void back() => bloc.add(const RegistrationBackPressed());
          return PopScope(
            canPop: false,
            onPopInvoked: (didPop) {
              if (didPop) return;
              step == RegistrationStep.password ? onExit() : back();
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (step) {
                RegistrationStep.password =>
                  _PasswordScreen(key: const ValueKey('registration-password'), onBack: onExit, onSignIn: onSignIn),
                RegistrationStep.otp => _PhoneScreen(
                    key: const ValueKey('registration-otp'),
                    onBack: back,
                    onEditPhone: onExit,
                    onSignIn: onSignIn,
                  ),
                _ => _TermsScreen(key: const ValueKey('registration-terms'), onBack: back),
              },
            ),
          );
        },
      ),
    );
  }
}

/// Shared frame: gradient wash, centred title + "step n of 4" with a back
/// button, the 4-segment progress, a scrolling body and a sticky action bar.
class _Frame extends StatelessWidget {
  const _Frame({
    required this.title,
    required this.step,
    required this.onBack,
    required this.children,
    required this.actions,
    this.showProgress = true,
  });

  final String title;
  final int step;
  final VoidCallback onBack;
  final List<Widget> children;
  final List<Widget> actions;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    return Scaffold(
      body: SeenScreenBackground(
        washHeight: 320,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SeenScreenHeader(
                title: title,
                subtitle: l10n.registrationStepOf(s.numeral(step), s.numeral(4)),
                onBack: onBack,
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                  children: [
                    if (showProgress) ...[_Progress(step: step), const SizedBox(height: 16)],
                    ...children,
                  ],
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

/// Four segments; the first [step] (from the start edge) are done.
class _Progress extends StatelessWidget {
  const _Progress({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: i < step ? SeenBrand.progressDone : SeenBrand.progressTodo,
                  borderRadius: const BorderRadius.all(Radius.circular(3)),
                ),
                child: const SizedBox(height: 5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- AUTH-05

class _PasswordScreen extends StatefulWidget {
  const _PasswordScreen({super.key, required this.onBack, this.onSignIn});

  final VoidCallback onBack;
  final VoidCallback? onSignIn;

  @override
  State<_PasswordScreen> createState() => _PasswordScreenState();
}

class _PasswordScreenState extends State<_PasswordScreen> {
  // Owned here, disposed in dispose().
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String get _text => _password.text;
  bool get _hasLength => _text.length >= 8;
  bool get _hasCase => RegExp('[a-z]').hasMatch(_text) && RegExp('[A-Z]').hasMatch(_text);
  bool get _hasDigit => RegExp('[0-9]').hasMatch(_text);
  bool get _hasSymbol => RegExp('[^A-Za-z0-9]').hasMatch(_text);
  bool get _hasDigitOrSymbol => _hasDigit || _hasSymbol;
  int get _score => [
        _hasLength,
        _hasCase,
        _hasDigitOrSymbol,
        _text.length >= 12 || (_hasDigit && _hasSymbol),
      ].where((x) => x).length;
  bool get _matches => _confirm.text == _text;
  bool get _valid => _hasLength && _hasCase && _hasDigitOrSymbol && _confirm.text.isNotEmpty && _matches;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final errorColors = SeenRequestStatus.rejected.colors;
    final okColor = SeenRequestStatus.completed.colors.fg;
    final score = _text.isEmpty ? 0 : _score;
    final strengthColor = score >= 3 ? okColor : (score == 2 ? SeenBrand.progressWaiting : errorColors.fg);
    final strengthLabel = switch (score) {
      <= 1 => l10n.recoveryStrengthWeak,
      2 => l10n.recoveryStrengthFair,
      3 => l10n.registrationStrengthGood,
      _ => l10n.registrationStrengthVeryStrong,
    };

    Widget rule(String label, bool ok) => Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: ok ? okColor : c.card,
                shape: BoxShape.circle,
                border: ok ? null : Border.all(color: c.borderStrong),
              ),
              child: SizedBox(
                width: 16,
                height: 16,
                child: ok ? Icon(SeenIcons.check, size: 10, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: t.caption.copyWith(color: ok ? okColor : c.inkMuted))),
          ],
        );

    Widget toggle() => SeenMotionlessEye(
          obscured: _obscure,
          onTap: () => setState(() => _obscure = !_obscure),
          showLabel: l10n.showPasswordAction,
          hideLabel: l10n.hidePasswordAction,
        );

    return BlocBuilder<AgencyRegistrationBloc, AgencyRegistrationState>(
      builder: (context, state) {
        final issue = state.issue;
        final mismatch = _confirm.text.isNotEmpty && !_matches;
        return _Frame(
          title: l10n.agencyCreateTitle,
          step: 2,
          onBack: widget.onBack,
          actions: [
            SeenButton(
              label: state.busy ? l10n.loading : l10n.agencySubmitAction,
              loading: state.busy,
              expand: true,
              onPressed: (state.busy || !_valid)
                  ? null
                  : () => context.read<AgencyRegistrationBloc>().add(RegistrationPasswordSubmitted(_text)),
            ),
          ],
          children: [
            Text(l10n.registrationPasswordHeading, style: t.h1),
            const SizedBox(height: 16),
            if (issue != null) ...[
              _issueBanner(l10n, s, issue, widget.onSignIn),
              const SizedBox(height: 16),
            ],
            SeenTextField(
              label: l10n.registrationPasswordLabel,
              helper: _obscure ? l10n.registrationPasswordHidden : l10n.registrationPasswordShown,
              controller: _password,
              obscureText: _obscure,
              suffix: toggle(),
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                setState(() {});
                if (issue != null) context.read<AgencyRegistrationBloc>().add(const RegistrationIssueDismissed());
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: i < score ? strengthColor : SeenBrand.progressTodo,
                        borderRadius: const BorderRadius.all(Radius.circular(3)),
                      ),
                      child: const SizedBox(height: 5),
                    ),
                  ),
                ],
              ],
            ),
            if (score > 0) ...[
              const SizedBox(height: 6),
              Text(strengthLabel, style: t.caption.copyWith(color: strengthColor)),
            ],
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: const BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(SeenRadius.lg)),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    rule(l10n.recoveryRuleLength, _hasLength),
                    const SizedBox(height: 8),
                    rule(l10n.recoveryRuleCase, _hasCase),
                    const SizedBox(height: 8),
                    rule(l10n.registrationRuleDigitOrSymbol, _hasDigitOrSymbol),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            SeenTextField(
              label: l10n.recoveryConfirmLabel,
              controller: _confirm,
              obscureText: _obscure,
              suffix: toggle(),
              errorText: mismatch ? l10n.recoveryMismatch : null,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
            ),
          ],
        );
      },
    );
  }
}

/// The banner for any [RegistrationIssue] that is not a code problem.
Widget _issueBanner(AppLocalizations l10n, SeenStrings s, RegistrationIssue issue, VoidCallback? onSignIn) {
  return switch (issue.kind) {
    RegistrationIssueKind.phoneTaken => SeenInlineBanner(
        tone: SeenBannerTone.error,
        message: l10n.registrationPhoneTaken,
        actionLabel: l10n.loginAction,
        onAction: onSignIn,
      ),
    RegistrationIssueKind.rateLimited => SeenInlineBanner(
        tone: SeenBannerTone.warn,
        message: l10n.recoveryRateLimited(s.clockMs(issue.seconds ?? 60)),
      ),
    RegistrationIssueKind.offline => SeenInlineBanner(tone: SeenBannerTone.offline, message: l10n.recoveryOffline),
    RegistrationIssueKind.weakPassword =>
      SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.recoveryPasswordWeak),
    RegistrationIssueKind.expiredCode => SeenInlineBanner(tone: SeenBannerTone.warn, message: l10n.recoveryExpired),
    RegistrationIssueKind.attemptsExhausted =>
      SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.recoveryExhausted(s.numeral(issue.minutes ?? 15))),
    RegistrationIssueKind.wrongCode ||
    RegistrationIssueKind.generic =>
      SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.recoveryServerError),
  };
}

// ---------------------------------------------------------------- AUTH-06

class _PhoneScreen extends StatefulWidget {
  const _PhoneScreen({super.key, required this.onBack, required this.onEditPhone, this.onSignIn});

  final VoidCallback onBack;
  final VoidCallback onEditPhone;
  final VoidCallback? onSignIn;

  @override
  State<_PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<_PhoneScreen> {
  // Owned here, cancelled / disposed in dispose().
  final _code = TextEditingController();
  Timer? _timer;
  int _remaining = 0;
  bool _seeded = false;

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _restartCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _remaining = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _remaining <= 0) return t.cancel();
      setState(() => _remaining--);
    });
  }

  void _verify([String? code]) {
    final value = code ?? _code.text.trim();
    if (value.length != 6) return;
    context.read<AgencyRegistrationBloc>().add(RegistrationCodeSubmitted(value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final errorColors = SeenRequestStatus.rejected.colors;
    return BlocConsumer<AgencyRegistrationBloc, AgencyRegistrationState>(
      listenWhen: (previous, current) => previous.codesSent != current.codesSent,
      listener: (context, state) {
        _code.clear();
        _restartCountdown(state.challenge?.resendCooldownSeconds ?? 60);
      },
      builder: (context, state) {
        if (!_seeded) {
          _seeded = true;
          // First build of this screen: seed from the challenge that opened it.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _restartCountdown(state.challenge?.resendCooldownSeconds ?? 60);
          });
        }
        final issue = state.issue;
        final wrong = issue?.kind == RegistrationIssueKind.wrongCode;
        void resend() => context.read<AgencyRegistrationBloc>().add(const RegistrationResendRequested());
        return _Frame(
          title: l10n.registrationVerifyTitle,
          step: 3,
          showProgress: false,
          onBack: widget.onBack,
          actions: [
            SeenButton(
              label: state.busy ? l10n.loading : l10n.registrationVerifyAction,
              loading: state.busy,
              expand: true,
              onPressed: state.busy ? null : _verify,
            ),
          ],
          children: [
            const _IconTile(asset: SeenVectors.iconChat),
            const SizedBox(height: 16),
            Text(l10n.registrationVerifyHeading, style: t.h1),
            const SizedBox(height: 16),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(
                  l10n.registrationVerifySent(SeenFormat.isolate(state.challenge?.maskedPhone ?? '')),
                  style: t.body.copyWith(color: c.inkSecondary),
                ),
                Text(l10n.registrationWrongNumber, style: t.body.copyWith(color: c.inkSecondary)),
                SeenTextLink(label: l10n.registrationEditNumber, onTap: widget.onEditPhone),
              ],
            ),
            const SizedBox(height: 16),
            SeenOtpInput(
              controller: _code,
              compact: true,
              error: wrong,
              onChanged: (_) {
                if (issue != null) context.read<AgencyRegistrationBloc>().add(const RegistrationIssueDismissed());
              },
              onCompleted: _verify,
            ),
            const SizedBox(height: 8),
            if (wrong)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${l10n.recoveryWrongCodeHeading}. ${s.attemptsLeft(issue?.attemptsLeft ?? 0)}.',
                  style: t.label.copyWith(color: errorColors.fg),
                ),
              ),
            Row(
              children: [
                Expanded(child: Text(l10n.registrationResendQuestion, style: t.label.copyWith(color: c.inkSecondary))),
                SeenTextLink(
                  label: _remaining > 0 ? l10n.registrationResendIn(s.clockMs(_remaining)) : l10n.registrationResend,
                  onTap: (_remaining > 0 || state.busy) ? null : resend,
                ),
              ],
            ),
            if (issue != null && !wrong) ...[
              const SizedBox(height: 16),
              _issueBanner(l10n, s, issue, widget.onSignIn),
            ],
          ],
        );
      },
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

// ---------------------------------------------------------------- AUTH-07

class _TermsScreen extends StatefulWidget {
  const _TermsScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<_TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<_TermsScreen> {
  bool _terms = false;
  bool _privacy = false;
  bool _marketing = false;

  // The readers (Figma AUTH-09 / 10) are not designed or served yet.
  void _readSoon() => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.registrationReadSoon)));

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return BlocBuilder<AgencyRegistrationBloc, AgencyRegistrationState>(
      builder: (context, state) {
        final issue = state.issue;
        return _Frame(
          title: l10n.registrationTermsTitle,
          step: 4,
          showProgress: false,
          onBack: widget.onBack,
          actions: [
            SeenButton(
              label: state.busy ? l10n.loading : l10n.registrationCreate,
              loading: state.busy,
              expand: true,
              onPressed: (state.busy || !_terms || !_privacy)
                  ? null
                  : () => context.read<AgencyRegistrationBloc>().add(RegistrationConsentSubmitted(
                        RegistrationConsent(acceptedTerms: _terms, acceptedPrivacy: _privacy, marketing: _marketing),
                      )),
            ),
            SeenButton.secondary(label: l10n.registrationBack, expand: true, onPressed: state.busy ? null : widget.onBack),
          ],
          children: [
            Text(l10n.registrationTermsHeading, style: t.h1),
            const SizedBox(height: 16),
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
                    for (final (i, text) in [
                      l10n.registrationTermsPoint1,
                      l10n.registrationTermsPoint2,
                      l10n.registrationTermsPoint3,
                    ].indexed) ...[
                      if (i > 0) const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: DecoratedBox(
                              decoration: BoxDecoration(color: SeenBrand.violet, shape: BoxShape.circle),
                              child: SizedBox(width: 6, height: 6),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(text, style: t.body.copyWith(color: c.inkSecondary))),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _ConsentRow(
              label: l10n.registrationConsentTerms,
              checked: _terms,
              onChanged: (v) => setState(() => _terms = v),
              readLabel: l10n.registrationRead,
              onRead: _readSoon,
            ),
            const SizedBox(height: 16),
            _ConsentRow(
              label: l10n.registrationConsentPrivacy,
              checked: _privacy,
              onChanged: (v) => setState(() => _privacy = v),
              readLabel: l10n.registrationRead,
              onRead: _readSoon,
            ),
            const SizedBox(height: 16),
            _ConsentRow(
              label: l10n.registrationConsentMarketing,
              checked: _marketing,
              onChanged: (v) => setState(() => _marketing = v),
            ),
            const SizedBox(height: 16),
            if (issue != null) ...[
              _issueBanner(l10n, s, issue, null),
              const SizedBox(height: 16),
            ],
            Text(l10n.registrationConsentNote, style: t.caption.copyWith(color: c.inkMuted)),
          ],
        );
      },
    );
  }
}

/// A bordered consent row: checkbox + label at the start, optional "Read" link
/// at the end. The whole row toggles the checkbox.
class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.label,
    required this.checked,
    required this.onChanged,
    this.readLabel,
    this.onRead,
  });

  final String label;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final String? readLabel;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.lg),
        border: Border.all(color: c.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                checked: checked,
                label: label,
                excludeSemantics: true,
                onTap: () => onChanged(!checked),
                child: InkWell(
                  onTap: () => onChanged(!checked),
                  child: Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: checked ? SeenBrand.violet : c.card,
                          borderRadius: const BorderRadius.all(Radius.circular(7)),
                          border: checked ? null : Border.all(color: c.borderStrong, width: 1.5),
                        ),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: checked ? Icon(SeenIcons.check, size: 14, color: Colors.white) : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(label, style: t.label.copyWith(color: c.ink))),
                    ],
                  ),
                ),
              ),
            ),
            if (readLabel != null) SeenTextLink(label: readLabel!, onTap: onRead),
          ],
        ),
      ),
    );
  }
}
