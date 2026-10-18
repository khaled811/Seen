// Profit margin per service (Figma ACC-02): what the agency adds to each service for
// its sub-agents, which ones are read-only, and the change log.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/loader.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/text_field.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/service_margin.dart';
import '../bloc/profile_cubits.dart';
import '../widgets/profile_strings.dart';
import '../../../auth/domain/entities/role_permissions.dart';
import '../widgets/session_role.dart';

/// Server error code when a margin value is refused.
/// TODO(backend-contract): confirm the name (docs/BACKEND_MIGRATION_GAPS.md section 33).
const marginInvalidCode = 'INVALID_MARGIN';

class ProfitMarginScreen extends StatelessWidget {
  const ProfitMarginScreen({super.key, this.createCubit});

  /// Test seam; defaults to the DI container.
  final MarginsCubit Function()? createCubit;

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const ProfitMarginScreen());

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return BlocProvider(
      create: (_) => (createCubit ?? () => InjectionContainer.instance.createMarginsCubit(canEdit: permissionsOf(context).can(Capability.margins)))()..load(),
      child: BlocConsumer<MarginsCubit, MarginsState>(
        listenWhen: (p, c) => p.save != c.save && (c.save == MarginSaveStatus.saved || c.save == MarginSaveStatus.failed),
        listener: (context, state) {
          final failure = state.failure;
          final message = state.save == MarginSaveStatus.saved
              ? s.marginSaved
              : (failure is ServerFailure && failure.code == marginInvalidCode || failure is ValidationFailure
                  ? s.marginRejected
                  : s.marginSaveFailed);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
        },
        buildWhen: (p, c) => true,
        builder: (context, state) {
          final cubit = context.read<MarginsCubit>();
          return PopScope(
            canPop: !state.dirty,
            onPopInvoked: (didPop) async {
              if (didPop) {
                return;
              }
              final navigator = Navigator.of(context);
              final discard = await _confirmDiscard(context);
              if (discard == true) {
                navigator.pop();
              }
            },
            child: Scaffold(
              backgroundColor: SeenColors.of(context).card,
              body: SeenScreenBackground(
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      SeenScreenHeader(title: s.marginTitle),
                      Expanded(child: _Body(state: state)),
                      if (state.status == LoadStatus.loaded && cubit.canEdit)
                        SeenActionBar(
                          actions: [
                            SeenButton(
                              label: s.saveChanges,
                              expand: true,
                              loading: state.save == MarginSaveStatus.saving,
                              onPressed: state.dirty ? cubit.save : null,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<bool?> _confirmDiscard(BuildContext context) {
  final s = SeenStrings.of(context);
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.discardTitle),
      content: Text(s.discardBody),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(s.keepEditing)),
        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(s.discardAction)),
      ],
    ),
  );
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final MarginsState state;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final c = SeenColors.of(context);
    final cubit = context.read<MarginsCubit>();
    if (state.margins.isEmpty) {
      if (state.status == LoadStatus.failure) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.loadFailedTitle),
              const SizedBox(height: SeenSpace.s3),
              SeenButton(label: s.retry, onPressed: cubit.load),
            ],
          ),
        );
      }
      return const Center(child: SeenLoader());
    }
    final locked = [for (final m in state.margins) if (!m.editable) m.serviceName];
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, SeenSpace.s6),
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: SeenRequestStatus.underReview.colors.bg,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(SeenIcons.info, size: 20, color: SeenRequestStatus.underReview.colors.fg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(s.marginBanner, style: t.label.copyWith(color: SeenRequestStatus.underReview.colors.fg)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.all(SeenRadius.r22),
              border: Border.all(color: c.border),
              boxShadow: SeenShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (var i = 0; i < state.margins.length; i++)
                    _MarginRow(margin: state.margins[i], last: i == state.margins.length - 1, state: state),
                ],
              ),
            ),
          ),
          if (locked.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(s.marginLocked(locked.join('، ')), style: t.caption.copyWith(color: c.inkMuted)),
          ],
          if (!cubit.canEdit) ...[
            const SizedBox(height: 8),
            Text(s.marginViewOnly, style: t.caption.copyWith(color: c.inkMuted)),
          ],
          const SizedBox(height: 18),
          Text(s.changeLog, style: t.title),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: const BorderRadius.all(SeenRadius.r22),
              border: Border.all(color: c.border),
              boxShadow: SeenShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: state.history.isEmpty
                    ? Text(s.changeLogEmpty, style: t.caption.copyWith(color: c.inkSecondary))
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (final h in state.history)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(s.marginChangeLine(h), style: t.caption.copyWith(color: c.inkSecondary)),
                            ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String? key) => switch (key) {
      'flight' => SeenIcons.plane,
      'entry' => SeenIcons.globe,
      _ => SeenIcons.passport,
    };

class _MarginRow extends StatelessWidget {
  const _MarginRow({required this.margin, required this.last, required this.state});

  final ServiceMargin margin;
  final bool last;
  final MarginsState state;

  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<MarginsCubit>();
    final picked = await showSeenSheet<int>(
      context: context,
      title: margin.serviceName,
      builder: (_) => _MarginEditor(margin: margin, current: state.valueOf(margin)),
    );
    if (picked != null) {
      cubit.edit(margin.serviceId, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final s = SeenStrings.of(context);
    final cubit = context.read<MarginsCubit>();
    final canTap = margin.editable && cubit.canEdit && state.save != MarginSaveStatus.saving;
    final edited = state.drafts.containsKey(margin.serviceId);
    final label = s.marginValue(margin.kind, state.valueOf(margin));
    return DecoratedBox(
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.border))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: SeenBrand.violet10, borderRadius: BorderRadius.all(Radius.circular(10))),
              child: SizedBox(width: 32, height: 32, child: Icon(_iconFor(margin.iconKey), size: 18, color: SeenBrand.violet)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(margin.serviceName, style: t.body)),
            Semantics(
              button: canTap,
              label: '${margin.serviceName}: $label',
              excludeSemantics: true,
              child: Material(
                color: margin.editable ? c.card : SeenBrand.violet05,
                shape: RoundedRectangleBorder(
                  borderRadius: const BorderRadius.all(SeenRadius.r12),
                  side: margin.editable
                      ? BorderSide(color: edited ? c.primary : c.borderStrong)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: canTap ? () => _edit(context) : null,
                  customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.r12)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(label, style: t.label.copyWith(color: margin.editable ? c.ink : c.inkMuted)),
                        if (!margin.editable) ...[
                          const SizedBox(width: 6),
                          Icon(SeenIcons.lock, size: 14, color: c.inkMuted),
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
    );
  }
}

/// The edit sheet's body. Owns its controller (created here, disposed here).
class _MarginEditor extends StatefulWidget {
  const _MarginEditor({required this.margin, required this.current});

  final ServiceMargin margin;
  final int current;

  @override
  State<_MarginEditor> createState() => _MarginEditorState();
}

class _MarginEditorState extends State<_MarginEditor> {
  late final TextEditingController _controller = TextEditingController(text: _initialText());
  String? _error;

  String _initialText() {
    final v = widget.current;
    return v % 100 == 0 ? '${v ~/ 100}' : (v / 100).toString();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final parsed = double.tryParse(_controller.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
      setState(() => _error = SeenStrings.of(context).marginInvalid);
      return;
    }
    Navigator.of(context).pop((parsed * 100).round());
  }

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SeenTextField(
          label: s.marginFieldLabel(widget.margin.kind),
          controller: _controller,
          ltr: true,
          errorText: _error,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          onChanged: (_) {
            if (_error != null) {
              setState(() => _error = null);
            }
          },
          onSubmitted: (_) => _apply(),
        ),
        const SizedBox(height: SeenSpace.s4),
        SeenButton(label: s.applyAction, expand: true, onPressed: _apply),
      ],
    );
  }
}
