import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/feedback.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

const int _otpLength = 6;

/// [resendCooldownSeconds] seeds the local countdown; a fresh value from a
/// new [AuthOtpRequired] state (after a resend) restarts it.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, required this.resendCooldownSeconds});

  final int resendCooldownSeconds;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  bool _hasError = false;

  // Owned here: started in initState/didUpdateWidget, cancelled in dispose.
  Timer? _countdownTimer;
  late int _secondsRemaining;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.resendCooldownSeconds;
    _startCountdown();
    _codeController.addListener(_clearError);
  }

  @override
  void didUpdateWidget(covariant OtpVerificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    super.dispose();
  }

  void _submit([String? code]) {
    final value = code ?? _codeController.text.trim();
    if (value.length != _otpLength) return;
    context.read<AuthBloc>().add(AuthOtpSubmitted(code: value));
  }

  void _resend() {
    context.read<AuthBloc>().add(const AuthOtpResendRequested());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: c.surface,
      body: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            current is AuthFailure && current.stage == AuthFailureStage.otp,
        listener: (context, state) {
          setState(() => _hasError = true);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text((state as AuthFailure).message)));
        },
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SeenSpace.s6),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.otpTitle, style: text.headlineSmall, textAlign: TextAlign.center),
                    const SizedBox(height: SeenSpace.s3),
                    Text(l10n.otpInstructions, style: text.bodyMedium, textAlign: TextAlign.center),
                    const SizedBox(height: SeenSpace.s6),
                    SeenOtpInput(
                      length: _otpLength,
                      controller: _codeController,
                      error: _hasError,
                      onCompleted: _submit,
                    ),
                    const SizedBox(height: SeenSpace.s6),
                    BlocBuilder<AuthBloc, AuthState>(
                      buildWhen: (previous, current) =>
                          previous is AuthLoading || current is AuthLoading,
                      builder: (context, state) {
                        final isLoading = state is AuthLoading;
                        return SeenButton(
                          label: isLoading ? l10n.loading : l10n.submit,
                          expand: true,
                          onPressed: isLoading ? null : () => _submit(),
                        );
                      },
                    ),
                    const SizedBox(height: SeenSpace.s3),
                    SeenButton.ghost(
                      label: _secondsRemaining > 0
                          ? l10n.otpResendIn(_secondsRemaining)
                          : l10n.otpResendAction,
                      expand: true,
                      onPressed: _secondsRemaining > 0 ? null : _resend,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
