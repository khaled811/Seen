// Change password (Figma AUTH-15): the current password, a new one with the same rules
// as recovery, and a confirmation. Per-field marks: the current password is flagged when
// the server refuses it, the new ones show a check when valid.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../domain/entities/account_security.dart';
import '../bloc/account_security_cubits.dart';
import '../widgets/account_security_strings.dart';
import 'forgot_password_flow.dart' show SeenMotionlessEye;

class ChangePasswordScreen extends StatelessWidget {
  const ChangePasswordScreen({super.key, this.createCubit});

  /// Test seam; defaults to the DI container.
  final ChangePasswordCubit Function()? createCubit;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const ChangePasswordScreen());

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createCubit ?? InjectionContainer.instance.createChangePasswordCubit)(),
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
  // Owned here, disposed in dispose().
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _rulesOk {
    final p = _new.text;
    return p.length >= 8 && RegExp('[a-z]').hasMatch(p) && RegExp('[A-Z]').hasMatch(p) && RegExp('[0-9]').hasMatch(p);
  }

  bool get _matches => _confirm.text.isNotEmpty && _confirm.text == _new.text;
  bool get _canSave => _current.text.isNotEmpty && _rulesOk && _matches;

  void _edited() {
    setState(() {});
    context.read<ChangePasswordCubit>().edited();
  }

  void _save() {
    context.read<ChangePasswordCubit>().submit(current: _current.text, next: _new.text);
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final l10n = AppLocalizations.of(context)!;
    return BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
      listenWhen: (p, c) => !p.done && c.done,
      listener: (context, state) {
        // Changed: clear the fields so the password does not linger on screen.
        _current.clear();
        _new.clear();
        _confirm.clear();
        setState(() {});
      },
      builder: (context, state) {
        final issue = state.issue?.kind;
        final wrongCurrent = issue == AccountIssueKind.wrongCurrentPassword;
        Widget eye() => SeenMotionlessEye(
              obscured: _obscure,
              onTap: () => setState(() => _obscure = !_obscure),
              showLabel: l10n.showPasswordAction,
              hideLabel: l10n.hidePasswordAction,
            );
        final banner = switch (issue) {
          AccountIssueKind.passwordReused => SeenInlineBanner(tone: SeenBannerTone.error, message: s.passwordReusedBanner),
          AccountIssueKind.weakPassword => SeenInlineBanner(tone: SeenBannerTone.error, message: s.passwordWeakBanner),
          AccountIssueKind.offline => SeenInlineBanner(tone: SeenBannerTone.offline, message: s.accountOffline),
          AccountIssueKind.wrongCurrentPassword || null => null,
          _ => SeenInlineBanner(tone: SeenBannerTone.error, message: s.accountGeneric),
        };
        return Scaffold(
          backgroundColor: SeenColors.of(context).card,
          body: SeenScreenBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SeenScreenHeader(title: s.changePasswordTitle),
                  Expanded(
                    child: ListView(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      children: [
                        SeenTextField(
                          label: s.currentPasswordLabel,
                          controller: _current,
                          obscureText: _obscure,
                          suffix: eye(),
                          showError: wrongCurrent,
                          errorText: wrongCurrent ? s.wrongCurrentPassword : null,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _edited(),
                        ),
                        const SizedBox(height: 14),
                        SeenTextField(
                          label: s.newPasswordLabel,
                          controller: _new,
                          obscureText: _obscure,
                          suffix: eye(),
                          success: _rulesOk,
                          helper: _rulesOk ? null : s.passwordRulesHelper,
                          autofillHints: const [AutofillHints.newPassword],
                          textInputAction: TextInputAction.next,
                          onChanged: (_) => _edited(),
                        ),
                        const SizedBox(height: 14),
                        SeenTextField(
                          label: s.confirmPasswordLabel,
                          controller: _confirm,
                          obscureText: _obscure,
                          suffix: eye(),
                          success: _matches,
                          errorText: _confirm.text.isNotEmpty && !_matches ? s.passwordsDoNotMatch : null,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => _edited(),
                          onSubmitted: (_) {
                            if (_canSave) {
                              _save();
                            }
                          },
                        ),
                        if (banner != null) ...[const SizedBox(height: 14), banner],
                        if (state.done) ...[
                          const SizedBox(height: 14),
                          SeenInlineBanner(tone: SeenBannerTone.ok, message: s.passwordChanged),
                        ],
                      ],
                    ),
                  ),
                  SeenActionBar(
                    actions: [
                      SeenButton(
                        label: s.savePassword,
                        expand: true,
                        loading: state.busy,
                        onPressed: state.busy || !_canSave ? null : _save,
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
