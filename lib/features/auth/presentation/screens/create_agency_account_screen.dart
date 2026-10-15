import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/dashed_border.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/validators/form_validators.dart';
import '../../domain/entities/agency_registration.dart';
import '../utils/phone_identifier.dart';

/// Figma 15 (node 20:594) — create agency account, step 1 of 4. A valid form
/// is handed to [onSubmitted] as a draft; the registration flow (password,
/// phone code, terms) sends it. [initial] restores the form when the user comes
/// back from a later step.
class CreateAgencyAccountScreen extends StatefulWidget {
  const CreateAgencyAccountScreen({super.key, required this.onBack, required this.onSubmitted, this.initial});

  final VoidCallback onBack;
  final ValueChanged<AgencyRegistrationDraft> onSubmitted;
  final AgencyRegistrationDraft? initial;

  @override
  State<CreateAgencyAccountScreen> createState() => _CreateAgencyAccountScreenState();
}

class _CreateAgencyAccountScreenState extends State<CreateAgencyAccountScreen> {
  // Owned here, disposed in dispose().
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.agencyName);
  late final _manager = TextEditingController(text: widget.initial?.managerName);
  late final _phone = TextEditingController(text: _initialLocalPhone());
  late final _email = TextEditingController(text: widget.initial?.email);
  late final _license = TextEditingController(text: widget.initial?.licenseNumber);
  late final _city = TextEditingController(text: widget.initial?.city);

  String? _initialLocalPhone() {
    final phone = widget.initial?.phone;
    if (phone == null) return null;
    return phone.startsWith(PhoneIdentifier.defaultCountryCode)
        ? phone.substring(PhoneIdentifier.defaultCountryCode.length)
        : phone;
  }

  @override
  void dispose() {
    _name.dispose();
    _manager.dispose();
    _phone.dispose();
    _email.dispose();
    _license.dispose();
    _city.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    widget.onSubmitted(AgencyRegistrationDraft(
      agencyName: _name.text.trim(),
      managerName: _manager.text.trim(),
      phone: PhoneIdentifier.toIdentifier(_phone.text),
      email: _email.text.trim(),
      city: _city.text.trim(),
      licenseNumber: _license.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    String? required(String? v) => FormValidators.required(v, message: l10n.validationRequired);
    const gap = SizedBox(height: 14);
    return Scaffold(
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SeenScreenHeader(
                title: l10n.agencyCreateTitle,
                subtitle: l10n.registrationStepOf(SeenStrings.of(context).numeral(1), SeenStrings.of(context).numeral(4)),
                onBack: widget.onBack,
              ),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      SeenTextField(
                        label: l10n.agencyNameLabel,
                        isRequired: true,
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        validator: required,
                      ),
                      gap,
                      SeenTextField(
                        label: l10n.agencyContactNameLabel,
                        hint: l10n.agencyContactNameHint,
                        isRequired: true,
                        controller: _manager,
                        textInputAction: TextInputAction.next,
                        validator: required,
                      ),
                      gap,
                      SeenTextField(
                        label: l10n.agencyPhoneLabel,
                        helper: l10n.agencyPhoneHelper,
                        isRequired: true,
                        controller: _phone,
                        ltr: true,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        // Country context; fixed default as on the login screen.
                        prefix: Padding(
                          padding: const EdgeInsetsDirectional.only(end: SeenSpace.s2),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(
                              PhoneIdentifier.defaultCountryCode,
                              style: type.bodyStrong.copyWith(color: c.ink),
                            ),
                          ),
                        ),
                        validator: (v) => PhoneIdentifier.isValid(v ?? '') ? null : l10n.validationInvalidPhone,
                      ),
                      gap,
                      SeenTextField(
                        label: l10n.agencyEmailLabel,
                        hint: 'name@agency.com',
                        isRequired: true,
                        controller: _email,
                        ltr: true,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          final value = v ?? '';
                          return value.contains('@') && PhoneIdentifier.isValidIdentifier(value)
                              ? null
                              : l10n.validationInvalidEmail;
                        },
                      ),
                      gap,
                      // City leads (start edge), license number trails, as drawn.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SeenTextField(
                              label: l10n.agencyCityLabel,
                              hint: l10n.agencyCityHint,
                              isRequired: true,
                              controller: _city,
                              textInputAction: TextInputAction.next,
                              validator: required,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SeenTextField(
                              label: l10n.agencyCrLabel,
                              hint: '—',
                              isRequired: true,
                              controller: _license,
                              mono: true,
                              ltr: true,
                              validator: required,
                            ),
                          ),
                        ],
                      ),
                      gap,
                      // No picker or upload API yet: say so, never fake an attachment.
                      _AttachmentSlot(
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

/// Figma "Dropzone" of screen 15: a dashed violet-05 panel with the text at the
/// start and a white 40 px upload tile at the end.
class _AttachmentSlot extends StatelessWidget {
  const _AttachmentSlot({required this.title, required this.caption, required this.onTap});

  final String title;
  final String caption;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    const radius = BorderRadius.all(SeenRadius.r18);
    return Semantics(
      button: true,
      label: '$title. $caption',
      excludeSemantics: true,
      child: SeenDashedBorder(
        color: SeenBrand.violet60,
        radius: SeenRadius.r18.x,
        child: Material(
          color: SeenBrand.violet05,
          borderRadius: radius,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(SeenRadius.r12),
                      boxShadow: SeenShadows.card,
                    ),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Center(child: SeenSvgIcon(SeenVectors.authUpload, size: 22)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: type.bodyStrong),
                        const SizedBox(height: 2),
                        Text(caption, style: type.caption.copyWith(color: c.inkMuted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
