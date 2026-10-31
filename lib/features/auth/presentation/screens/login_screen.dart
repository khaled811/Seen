import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/config/debug_fallbacks.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/foundation/seen_motion_icons.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/motion_icon.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/utils/latin_digits.dart';
import '../../../../core/validators/form_validators.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../../../support/presentation/widgets/contact_support_sheet.dart';
import '../bloc/auth_state.dart';
import '../utils/phone_identifier.dart';

/// Screen 03 · Login (Figma 4:248): phone number + password.
///
/// The phone field is mapped onto the existing `identifier` of
/// [AuthLoginSubmitted] by [PhoneIdentifier.toIdentifier], so the auth
/// contract is unchanged. [onBack] shows the back button (when reached from
/// Welcome); [onForgotPassword] / [onCreateAccount] default to a "coming
/// soon" notice until those flows exist.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.onBack, this.onForgotPassword, this.onCreateAccount});

  final VoidCallback? onBack;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onCreateAccount;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  /// The last login failure that has its own display (Figma AUTH-11); null when
  /// there is none, or once the agent starts correcting the form.
  AuthFailure? _failure;

  // Owned here, cancelled in dispose(): counts the lock-out down once a second.
  Timer? _lockTimer;
  int _lockSeconds = 0;

  bool get _locked => _failure?.reason == LoginFailureReason.locked && _lockSeconds > 0;

  void _onFailure(AuthFailure failure) {
    _lockTimer?.cancel();
    if (failure.reason == LoginFailureReason.generic) {
      setState(() => _failure = null);
      final l10n = AppLocalizations.of(context)!;
      final cause = failure.cause;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(cause == null ? failure.message : localizedFailureMessage(l10n, cause))));
      return;
    }
    setState(() {
      _failure = failure;
      _lockSeconds = failure.reason == LoginFailureReason.locked ? (failure.retryAfterSeconds ?? 0) : 0;
    });
    if (_lockSeconds > 0) {
      _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return timer.cancel();
        setState(() => _lockSeconds -= 1);
        if (_lockSeconds <= 0) {
          timer.cancel();
          setState(() => _failure = null);
        }
      });
    }
  }

  /// Typing again clears "wrong phone or password" (the other states are the
  /// account's, not the fields').
  void _fieldEdited() {
    if (_failure?.reason == LoginFailureReason.invalidCredentials) setState(() => _failure = null);
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (_locked) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthBloc>().add(
          AuthLoginSubmitted(
            identifier: PhoneIdentifier.toLoginIdentifier(_phoneController.text),
            password: _passwordController.text,
          ),
        );
  }

  void _comingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.comingSoon)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final s = SeenStrings.of(context);
    final failure = _failure;
    final badCredentials = failure?.reason == LoginFailureReason.invalidCredentials;
    return Scaffold(
      backgroundColor: c.card,
      body: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) => current is AuthFailure && current.stage == AuthFailureStage.login,
        listener: (context, state) => _onFailure(state as AuthFailure),
        child: SeenScreenBackground(
          child: SafeArea(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    // Figma 4:248: the body starts 72 px from the screen top.
                    padding:
                        EdgeInsets.fromLTRB(20, (72 - MediaQuery.paddingOf(context).top).clamp(16.0, 72.0), 20, 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.onBack != null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: SeenRoundIconButton(
                                icon: SeenIcons.back(context),
                                // The back icon of Figma 03 · Login (it points right in RTL, so it is
                                // mirrored in LTR).
                                glyph: const SeenBackGlyph(),
                                semanticLabel: MaterialLocalizations.of(context).backButtonTooltip,
                                tonal: true,
                                onPressed: widget.onBack,
                              ),
                            ),
                          const SizedBox(height: SeenSpace.s5),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: Semantics(
                              label: l10n.appTitle,
                              image: true,
                              child: SvgPicture.asset(SeenVectors.logoPrimary, width: 96, excludeFromSemantics: true),
                            ),
                          ),
                          const SizedBox(height: SeenSpace.s5),
                          Text(l10n.loginTitle, style: type.h1),
                          const SizedBox(height: SeenSpace.s1),
                          Text(l10n.loginSubtitle, style: type.body.copyWith(color: c.inkMuted)),
                          const SizedBox(height: SeenSpace.s5),
                          // Email or phone. With letters / "@" it is an email and the
                          // phone prefix and digit handling step aside.
                          ListenableBuilder(
                            listenable: _phoneController,
                            builder: (context, _) {
                              final isEmail = PhoneIdentifier.looksLikeEmail(_phoneController.text);
                              return SeenTextField(
                                label: l10n.loginPhoneLabel,
                                helper: l10n.loginPhoneHelper,
                                controller: _phoneController,
                                ltr: true,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username, AutofillHints.telephoneNumber],
                                // Latin digits only, even from an Arabic keyboard.
                                inputFormatters: const [LatinDigitsFormatter()],
                                showError: badCredentials,
                                onChanged: (_) => _fieldEdited(),
                                // Country context for phone numbers. Fixed default: Figma has no picker.
                                prefix: isEmail
                                    ? null
                                    : Padding(
                                        padding: const EdgeInsetsDirectional.only(end: SeenSpace.s2),
                                        child: Directionality(
                                          textDirection: TextDirection.ltr,
                                          child: Text(
                                            PhoneIdentifier.defaultCountryCode,
                                            style: type.bodyStrong.copyWith(color: c.ink),
                                          ),
                                        ),
                                      ),
                                validator: (value) =>
                                    FormValidators.required(value, message: l10n.validationRequired) ??
                                    (PhoneIdentifier.isValidIdentifier(value ?? '')
                                        ? null
                                        : (PhoneIdentifier.looksLikeEmail(value ?? '')
                                            ? l10n.validationInvalidEmail
                                            : l10n.validationInvalidPhone)),
                              );
                            },
                          ),
                          const SizedBox(height: SeenSpace.s5),
                          SeenTextField(
                            label: l10n.loginPasswordLabel,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            // The field gives its suffix a 48 px box: the eye is centred in it at its own
                            // size (a bare small box would be stretched to 48), light grey, with the whole
                            // box as the tap target.
                            suffix: Semantics(
                              button: true,
                              label: _obscurePassword ? l10n.showPasswordAction : l10n.hidePasswordAction,
                              excludeSemantics: true,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                                child: SizedBox(
                                  width: 44,
                                  height: 44,
                                  child: Center(
                                    child: SeenMotionIcon(
                                      asset: SeenMotionIcons.passwordVisibility,
                                      fallbackIcon: _obscurePassword ? SeenIcons.eye : SeenIcons.eyeSlash,
                                      // Two-state toggle: true = password visible (eye open).
                                      value: !_obscurePassword,
                                      size: 26,
                                      color: SeenBrand.tabIconInactive,
                                      tintAnimation: true,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            showError: badCredentials,
                            errorText: badCredentials
                                ? (failure?.attemptsLeft == null
                                    ? l10n.loginInvalidCredentials
                                    : '${l10n.loginInvalidCredentials} ${s.attemptsLeft(failure!.attemptsLeft!)}.')
                                : null,
                            onChanged: (_) => _fieldEdited(),
                            validator: (value) => FormValidators.required(value, message: l10n.validationRequired),
                          ),
                          const SizedBox(height: SeenSpace.s5),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: SeenTextLink(
                              label: l10n.loginForgotPassword,
                              onTap: widget.onForgotPassword ?? _comingSoon,
                            ),
                          ),
                          if (failure != null) ...[
                            const SizedBox(height: SeenSpace.s4),
                            switch (failure.reason) {
                              LoginFailureReason.pendingApproval => SeenInlineBanner(
                                  tone: SeenBannerTone.warn,
                                  message: l10n.loginAccountPending,
                                  actionLabel: l10n.loginBannerSupport,
                                  onAction: () => showContactSupportSheet(context),
                                ),
                              LoginFailureReason.suspended => SeenInlineBanner(
                                  tone: SeenBannerTone.error,
                                  message: l10n.loginAccountSuspended,
                                  actionLabel: l10n.loginBannerContact,
                                  onAction: () => showContactSupportSheet(context),
                                ),
                              LoginFailureReason.locked => SeenInlineBanner(
                                  tone: SeenBannerTone.error,
                                  message: l10n.loginLocked(s.clockMs(_lockSeconds)),
                                ),
                              LoginFailureReason.emailRequired => SeenInlineBanner(
                                  tone: SeenBannerTone.warn,
                                  message: l10n.loginEmailRequired,
                                ),
                              LoginFailureReason.enrollmentLinkRequired => SeenInlineBanner(
                                  tone: SeenBannerTone.warn,
                                  message: l10n.loginEnrollmentLinkRequired,
                                  actionLabel: l10n.loginBannerSupport,
                                  onAction: () => showContactSupportSheet(context),
                                ),
                              LoginFailureReason.verificationExpired => SeenInlineBanner(
                                  tone: SeenBannerTone.warn,
                                  message: l10n.loginVerificationExpired,
                                ),
                              _ => const SizedBox.shrink(),
                            },
                          ],
                          // Figma: a 90 px spacer between two 20 px gaps.
                          SizedBox(height: failure == null || badCredentials ? 130 : 60),
                          BlocBuilder<AuthBloc, AuthState>(
                            buildWhen: (previous, current) => previous is AuthLoading || current is AuthLoading,
                            builder: (context, state) {
                              final isLoading = state is AuthLoading;
                              return SeenButton(
                                label: isLoading ? l10n.loading : l10n.loginAction,
                                size: SeenButtonSize.large,
                                expand: true,
                                loading: isLoading,
                                onPressed: _locked ? null : _submit,
                              );
                            },
                          ),
                          const SizedBox(height: SeenSpace.s5),
                          Wrap(
                            alignment: WrapAlignment.center,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(l10n.loginNoAccount, style: type.body.copyWith(color: c.inkMuted)),
                              SeenTextLink(
                                label: l10n.loginCreateAgency,
                                onTap: widget.onCreateAccount ?? _comingSoon,
                              ),
                            ],
                          ),
                          // DEBUG ONLY and opt-in: shown just in a debug build
                          // started with USE_DEBUG_FALLBACKS=true (the fake
                          // session only works with fake data, so it must not
                          // be one tap away when pointed at a real server). The
                          // string is deliberately not in ARB: a developer
                          // tool, not user-facing copy.
                          if (debugFallbacksEnabled) ...[
                            const SizedBox(height: SeenSpace.s4),
                            Divider(color: c.border),
                            const SizedBox(height: SeenSpace.s2),
                            SeenButton.ghost(
                              label: 'تخطي / الدخول التجريبي (Bypass Auth)',
                              expand: true,
                              onPressed: () => context.read<AuthBloc>().add(const AuthDebugBypassRequested()),
                            ),
                          ],
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
