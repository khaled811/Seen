// New ticket (Figma SUP-02): category, priority, subject, description and an
// optional attachment slot. Submitting opens the created ticket's thread.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/failure_message.dart';
import '../../../../core/presentation/foundation/seen_vectors.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/dashed_border.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/svg_icon.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/validators/form_validators.dart';
import '../../../requests/presentation/bloc/staged_attachment_cubit.dart';
import '../../../wallet/presentation/widgets/seen_receipt_slot.dart';
import '../bloc/support_bloc.dart';
import '../bloc/support_event.dart';
import '../bloc/support_state.dart';
import '../bloc/ticket_categories_cubit.dart';
import '../widgets/ticket_category_sheet.dart';

// Figma lists high first (at the start edge), then normal, then low.
const _priorities = [
  TicketPriority.high,
  TicketPriority.normal,
  TicketPriority.low
];

class CreateTicketScreen extends StatefulWidget {
  const CreateTicketScreen(
      {super.key,
      this.requestId,
      this.createAttachment,
      this.createCategories});

  /// Test seam for the categories cubit; defaults to the DI container.
  final TicketCategoriesCubit Function()? createCategories;

  /// Test seam for the attachment cubit; defaults to the DI container.
  final StagedAttachmentCubit Function()? createAttachment;

  /// The request this ticket is about, when opened from one. Not a field of the
  /// form (the design has none): it travels with the ticket.
  final String? requestId;

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  // Owned here, disposed in dispose().
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  // A financial correction is a wallet-adjustment ticket (agent, action and amount): it cannot be
  // opened from this form, so the kind stays general; the picker only chooses the server's category.
  final TicketCategory _category = TicketCategory.general;
  String? _categoryCode;

  /// Shows the picked category's name in the picker field.
  final _categoryField = TextEditingController();
  TicketPriority _priority = TicketPriority.normal;

  /// The optional attachment: created here, closed in dispose(). It is sent to the
  /// server as soon as it is picked and the ticket refers to it by id.
  late final StagedAttachmentCubit _attachment = (widget.createAttachment ??
      InjectionContainer.instance.createStagedAttachmentCubit)();

  /// The categories to pick from: created here, closed in dispose(); read when the sheet opens.
  TicketCategoriesCubit? _categoriesCubit;

  /// Created the first time the sheet opens, never otherwise.
  TicketCategoriesCubit get _categories => _categoriesCubit ??= (widget.createCategories ??
      InjectionContainer.instance.createTicketCategoriesCubit)();

  @override
  void dispose() {
    _categoriesCubit?.close();
    _categoryField.dispose();
    _attachment.close();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_attachment.state.uploading) return; // the file is still on its way
    context.read<SupportBloc>().add(
          SupportTicketCreateSubmitted(
            category: _category,
            priority: _priority,
            subject: _subjectController.text.trim(),
            message: _messageController.text.trim(),
            requestId: widget.requestId,
            attachmentFileId: _attachment.state.fileId,
            categoryCode: _categoryCode,
          ),
        );
  }

  Future<void> _pickCategory() async {
    final picked = await showTicketCategorySheet(context,
        cubit: _categories, selectedCode: _categoryCode);
    if (picked != null && mounted) {
      setState(() {
        _categoryCode = picked.code;
        _categoryField.text = picked.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final priorityLabels = {
      TicketPriority.high: l10n.ticketPriorityHigh,
      TicketPriority.normal: l10n.ticketPriorityNormal,
      TicketPriority.low: l10n.ticketPriorityLow,
    };
    final priorityColors = {
      TicketPriority.high: SeenRequestStatus.deadlineUnder24h.colors,
      TicketPriority.normal: SeenRequestStatus.newRequest.colors,
      TicketPriority.low: SeenRequestStatus.cancelled.colors,
    };
    return BlocListener<SupportBloc, SupportState>(
      listenWhen: (previous, current) =>
          current is SupportLoaded &&
          current.createStatus == CreateTicketStatus.failure,
      listener: (context, state) {
        final loaded = state as SupportLoaded;
        final message = failureTextOr(
            l10n, loaded.createFailure, loaded.createError ?? l10n.error);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
      },
      child: Scaffold(
        backgroundColor: c.card,
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                SeenScreenHeader(title: l10n.createTicketTitle),
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                          20, SeenSpace.s1, 20, SeenSpace.s6),
                      children: [
                        SeenTextField(
                          label: l10n.supCategory,
                          picker: true,
                          readOnly: true,
                          controller: _categoryField,
                          hint: l10n.supCategoryHint,
                          suffix: Icon(SeenIcons.forward(context),
                              size: 16, color: c.inkMuted),
                          onTap: _pickCategory,
                        ),
                        const SizedBox(height: 12),
                        Text(l10n.ticketPriorityFieldLabel,
                            style: t.label.copyWith(color: c.ink)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final priority in _priorities)
                              _PriorityChip(
                                label: priorityLabels[priority]!,
                                bg: priorityColors[priority]!.bg,
                                fg: priorityColors[priority]!.fg,
                                selected: _priority == priority,
                                onTap: () =>
                                    setState(() => _priority = priority),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SeenTextField(
                          label: l10n.ticketSubjectFieldLabel,
                          controller: _subjectController,
                          validator: (value) => FormValidators.required(value,
                              message: l10n.ticketSubjectRequired),
                        ),
                        const SizedBox(height: 12),
                        SeenTextField(
                          label: l10n.ticketDescriptionLabel,
                          controller: _messageController,
                          maxLines: 4,
                          hint: l10n.ticketDescriptionHint,
                          validator: (value) => FormValidators.required(value,
                              message: l10n.validationRequired),
                        ),
                        const SizedBox(height: 12),
                        BlocProvider<StagedAttachmentCubit>.value(
                          value: _attachment,
                          child: SeenReceiptSlot(
                              title: l10n.ticketAttachOptional,
                              caption: '',
                              attachedText:
                                  SeenStrings.of(context).attachmentAttached,
                              uploadingText:
                                  SeenStrings.of(context).attachmentUploading,
                              emptyBuilder: (onTap) => Semantics(
                                    button: true,
                                    child: SeenDashedBorder(
                                      color: SeenBrand.violet40,
                                      radius: 16,
                                      child: Material(
                                        color: SeenBrand.violet05,
                                        borderRadius: const BorderRadius.all(
                                            SeenRadius.lg),
                                        child: InkWell(
                                          borderRadius: const BorderRadius.all(
                                              SeenRadius.lg),
                                          onTap: onTap,
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 14, vertical: 12),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                      l10n.ticketAttachOptional,
                                                      style: t.label.copyWith(
                                                          color: c.primary)),
                                                ),
                                                SeenSvgIcon(
                                                    SeenVectors.authUpload,
                                                    size: 18,
                                                    color: c.primary),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  )),
                        ),
                      ],
                    ),
                  ),
                ),
                BlocBuilder<SupportBloc, SupportState>(
                  buildWhen: (previous, current) =>
                      current is SupportLoaded &&
                      (previous is! SupportLoaded ||
                          previous.createStatus != current.createStatus),
                  builder: (context, state) {
                    final isSubmitting = state is SupportLoaded &&
                        state.createStatus == CreateTicketStatus.submitting;
                    return SeenActionBar(
                      actions: [
                        SeenButton(
                          label: isSubmitting
                              ? l10n.loading
                              : l10n.ticketSubmitAction,
                          loading: isSubmitting,
                          expand: true,
                          onPressed: isSubmitting ? null : _submit,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A priority as a status-coloured pill; the chosen one carries a violet ring.
class _PriorityChip extends StatelessWidget {
  const _PriorityChip({
    required this.label,
    required this.bg,
    required this.fg,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color bg;
  final Color fg;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: bg,
        shape: StadiumBorder(
            side: BorderSide(
                color: selected ? c.primary : Colors.transparent, width: 1.5)),
        child: InkWell(
          onTap: onTap,
          customBorder: const StadiumBorder(),
          child: SizedBox(
            height: 32,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: t.chipS.copyWith(color: fg)),
                  const SizedBox(width: 6),
                  DecoratedBox(
                    decoration:
                        BoxDecoration(color: fg, shape: BoxShape.circle),
                    child: const SizedBox(width: 6, height: 6),
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
