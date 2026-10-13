import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_motion_icons.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
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

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
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
    return Scaffold(
      backgroundColor: c.card,
      body: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) => current is AuthFailure && current.stage == AuthFailureStage.login,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text((state as AuthFailure).message)));
        },
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
                            suffix: SeenMotionIcon(
                              asset: SeenMotionIcons.passwordVisibility,
                              fallbackIcon: _obscurePassword ? SeenIcons.eye : SeenIcons.eyeSlash,
                              // Two-state toggle, not a one-shot: true =
                              // password visible (eye open).
                              value: !_obscurePassword,
                              size: 16,
                              color: c.inkMuted,
                              semanticLabel: _obscurePassword ? l10n.showPasswordAction : l10n.hidePasswordAction,
                              onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
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
                          // Figma: a 90 px spacer between two 20 px gaps.
                          const SizedBox(height: 130),
                          BlocBuilder<AuthBloc, AuthState>(
                            buildWhen: (previous, current) => previous is AuthLoading || current is AuthLoading,
                            builder: (context, state) {
                              final isLoading = state is AuthLoading;
                              return SeenButton(
                                label: isLoading ? l10n.loading : l10n.loginAction,
                                size: SeenButtonSize.large,
                                expand: true,
                                loading: isLoading,
                                onPressed: _submit,
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
                          // DEBUG ONLY: `kDebugMode` is a compile-time
                          // constant, so this whole block (and the
                          // string, deliberately not put through ARB —
                          // it's a developer tool, not user-facing copy)
                          // is dead-code-eliminated from release builds.
                          if (kDebugMode) ...[
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
