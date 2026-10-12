import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/filters.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/validators/form_validators.dart';
import '../bloc/support_bloc.dart';
import '../bloc/support_event.dart';
import '../bloc/support_state.dart';
import '../widgets/ticket_category_label.dart';

const _categories = [TicketCategory.general, TicketCategory.financialCorrection];

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen({super.key});

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  final _requestReferenceController = TextEditingController();
  TicketCategory _category = TicketCategory.general;

  @override
  void dispose() {
    _subjectController.dispose();
    _messageController.dispose();
    _requestReferenceController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    context.read<SupportBloc>().add(
          SupportTicketCreateSubmitted(
            category: _category,
            subject: _subjectController.text.trim(),
            message: _messageController.text.trim(),
            requestId: _requestReferenceController.text.trim().isEmpty
                ? null
                : _requestReferenceController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final text = Theme.of(context).textTheme;
    return BlocListener<SupportBloc, SupportState>(
      listenWhen: (previous, current) =>
          current is SupportLoaded && current.createStatus == CreateTicketStatus.failure,
      listener: (context, state) {
        final message = (state as SupportLoaded).createError ?? l10n.error;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      child: Scaffold(
        appBar: SeenTopBar.inner(title: l10n.createTicketTitle),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(SeenSpace.s4),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.ticketCategoryFieldLabel, style: text.bodyMedium),
                  const SizedBox(height: SeenSpace.s2),
                  SeenSegmentChips(
                    items: [
                      for (final category in _categories) SeenSegment(label: TicketCategoryLabel.label(l10n, category)),
                    ],
                    selectedIndex: _categories.indexOf(_category),
                    onSelected: (i) => setState(() => _category = _categories[i]),
                  ),
                  const SizedBox(height: SeenSpace.s4),
                  SeenTextField(
                    label: l10n.ticketSubjectFieldLabel,
                    isRequired: true,
                    controller: _subjectController,
                    validator: (value) => FormValidators.required(value, message: l10n.validationRequired),
                  ),
                  const SizedBox(height: SeenSpace.s4),
                  Text(l10n.ticketMessageFieldLabel, style: text.bodyMedium),
                  const SizedBox(height: SeenSpace.s2),
                  // Plain multi-line field — SeenTextField is a fixed
                  // single-line 52px control with no multiline variant.
                  TextFormField(
                    controller: _messageController,
                    maxLines: 5,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    validator: (value) => FormValidators.required(value, message: l10n.validationRequired),
                  ),
                  const SizedBox(height: SeenSpace.s4),
                  SeenTextField(
                    label: l10n.ticketRequestReferenceFieldLabel,
                    controller: _requestReferenceController,
                    mono: true,
                    ltr: true,
                  ),
                  const SizedBox(height: SeenSpace.s6),
                  BlocBuilder<SupportBloc, SupportState>(
                    buildWhen: (previous, current) =>
                        current is SupportLoaded &&
                        (previous is! SupportLoaded || previous.createStatus != current.createStatus),
                    builder: (context, state) {
                      final isSubmitting =
                          state is SupportLoaded && state.createStatus == CreateTicketStatus.submitting;
                      return SeenButton(
                        label: isSubmitting ? l10n.loading : l10n.submit,
                        expand: true,
                        onPressed: isSubmitting ? null : _submit,
                      );
                    },
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
