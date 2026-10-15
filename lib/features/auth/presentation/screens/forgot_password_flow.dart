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
import '../../../../core/utils/latin_digits.dart';
import '../../domain/entities/password_recovery.dart';
import '../bloc/password_recovery_bloc.dart';
import '../utils/phone_identifier.dart';

/// "Forgot password" (Figma AUTH-01 … AUTH-04): request a code, enter it, choose
/// a new password, confirmation. Owns a [PasswordRecoveryBloc]; the system back
/// gesture steps back inside the flow and leaves it from the first step.
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
              if (state.step == RecoveryStep.request || state.step == RecoveryStep.done) {
                onExit();
              } else {
                bloc.add(const RecoveryBackPressed());
              }
            },
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (state.step) {
                RecoveryStep.request => _RequestCodeScreen(
                    key: const ValueKey('recovery-request'),
                    onBack: onExit,
                    onCreateAccount: onCreateAccount,
                    onContactSupport: onContactSupport,
                  ),
                RecoveryStep.otp => _CodeScreen(
                    key: const ValueKey('recovery-otp'),
                    onBack: () => bloc.add(const RecoveryBackPressed()),
                    onContactSupport: onContactSupport,
                  ),
                RecoveryStep.newPassword => _NewPasswordScreen(
                    key: const ValueKey('recovery-password'),
                    onBack: () => bloc.add(const RecoveryBackPressed()),
                  ),
                RecoveryStep.done => _DoneScreen(key: const ValueKey('recovery-done'), onDone: onExit),
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

class _RequestCodeScreen extends StatefulWidget {
  const _RequestCodeScreen({super.key, required this.onBack, this.onCreateAccount, this.onContactSupport});

  final VoidCallback onBack;
  final VoidCallback? onCreateAccount;
  final VoidCallback? onContactSupport;

  @override
  State<_RequestCodeScreen> createState() => _RequestCodeScreenState();
}

class _RequestCodeScreenState extends State<_RequestCodeScreen> {
  // Owned here, disposed in dispose().
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _byPhone = true;
  Timer? _timer;
  int _lockSeconds = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _startLock(int seconds) {
    _timer?.cancel();
    setState(() => _lockSeconds = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_lockSeconds <= 1) {
        t.cancel();
        setState(() => _lockSeconds = 0);
        context.read<PasswordRecoveryBloc>().add(const RecoveryIssueDismissed());
      } else {
        setState(() => _lockSeconds--);
      }
    });
  }

  String get _identifier => _byPhone ? PhoneIdentifier.toIdentifier(_phone.text) : _email.text.trim();

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<PasswordRecoveryBloc>().add(RecoveryCodeRequested(_identifier));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return BlocConsumer<PasswordRecoveryBloc, PasswordRecoveryState>(
      listenWhen: (previous, current) =>
          current.issue?.kind == RecoveryIssueKind.rateLimited && previous.issue != current.issue,
      listener: (context, state) => _startLock(state.issue?.seconds ?? 60),
      builder: (context, state) {
        final issue = state.issue;
        final locked = issue?.kind == RecoveryIssueKind.rateLimited && _lockSeconds > 0;
        final unknown = issue?.kind == RecoveryIssueKind.unknownAccount;
        return _Frame(
          title: l10n.recoveryTitle,
          onBack: widget.onBack,
          actions: [
            Opacity(
              opacity: locked ? 0.45 : 1,
              child: SeenButton(
                label: state.busy ? l10n.loading : l10n.recoverySendCode,
                loading: state.busy,
                expand: true,
                onPressed: (state.busy || locked) ? null : _submit,
              ),
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
            _MethodSwitch(
              phoneSelected: _byPhone,
              phoneLabel: l10n.recoveryMethodPhone,
              emailLabel: l10n.recoveryMethodEmail,
              onChanged: (phone) {
                setState(() => _byPhone = phone);
                context.read<PasswordRecoveryBloc>().add(const RecoveryIssueDismissed());
              },
            ),
            const SizedBox(height: 18),
            Form(
              key: _formKey,
              child: _byPhone
                  ? SeenTextField(
                      key: const ValueKey('recovery-phone'),
                      label: l10n.recoveryMethodPhone,
                      helper: l10n.recoveryRequestHelper,
                      errorText: unknown ? l10n.recoveryUnknownPhone : null,
                      controller: _phone,
                      ltr: true,
                      keyboardType: TextInputType.phone,
                      inputFormatters: const [LatinDigitsFormatter()],
                      autofillHints: const [AutofillHints.telephoneNumber],
                      prefix: Padding(
                        padding: const EdgeInsetsDirectional.only(end: SeenSpace.s2),
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(PhoneIdentifier.defaultCountryCode, style: t.bodyStrong.copyWith(color: c.ink)),
                        ),
                      ),
                      onChanged: (_) {
                        if (unknown) context.read<PasswordRecoveryBloc>().add(const RecoveryIssueDismissed());
                      },
                      validator: (v) => PhoneIdentifier.isValid(v ?? '') ? null : l10n.validationInvalidPhone,
                    )
                  : SeenTextField(
                      key: const ValueKey('recovery-email'),
                      label: l10n.recoveryMethodEmail,
                      helper: l10n.recoveryRequestHelper,
                      errorText: unknown ? l10n.recoveryUnknownEmail : null,
                      controller: _email,
                      ltr: true,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onChanged: (_) {
                        if (unknown) context.read<PasswordRecoveryBloc>().add(const RecoveryIssueDismissed());
                      },
                      validator: (v) {
                        final value = v ?? '';
                        return value.contains('@') && PhoneIdentifier.isValidIdentifier(value)
                            ? null
                            : l10n.validationInvalidEmail;
                      },
                    ),
            ),
            if (issue?.kind == RecoveryIssueKind.rateLimited) ...[
              const SizedBox(height: 16),
              SeenInlineBanner(
                tone: SeenBannerTone.warn,
                message: l10n.recoveryRateLimited(s.clockMs(_lockSeconds > 0 ? _lockSeconds : (issue?.seconds ?? 0))),
              ),
            ],
            if (unknown || issue?.kind == RecoveryIssueKind.rateLimited) ...[
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

/// Figma "Method" segmented switch: violet-05 track, white raised selected pill.
class _MethodSwitch extends StatelessWidget {
  const _MethodSwitch({
    required this.phoneSelected,
    required this.phoneLabel,
    required this.emailLabel,
    required this.onChanged,
  });

  final bool phoneSelected;
  final String phoneLabel;
  final String emailLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    Widget seg(String label, bool selected, VoidCallback onTap) => Expanded(
          child: Semantics(
            button: true,
            selected: selected,
            label: label,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? c.card : null,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  boxShadow: selected ? SeenShadows.card : null,
                ),
                child: SizedBox(
                  height: 38,
                  child: Center(child: Text(label, style: t.label.copyWith(color: selected ? c.ink : c.inkSecondary))),
                ),
              ),
            ),
          ),
        );
    return DecoratedBox(
      decoration: const BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(Radius.circular(14))),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            seg(phoneLabel, phoneSelected, () => onChanged(true)),
            const SizedBox(width: 4),
            seg(emailLabel, !phoneSelected, () => onChanged(false)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- AUTH-02

class _CodeScreen extends StatefulWidget {
  const _CodeScreen({super.key, required this.onBack, this.onContactSupport});

  final VoidCallback onBack;
  final VoidCallback? onContactSupport;

  @override
  State<_CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<_CodeScreen> {
  // Owned here, cancelled / disposed in dispose().
  final _code = TextEditingController();
  Timer? _timer;
  int _remaining = 0;
  int _seenCodesSent = -1;

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
    context.read<PasswordRecoveryBloc>().add(RecoveryCodeSubmitted(value));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final errorColors = SeenRequestStatus.rejected.colors;
    return BlocConsumer<PasswordRecoveryBloc, PasswordRecoveryState>(
      listenWhen: (previous, current) => previous.codesSent != current.codesSent,
      listener: (context, state) {
        _code.clear();
        _restartCountdown(state.challenge?.resendCooldownSeconds ?? 60);
      },
      builder: (context, state) {
        if (_seenCodesSent != state.codesSent) {
          _seenCodesSent = state.codesSent;
          if (_timer == null) {
            // First build of this screen: seed from the challenge that opened it.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _restartCountdown(state.challenge?.resendCooldownSeconds ?? 60);
            });
          }
        }
        final issue = state.issue;
        final kind = issue?.kind;
        final wrong = kind == RecoveryIssueKind.wrongCode;
        final expired = kind == RecoveryIssueKind.expiredCode;
        final exhausted = kind == RecoveryIssueKind.attemptsExhausted;
        final hasIssue = wrong || expired || exhausted;
        void resend() => context.read<PasswordRecoveryBloc>().add(const RecoveryResendRequested());
        return _Frame(
          title: l10n.recoveryOtpTitle,
          onBack: widget.onBack,
          actions: [
            if (hasIssue)
              SeenButton.secondary(
                label: state.busy ? l10n.loading : l10n.recoveryResendNow,
                loading: state.busy,
                expand: true,
                onPressed: (state.busy || exhausted) ? null : resend,
              )
            else
              SeenButton(
                label: state.busy ? l10n.loading : l10n.recoveryVerify,
                loading: state.busy,
                expand: true,
                onPressed: state.busy ? null : _verify,
              ),
          ],
          children: [
            if (!wrong) ...[
              const _IconTile(asset: SeenVectors.iconChat),
              const SizedBox(height: 18),
            ],
            Text(wrong ? l10n.recoveryWrongCodeHeading : l10n.recoveryOtpHeading, style: t.h1),
            const SizedBox(height: 16),
            if (!wrong)
              Text(
                l10n.recoveryOtpSent(
                  SeenFormat.isolate(state.challenge?.maskedDestination ?? ''),
                ),
                style: t.body.copyWith(color: c.inkSecondary),
              ),
            if (!wrong) const SizedBox(height: 18),
            SeenOtpInput(
              controller: _code,
              compact: true,
              error: wrong,
              onChanged: (_) {
                if (hasIssue) context.read<PasswordRecoveryBloc>().add(const RecoveryIssueDismissed());
              },
              onCompleted: _verify,
            ),
            const SizedBox(height: 16),
            if (wrong)
              Text(
                '${l10n.recoveryWrongCodeHeading}. ${s.attemptsLeft(issue?.attemptsLeft ?? 0)}.',
                style: t.label.copyWith(color: errorColors.fg),
              ),
            if (expired)
              SeenInlineBanner(
                tone: SeenBannerTone.warn,
                message: l10n.recoveryExpired,
                actionLabel: l10n.recoveryResendAction,
                onAction: resend,
              ),
            if (exhausted)
              SeenInlineBanner(
                tone: SeenBannerTone.error,
                message: l10n.recoveryExhausted(s.numeral(issue?.minutes ?? 15)),
              ),
            if (kind == RecoveryIssueKind.offline) SeenInlineBanner(tone: SeenBannerTone.offline, message: l10n.recoveryOffline),
            if (kind == RecoveryIssueKind.generic) SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.recoveryServerError),
            if (!hasIssue) ...[
              Row(
                children: [
                  Expanded(child: Text(l10n.recoveryResendAfter, style: t.label.copyWith(color: c.inkSecondary))),
                  if (_remaining > 0)
                    _CountdownChip(label: s.clockMs(_remaining))
                  else
                    SeenTextLink(label: l10n.recoveryResendNow, onTap: resend),
                ],
              ),
            ],
            if (exhausted || expired) ...[
              const SizedBox(height: 12),
              SeenTextLink(label: l10n.recoveryContactSupport, onTap: widget.onContactSupport),
            ],
          ],
        );
      },
    );
  }
}

class _CountdownChip extends StatelessWidget {
  const _CountdownChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = SeenRequestStatus.actionRequired.colors;
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.bg, borderRadius: const BorderRadius.all(SeenRadius.full)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: colors.fg, shape: BoxShape.circle),
              child: const SizedBox(width: 6, height: 6),
            ),
            const SizedBox(width: 6),
            Text(label, textDirection: TextDirection.ltr, style: t.caption.copyWith(color: colors.fg)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- AUTH-03

class _NewPasswordScreen extends StatefulWidget {
  const _NewPasswordScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<_NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends State<_NewPasswordScreen> {
  // Owned here, disposed in dispose().
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _hasLength => _password.text.length >= 8;
  bool get _hasCase => RegExp('[a-z]').hasMatch(_password.text) && RegExp('[A-Z]').hasMatch(_password.text);
  bool get _hasDigit => RegExp('[0-9]').hasMatch(_password.text);
  int get _score =>
      [_hasLength, _hasCase, _hasDigit, _password.text.length >= 12 || RegExp('[^A-Za-z0-9]').hasMatch(_password.text)]
          .where((x) => x)
          .length;
  bool get _matches => _confirm.text == _password.text;
  bool get _valid => _hasLength && _hasCase && _hasDigit && _confirm.text.isNotEmpty && _matches;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final errorColors = SeenRequestStatus.rejected.colors;
    final okColor = SeenRequestStatus.completed.colors.fg;
    final score = _password.text.isEmpty ? 0 : _score;
    final strengthColor = score >= 3 ? okColor : (score == 2 ? SeenBrand.progressWaiting : errorColors.fg);
    final strengthLabel = switch (score) {
      <= 1 => l10n.recoveryStrengthWeak,
      2 => l10n.recoveryStrengthFair,
      _ => l10n.recoveryStrengthStrong,
    };

    Widget rule(String label, bool ok, {bool failed = false}) => Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: ok ? okColor : (failed ? errorColors.bg : c.card),
                shape: BoxShape.circle,
                border: ok ? null : Border.all(color: failed ? errorColors.fg : c.borderStrong),
              ),
              child: SizedBox(
                width: 16,
                height: 16,
                child: ok ? Icon(SeenIcons.check, size: 10, color: Colors.white) : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: t.caption.copyWith(color: ok ? okColor : (failed ? errorColors.fg : c.inkMuted)),
              ),
            ),
          ],
        );

    Widget toggle() => SeenMotionlessEye(
          obscured: _obscure,
          onTap: () => setState(() => _obscure = !_obscure),
          showLabel: l10n.showPasswordAction,
          hideLabel: l10n.hidePasswordAction,
        );

    return BlocBuilder<PasswordRecoveryBloc, PasswordRecoveryState>(
      builder: (context, state) {
        final issue = state.issue;
        final reused = issue?.kind == RecoveryIssueKind.passwordReused;
        final mismatch = _confirm.text.isNotEmpty && !_matches;
        return _Frame(
          title: l10n.recoveryNewPasswordTitle,
          onBack: widget.onBack,
          actions: [
            SeenButton(
              label: state.busy ? l10n.loading : l10n.recoverySavePassword,
              loading: state.busy,
              expand: true,
              onPressed: (state.busy || !_valid)
                  ? null
                  : () => context.read<PasswordRecoveryBloc>().add(RecoveryPasswordSubmitted(_password.text)),
            ),
          ],
          children: [
            Text(l10n.recoveryNewPasswordHeading, style: t.h1),
            const SizedBox(height: 16),
            SeenTextField(
              label: l10n.recoveryNewPasswordLabel,
              controller: _password,
              obscureText: _obscure,
              suffix: toggle(),
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                setState(() {});
                if (issue != null) context.read<PasswordRecoveryBloc>().add(const RecoveryIssueDismissed());
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
                    rule(l10n.recoveryRuleDigit, _hasDigit),
                    const SizedBox(height: 8),
                    rule(l10n.recoveryRuleNotReused, false, failed: reused),
                  ],
                ),
              ),
            ),
            if (reused) ...[
              const SizedBox(height: 16),
              SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.recoveryPasswordReused),
            ],
            if (issue?.kind == RecoveryIssueKind.weakPassword) ...[
              const SizedBox(height: 16),
              SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.recoveryPasswordWeak),
            ],
            if (issue?.kind == RecoveryIssueKind.offline) ...[
              const SizedBox(height: 16),
              SeenInlineBanner(tone: SeenBannerTone.offline, message: l10n.recoveryOffline),
            ],
            if (issue?.kind == RecoveryIssueKind.generic || issue?.kind == RecoveryIssueKind.expiredCode) ...[
              const SizedBox(height: 16),
              SeenInlineBanner(tone: SeenBannerTone.error, message: l10n.recoveryServerError),
            ],
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

class _DoneScreen extends StatelessWidget {
  const _DoneScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final done = SeenRequestStatus.completed.colors;
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
                      Text(l10n.recoveryDoneTitle, textAlign: TextAlign.center, style: t.h1),
                      const SizedBox(height: 12),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 310),
                        child: Text(
                          l10n.recoveryDoneBody,
                          textAlign: TextAlign.center,
                          style: t.body.copyWith(color: c.inkSecondary),
                        ),
                      ),
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
