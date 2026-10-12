import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/validators/form_validators.dart';

/// Collects a required reject reason. [SeenApprovalCard.onReject] is a bare
/// `VoidCallback?` (the card itself doesn't collect one — see its own doc
/// comment), so callers run this first and only dispatch the reject event
/// once a non-empty reason comes back.
Future<String?> showRejectReasonSheet(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final formKey = GlobalKey<FormState>();
  final reasonController = TextEditingController();
  final reason = await showSeenSheet<String>(
    context: context,
    title: l10n.subAgentRejectDialogTitle,
    builder: (_) => Form(
      key: formKey,
      child: SeenTextField(
        label: l10n.subAgentRejectReasonLabel,
        isRequired: true,
        controller: reasonController,
        validator: (value) => FormValidators.required(value, message: l10n.validationRequired),
      ),
    ),
    footerBuilder: (sheetContext) => Row(children: [
      Expanded(
        child: SeenButton.secondary(
          label: l10n.no,
          expand: true,
          onPressed: () => Navigator.of(sheetContext).pop(),
        ),
      ),
      const SizedBox(width: SeenSpace.s3),
      Expanded(
        child: SeenButton.dangerOutline(
          label: l10n.subAgentRejectAction,
          expand: true,
          onPressed: () {
            if (formKey.currentState?.validate() ?? false) {
              Navigator.of(sheetContext).pop(reasonController.text.trim());
            }
          },
        ),
      ),
    ]),
  );
  reasonController.dispose();
  return reason;
}
