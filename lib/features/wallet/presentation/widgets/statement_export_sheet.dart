// Statement export (Figma WAL-06): pick a period and a format, then download or
// share. The server builds the file; the sheet shows the wait, and a failure
// with a retry.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/selection.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../../core/presentation/widgets/loading/seen_loader.dart';
import '../../domain/entities/statement.dart';
import '../bloc/statement_export_cubit.dart';

/// Opens the export sheet. [createCubit], [pickRange] and [now] are test seams.
Future<void> showStatementExportSheet(
  BuildContext context, {
  StatementExportCubit Function()? createCubit,
  Future<DateTimeRange?> Function(BuildContext context, DateTime now)? pickRange,
  DateTime Function()? now,
}) {
  final l10n = AppLocalizations.of(context)!;
  // Messages that outlive the sheet go through the screen below it.
  final messenger = ScaffoldMessenger.of(context);
  return showSeenSheet<void>(
    context: context,
    title: l10n.walletExportTitle,
    builder: (_) => BlocProvider(
      create: (_) => (createCubit ?? InjectionContainer.instance.createStatementExportCubit)(),
      child: _ExportBody(messenger: messenger, pickRange: pickRange, now: now ?? DateTime.now),
    ),
  );
}

class _ExportBody extends StatefulWidget {
  const _ExportBody({required this.messenger, required this.pickRange, required this.now});

  final ScaffoldMessengerState messenger;
  final Future<DateTimeRange?> Function(BuildContext context, DateTime now)? pickRange;
  final DateTime Function() now;

  @override
  State<_ExportBody> createState() => _ExportBodyState();
}

class _ExportBodyState extends State<_ExportBody> {
  StatementPeriod _period = StatementPeriod.thisMonth;
  StatementFormat _format = StatementFormat.pdf;
  StatementRange? _custom;
  StatementAction _lastAction = StatementAction.download;

  StatementRange get _range =>
      _period == StatementPeriod.custom && _custom != null
          ? _custom!
          : StatementRange.forPeriod(_period, widget.now());

  Future<void> _selectPeriod(StatementPeriod period) async {
    if (period != StatementPeriod.custom) return setState(() => _period = period);
    final now = widget.now();
    final picked = await (widget.pickRange ?? _defaultPicker)(context, now);
    if (picked == null || !mounted) return;
    setState(() {
      _period = StatementPeriod.custom;
      _custom = StatementRange(picked.start, picked.end);
    });
  }

  Future<DateTimeRange?> _defaultPicker(BuildContext context, DateTime now) => showDateRangePicker(
        context: context,
        firstDate: DateTime(now.year - 5),
        lastDate: now,
        helpText: AppLocalizations.of(context)!.walletExportCustomHelp,
      );

  void _run(StatementAction action) {
    _lastAction = action;
    context.read<StatementExportCubit>().export(range: _range, format: _format, action: action);
  }

  String _rangeLabel(SeenStrings s, StatementRange r) {
    final sameMonth = r.from.year == r.to.year && r.from.month == r.to.month;
    return sameMonth ? '${s.numeral(r.from.day)} – ${s.dayMonth(r.to)}' : '${s.dayMonth(r.from)} – ${s.dayMonth(r.to)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final periodLabels = {
      StatementPeriod.thisMonth: l10n.walletExportThisMonth,
      StatementPeriod.threeMonths: l10n.walletExportThreeMonths,
      StatementPeriod.custom: l10n.walletExportCustom,
    };
    return BlocConsumer<StatementExportCubit, StatementExportState>(
      listenWhen: (previous, current) => previous.outcomeSeq != current.outcomeSeq,
      listener: (context, state) {
        if (state.outcome == StatementOutcome.saved) {
          widget.messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(l10n.walletExportSaved)));
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        final generating = state.status == StatementStatus.generating;
        final error = switch ((state.status, state.outcome)) {
          (StatementStatus.failed, _) => l10n.walletExportFailed,
          (_, StatementOutcome.saveFailed) => l10n.walletExportSaveFailed,
          (_, StatementOutcome.shareFailed) => l10n.walletExportShareFailed,
          _ => null,
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                for (final period in StatementPeriod.values) ...[
                  if (period != StatementPeriod.values.first) const SizedBox(width: 6),
                  Expanded(
                    child: _Choice(
                      label: periodLabels[period]!,
                      selected: _period == period,
                      onTap: generating ? null : () => _selectPeriod(period),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final format in StatementFormat.values) ...[
                  if (format != StatementFormat.values.first) const SizedBox(width: 12),
                  Expanded(
                    child: _FormatBox(
                      label: format == StatementFormat.pdf ? 'PDF' : 'Excel',
                      selected: _format == format,
                      onTap: generating ? null : () => setState(() => _format = format),
                    ),
                  ),
                ],
              ],
            ),
            if (generating) ...[
              const SizedBox(height: 16),
              Semantics(
                liveRegion: true,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: SeenBrand.violet05,
                    borderRadius: BorderRadius.all(SeenRadius.r14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.walletExportGenerating(_rangeLabel(s, _range)), style: t.label.copyWith(color: c.ink)),
                        const SizedBox(height: 6),
                        // The server reports no progress: the trace, not a made-up percentage.
                        const Align(alignment: AlignmentDirectional.centerStart, child: SeenLoader(size: 24)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            if (error != null && !generating) ...[
              const SizedBox(height: 16),
              SeenInlineBanner(
                tone: SeenBannerTone.error,
                message: error,
                actionLabel: l10n.walletExportRetry,
                onAction: () => _run(_lastAction),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SeenButton(
                    label: l10n.walletExportDownload,
                    expand: true,
                    loading: generating && _lastAction == StatementAction.download,
                    onPressed: generating ? null : () => _run(StatementAction.download),
                  ),
                ),
                const SizedBox(width: SeenSpace.s3),
                Expanded(
                  child: SeenButton.secondary(
                    label: l10n.walletExportShare,
                    expand: true,
                    loading: generating && _lastAction == StatementAction.share,
                    onPressed: generating ? null : () => _run(StatementAction.share),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? SeenBrand.violet10 : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SeenRadius.r12),
          side: BorderSide(color: selected ? c.primary : c.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.r12)),
          child: SizedBox(
            height: 38,
            child: Center(
              child: Text(label, style: t.label.copyWith(color: selected ? c.primary : c.inkSecondary)),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormatBox extends StatelessWidget {
  const _FormatBox({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? SeenBrand.violet05 : c.card,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(SeenRadius.r14),
          side: BorderSide(color: selected ? c.primary : c.border),
        ),
        child: InkWell(
          onTap: onTap,
          customBorder: const RoundedRectangleBorder(borderRadius: BorderRadius.all(SeenRadius.r14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SeenRadioDot(selected: selected),
                const SizedBox(width: 8),
                Text(label, style: t.label.copyWith(color: c.ink)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
