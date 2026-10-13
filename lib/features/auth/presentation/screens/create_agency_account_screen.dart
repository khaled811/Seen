import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/dropzone.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/validators/form_validators.dart';
import '../utils/phone_identifier.dart';

/// Figma 15 — create agency account. The backend exposes no self-registration
/// mutation yet, so a valid form is not sent anywhere: [onSubmitted] just moves
/// the flow to the pending-approval screen. Nothing is stored or faked.
class CreateAgencyAccountScreen extends StatefulWidget {
  const CreateAgencyAccountScreen({super.key, required this.onBack, required this.onSubmitted});

  final VoidCallback onBack;
  final VoidCallback onSubmitted;

  @override
  State<CreateAgencyAccountScreen> createState() => _CreateAgencyAccountScreenState();
}

class _CreateAgencyAccountScreenState extends State<CreateAgencyAccountScreen> {
  // Owned here, disposed in dispose().
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cr = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _cr.dispose();
    _city.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmitted();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    String? required(String? v) => FormValidators.required(v, message: l10n.validationRequired);
    return Scaffold(
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SeenScreenHeader(
                title: l10n.agencyCreateTitle,
                subtitle: l10n.agencyCreateSubtitle,
                onBack: widget.onBack,
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, SeenSpace.s2, 20, 24),
                    children: [
                      SeenTextField(
                        label: l10n.agencyNameLabel,
                        isRequired: true,
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        validator: required,
                      ),
                      const SizedBox(height: SeenSpace.s4),
                      SeenTextField(
                        label: l10n.agencyCrLabel,
                        isRequired: true,
                        controller: _cr,
                        mono: true,
                        ltr: true,
                        textInputAction: TextInputAction.next,
                        validator: required,
                      ),
                      const SizedBox(height: SeenSpace.s4),
                      SeenTextField(
                        label: l10n.agencyCityLabel,
                        isRequired: true,
                        controller: _city,
                        textInputAction: TextInputAction.next,
                        validator: required,
                      ),
                      const SizedBox(height: SeenSpace.s4),
                      SeenTextField(
                        label: l10n.agencyPhoneLabel,
                        isRequired: true,
                        controller: _phone,
                        mono: true,
                        ltr: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (v) => PhoneIdentifier.isValid(v ?? '') ? null : l10n.validationInvalidPhone,
                      ),
                      const SizedBox(height: SeenSpace.s4),
                      SeenTextField(
                        label: l10n.agencyEmailLabel,
                        isRequired: true,
                        controller: _email,
                        ltr: true,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final value = v ?? '';
                          return value.contains('@') && PhoneIdentifier.isValidIdentifier(value)
                              ? null
                              : l10n.validationInvalidEmail;
                        },
                      ),
                      const SizedBox(height: SeenSpace.s5),
                      // No picker or upload API yet: say so, never fake an attachment.
                      SeenDropzone(
                        title: l10n.agencyCrUploadTitle,
                        caption: l10n.agencyCrUploadCaption,
                        onTap: () => ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(SnackBar(content: Text(l10n.agencyCrUploadCaption))),
                      ),
                    ],
                  ),
                ),
              ),
              SeenActionBar(actions: [SeenButton(label: l10n.agencySubmitAction, expand: true, onPressed: _submit)]),
            ],
          ),
        ),
      ),
    );
  }
}
