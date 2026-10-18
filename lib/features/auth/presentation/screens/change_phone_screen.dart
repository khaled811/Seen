// Change mobile number (Figma AUTH-16): the current number (masked, read-only), the new
// one, and the code the server sends to it. "Confirm number" first sends the code, then
// checks it. Changing the number after a code went out starts again.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/feedback.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_format.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/utils/latin_digits.dart';
import '../../domain/entities/account_security.dart';
import '../bloc/account_security_cubits.dart';
import '../utils/phone_identifier.dart';
import '../widgets/account_security_strings.dart';

class ChangePhoneScreen extends StatelessWidget {
  const ChangePhoneScreen({super.key, this.createCubit});

  /// Test seam; defaults to the DI container.
  final ChangePhoneCubit Function()? createCubit;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const ChangePhoneScreen());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createCubit ?? InjectionContainer.instance.createChangePhoneCubit)()..load(),
      child: const _Form(),
    );
  }
}

class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  // Owned here, disposed / cancelled in dispose().
  final _phone = TextEditingController();
  final _currentNumber = TextEditingController();
  final _code = TextEditingController();
  Timer? _timer;
  int _remaining = 0;
  String? _phoneError;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _currentNumber.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _e164 => PhoneIdentifier.toIdentifier(_phone.text);

  /// Counts the resend wait down once per second; replaced when a new code goes out.
  void _startCountdown(int seconds) {
    _timer?.cancel();
    setState(() => _remaining = seconds);
    if (seconds <= 0) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remaining = _remaining - 1);
      if (_remaining <= 0) {
        t.cancel();
      }
    });
  }

  void _primary(ChangePhoneState state) {
    final cubit = context.read<ChangePhoneCubit>();
    if (!state.codeSent) {
      if (!PhoneIdentifier.isValid(_phone.text)) {
        setState(() => _phoneError = SeenStrings.of(context).isArabic ? 'أدخل رقم جوال صحيحًا.' : 'Enter a valid mobile number.');
        return;
      }
      cubit.sendCode(_e164);
    } else if (_code.text.length == 6) {
      cubit.confirm(_code.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return BlocConsumer<ChangePhoneCubit, ChangePhoneState>(
      listenWhen: (p, c) => p.challenge != c.challenge || (!p.done && c.done) || p.currentMasked != c.currentMasked,
      listener: (context, state) {
        if (_currentNumber.text != (state.currentMasked ?? '')) {
          _currentNumber.text = state.currentMasked ?? '';
        }
        if (state.done) {
          _timer?.cancel();
          final messenger = ScaffoldMessenger.of(context);
          Navigator.of(context).pop();
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(s.phoneChanged)));
          return;
        }
        _startCountdown(state.challenge?.resendCooldownSeconds ?? 0);
      },
      builder: (context, state) {
        final issue = state.issue;
        final kind = issue?.kind;
        final wrongCode = kind == AccountIssueKind.wrongCode;
        final banner = switch (kind) {
          null => null,
          AccountIssueKind.phoneTaken => SeenInlineBanner(tone: SeenBannerTone.error, message: s.phoneTakenBanner),
          AccountIssueKind.wrongCode => SeenInlineBanner(tone: SeenBannerTone.error, message: s.phoneCodeWrong(issue!.attemptsLeft ?? 0)),
          AccountIssueKind.expiredCode => SeenInlineBanner(
              tone: SeenBannerTone.warn,
              message: s.phoneCodeExpired,
              actionLabel: s.resendNow,
              onAction: () => context.read<ChangePhoneCubit>().resend(),
            ),
          AccountIssueKind.attemptsExhausted =>
            SeenInlineBanner(tone: SeenBannerTone.error, message: s.phoneCodeLocked(issue!.minutes ?? 15)),
          AccountIssueKind.rateLimited => SeenInlineBanner(tone: SeenBannerTone.warn, message: s.phoneRateLimited(issue!.seconds ?? 0)),
          AccountIssueKind.offline => SeenInlineBanner(tone: SeenBannerTone.offline, message: s.accountOffline),
          _ => SeenInlineBanner(tone: SeenBannerTone.error, message: s.accountGeneric),
        };
        return Scaffold(
          backgroundColor: c.card,
          body: SeenScreenBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SeenScreenHeader(title: s.changePhoneTitle),
                  Expanded(
                    child: ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        if (state.currentMasked != null && state.currentMasked!.isNotEmpty) ...[
                          SeenTextField(
                            label: s.currentNumberLabel,
                            controller: _currentNumber,
                            readOnly: true,
                            ltr: true,
                          ),
                          const SizedBox(height: 14),
                        ],
                        SeenTextField(
                          label: s.newNumberLabel,
                          controller: _phone,
                          ltr: true,
                          keyboardType: TextInputType.phone,
                          inputFormatters: const [LatinDigitsFormatter()],
                          textInputAction: TextInputAction.done,
                          errorText: _phoneError,
                          showError: kind == AccountIssueKind.phoneTaken,
                          prefix: Padding(
                            padding: const EdgeInsetsDirectional.only(end: SeenSpace.s2),
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(PhoneIdentifier.defaultCountryCode, style: t.bodyStrong.copyWith(color: c.ink)),
                            ),
                          ),
                          onChanged: (_) {
                            if (_phoneError != null) {
                              setState(() => _phoneError = null);
                            }
                            _code.clear();
                            context.read<ChangePhoneCubit>().phoneEdited();
                          },
                        ),
                        if (state.codeSent) ...[
                          const SizedBox(height: 14),
                          Text(s.enterNewNumberCode, style: t.label),
                          const SizedBox(height: 10),
                          SeenOtpInput(
                            controller: _code,
                            compact: true,
                            error: wrongCode,
                            onChanged: (_) => context.read<ChangePhoneCubit>().dismissIssue(),
                            onCompleted: (code) => context.read<ChangePhoneCubit>().confirm(code),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: Text(s.resendCodeIn, style: t.label.copyWith(color: c.inkSecondary))),
                              if (_remaining > 0)
                                Text(SeenFormat.isolate(s.clockMs(_remaining)), style: t.label.copyWith(color: c.inkSecondary))
                              else
                                SeenTextLink(label: s.resendNow, onTap: () => context.read<ChangePhoneCubit>().resend()),
                            ],
                          ),
                        ],
                        if (banner != null) ...[const SizedBox(height: 14), banner],
                      ],
                    ),
                  ),
                  SeenActionBar(
                    actions: [
                      SeenButton(
                        label: s.confirmNumber,
                        expand: true,
                        loading: state.busy,
                        onPressed: state.busy ? null : () => _primary(state),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
