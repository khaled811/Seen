import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_images.dart';
import '../../../../core/presentation/foundation/seen_motion_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/motion_icon.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/validators/form_validators.dart';
import '../bloc/auth_bloc.dart';
import '../bloc/auth_event.dart';
import '../bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<AuthBloc>().add(
          AuthLoginSubmitted(
            identifier: _identifierController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return Scaffold(
      backgroundColor: c.surface,
      body: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            current is AuthFailure && current.stage == AuthFailureStage.login,
        listener: (context, state) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text((state as AuthFailure).message)));
        },
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _LoginHero(),
                Padding(
                  padding: const EdgeInsets.all(SeenSpace.s6),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SeenTextField(
                              label: l10n.loginIdentifierLabel,
                              isRequired: true,
                              controller: _identifierController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username],
                              validator: (value) =>
                                  FormValidators.required(value, message: l10n.validationRequired),
                            ),
                            const SizedBox(height: SeenSpace.s4),
                            SeenTextField(
                              label: l10n.loginPasswordLabel,
                              isRequired: true,
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              textInputAction: TextInputAction.done,
                              suffix: SeenMotionIcon(
                                asset: SeenMotionIcons.passwordVisibility,
                                fallbackIcon: _obscurePassword ? SeenIcons.eye : SeenIcons.eyeSlash,
                                // Two-state toggle, not a one-shot: true =
                                // password visible (eye open). If the
                                // asset's frames turn out reversed on
                                // screen, flip this to `_obscurePassword`.
                                value: !_obscurePassword,
                                size: 16,
                                color: c.inkMuted,
                                semanticLabel:
                                    _obscurePassword ? l10n.showPasswordAction : l10n.hidePasswordAction,
                                onTap: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              validator: (value) =>
                                  FormValidators.required(value, message: l10n.validationRequired),
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
                                  onPressed: isLoading ? null : _submit,
                                );
                              },
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
                                onPressed: () =>
                                    context.read<AuthBloc>().add(const AuthDebugBypassRequested()),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Branded banner above the sign-in form: navy, the flight pattern faint in
/// the background, an initial tile + app name + "Sign In".
class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: c.primary,
        borderRadius: const BorderRadius.only(bottomLeft: SeenRadius.lg, bottomRight: SeenRadius.lg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: 0.32,
            child: Image.asset(SeenImages.flightPattern, fit: BoxFit.cover, alignment: Alignment.topRight),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.card, borderRadius: const BorderRadius.all(SeenRadius.md)),
                  child: Text(
                    l10n.appTitle.isEmpty ? '' : l10n.appTitle.characters.first,
                    style: seenStyle(24, 24, FontWeight.w700, c.primaryInk),
                  ),
                ),
                const SizedBox(height: SeenSpace.s3),
                Text(l10n.appTitle, style: text.headlineSmall?.copyWith(color: c.onPrimary)),
                const SizedBox(height: 2),
                Text(l10n.loginTitle, style: text.bodyMedium?.copyWith(color: c.onPrimaryMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
