import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/feedback.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/status.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';
import '../utils/phone_identifier.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';

const int _otpLength = 6;

/// A recovery code looks like `xxxx-xxxx-xxxx`; the server is the judge, this
/// only avoids sending an empty or obviously short value.
const int _recoveryMinLength = 12;

/// Screen 04 · OTP verification (Figma 4:295).
///
/// [resendCooldownSeconds] seeds the local countdown; a fresh value from a
/// new [AuthOtpRequired] state (after a resend) restarts it. [identifier] is
/// the phone/email the code went to (shown masked); once known it is kept
/// across rebuilds that do not carry it (e.g. after a failed attempt).
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.resendCooldownSeconds,
    this.identifier,
    this.canResend = true,
  });

  final int resendCooldownSeconds;
  final String? identifier;

  /// False when the code comes from the person's authenticator app: there is
  /// nothing to resend, so the resend row gives way to "use a recovery code".
  final bool canResend;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  // Owned here, disposed in dispose(): the single-use recovery code (xxxx-xxxx-xxxx).
  final _recoveryController = TextEditingController();
  bool _recoveryMode = false;
  bool _hasError = false;

  // Owned here: started in initState/didUpdateWidget, cancelled in dispose.
  Timer? _countdownTimer;
  late int _secondsRemaining;
  String? _identifier;

  @override
  void initState() {
    super.initState();
    _identifier = widget.identifier;
    _secondsRemaining = widget.resendCooldownSeconds;
    _startCountdown();
    _codeController.addListener(_clearError);
    _recoveryController.addListener(_clearError);
  }

  @override
  void didUpdateWidget(covariant OtpVerificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.identifier != null) _identifier = widget.identifier;
    if (oldWidget.resendCooldownSeconds != widget.resendCooldownSeconds) {
      setState(() => _secondsRemaining = widget.resendCooldownSeconds);
      _startCountdown();
    }
  }

  void _clearError() {
    if (_hasError) setState(() => _hasError = false);
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _secondsRemaining <= 0) {
        timer.cancel();
        return;
      }
      setState(() => _secondsRemaining--);
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.removeListener(_clearError);
    _codeController.dispose();
    _recoveryController.removeListener(_clearError);
    _recoveryController.dispose();
    super.dispose();
  }

  void _submit([String? code]) {
    if (_recoveryMode) {
      final recovery = _recoveryController.text.trim();
      if (recovery.length < _recoveryMinLength) return;
      context.read<AuthBloc>().add(AuthOtpSubmitted(code: recovery));
      return;
    }
    final value = code ?? _codeController.text.trim();
    if (value.length != _otpLength) return;
    context.read<AuthBloc>().add(AuthOtpSubmitted(code: value));
  }

  void _toggleRecovery() => setState(() {
        _recoveryMode = !_recoveryMode;
        _hasError = false;
      });

  void _back() => context.read<AuthBloc>().add(const AuthOtpCancelled());

  void _resend() {
    context.read<AuthBloc>().add(const AuthOtpResendRequested());
  }

  /// Localized text for a failed verification (never the server's message).
  String _failureText(AppLocalizations l10n, AuthFailure failure) {
    final cause = failure.cause;
    return cause == null ? l10n.error : localizedFailureMessage(l10n, cause);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final identifier = _identifier;
    return PopScope(
      canPop: false, // system back = same as the on-screen back button
      onPopInvoked: (didPop) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: c.card,
        body: BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) => current is AuthFailure && current.stage == AuthFailureStage.otp,
          listener: (context, state) {
            setState(() => _hasError = true);
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(_failureText(l10n, state as AuthFailure))));
          },
          child: SeenScreenBackground(
            child: SafeArea(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      // Figma 4:295: the body starts 72 px from the screen top.
                      padding:
                          EdgeInsets.fromLTRB(20, (72 - MediaQuery.paddingOf(context).top).clamp(16.0, 72.0), 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: SeenRoundIconButton(
                              icon: SeenIcons.back(context),
                              glyph: const SeenBackGlyph(),
                              semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
                              tonal: true,
                              onPressed: _back,
                            ),
                          ),
                          const SizedBox(height: 22),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: ExcludeSemantics(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: c.primarySoft,
                                  borderRadius: const BorderRadius.all(SeenRadius.r20),
                                ),
                                child: SizedBox(
                                  width: 64,
                                  height: 64,
                                  child: Center(child: SvgPicture.asset(SeenVectors.iconChat, width: 36, height: 36)),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(l10n.otpTitle, style: type.h1),
                          const SizedBox(height: SeenSpace.s1),
                          Text(
                            !widget.canResend
                                ? l10n.otpAuthenticatorInstructions
                                : identifier == null
                                    ? l10n.otpInstructions
                                    : l10n.otpSentTo(PhoneIdentifier.mask(identifier)),
                            style: type.body.copyWith(color: c.inkMuted),
                          ),
                          const SizedBox(height: 22),
                          if (_recoveryMode)
                            SeenTextField(
                              label: l10n.otpRecoveryCodeLabel,
                              controller: _recoveryController,
                              ltr: true,
                              showError: _hasError,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                            )
                          else
                            SeenOtpInput(
                              length: _otpLength,
                              controller: _codeController,
                              error: _hasError,
                              onCompleted: _submit,
                            ),
                          const SizedBox(height: 22),
                          if (widget.canResend)
                            _ResendRow(secondsRemaining: _secondsRemaining, onResend: _resend)
                          else
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: SeenTextLink(
                                label: _recoveryMode ? l10n.otpUseAuthenticatorCode : l10n.otpUseRecoveryCode,
                                onTap: _toggleRecovery,
                              ),
                            ),
                          // Figma: a 160 px spacer between two 22 px gaps.
                          const SizedBox(height: 204),
                          BlocBuilder<AuthBloc, AuthState>(
                            buildWhen: (previous, current) => previous is AuthLoading || current is AuthLoading,
                            builder: (context, state) {
                              final isLoading = state is AuthLoading;
                              return SeenButton(
                                label: isLoading ? l10n.loading : l10n.otpConfirm,
                                size: SeenButtonSize.large,
                                expand: true,
                                loading: isLoading,
                                onPressed: () => _submit(),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Didn't get the code? Resend in [0:42]" while counting down; the resend
/// link once the cooldown ends.
class _ResendRow extends StatelessWidget {
  const _ResendRow({required this.secondsRemaining, required this.onResend});

  final int secondsRemaining;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final waiting = secondsRemaining > 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            waiting ? l10n.otpResendPrompt : l10n.otpDidntReceive,
            style: type.label.copyWith(color: c.inkMuted),
          ),
        ),
        if (waiting)
          SeenCountdownPill(
            label: '${secondsRemaining ~/ 60}:${(secondsRemaining % 60).toString().padLeft(2, '0')}',
            ltrLabel: true,
            semanticLabel: l10n.otpResendIn(secondsRemaining),
          )
        else
          SeenTextLink(label: l10n.otpResendAction, onTap: onResend),
      ],
    );
  }
}
