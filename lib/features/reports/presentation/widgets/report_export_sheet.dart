// Export a report (design/gaps REP-05): pick the format, export, then share or save the file. The
// server builds the file (csv, xlsx or pdf; at most 5,000 rows) and the app holds it in memory only.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/components.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/report.dart';
import '../bloc/report_cubits.dart';

/// Opens the sheet for [request] (which has [rows] rows and [columns] columns, for the subtitle).
Future<void> showReportExportSheet(
  BuildContext context, {
  required ReportRequest request,
  required int rows,
  required int columns,
  ReportExportCubit Function()? createCubit,
}) {
  final l10n = AppLocalizations.of(context)!;
  final s = SeenStrings.of(context);
  return showSeenSheet<void>(
    context: context,
    title: l10n.repExportTitle,
    subtitle: s.digits(l10n.repExportSub(rows, columns)),
    builder: (_) => _SheetBody(request: request, createCubit: createCubit ?? () => InjectionContainer.instance.createReportExportCubit(request)),
  );
}

class _SheetBody extends StatefulWidget {
  const _SheetBody({required this.request, required this.createCubit});

  final ReportRequest request;
  final ReportExportCubit Function() createCubit;

  @override
  State<_SheetBody> createState() => _SheetBodyState();
}

class _SheetBodyState extends State<_SheetBody> {
  // Created here, closed in dispose().
  late final ReportExportCubit _cubit = widget.createCubit();

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return BlocConsumer<ReportExportCubit, ReportExportState>(
      bloc: _cubit,
      listenWhen: (a, b) => b.outcome != null && a.outcomeSeq != b.outcomeSeq,
      listener: (context, state) {
        final text = switch (state.outcome) {
          ReportExportOutcome.saved => l10n.repReadyTitle,
          ReportExportOutcome.saveFailed || ReportExportOutcome.shareFailed => l10n.repExportFailed,
          null => null,
        };
        if (text != null) {
          showSeenToast(context, message: text);
        }
      },
      builder: (context, state) {
        final exporting = state.status == ReportExportStatus.exporting;
        final ready = state.status == ReportExportStatus.ready;
        final formats = <(ReportFormat, String, String)>[
          (ReportFormat.pdf, 'PDF', l10n.repFmtPdfSub),
          (ReportFormat.xlsx, 'Excel · XLSX', l10n.repFmtXlsxSub),
          (ReportFormat.csv, 'CSV', l10n.repFmtCsvSub),
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.status == ReportExportStatus.failed) ...[
                SeenInlineBanner(
                  tone: state.issue?.kind == ReportIssueKind.forbidden ? SeenBannerTone.warn : SeenBannerTone.error,
                  message: state.issue?.kind == ReportIssueKind.tooLarge ? '${l10n.repTruncatedTitle}. ${l10n.repTruncatedBody}' : l10n.repExportFailed,
                ),
                const SizedBox(height: 12),
              ],
              if (ready) _Ready(file: state.file!),
              if (!ready)
                DecoratedBox(
                  decoration: BoxDecoration(color: c.card, border: Border.all(color: c.border), borderRadius: const BorderRadius.all(SeenRadius.r22)),
                  child: Column(
                    children: [
                      for (var i = 0; i < formats.length; i++)
                        _FormatRow(
                          title: formats[i].$2,
                          subtitle: formats[i].$3,
                          selected: state.format == formats[i].$1,
                          enabled: !exporting,
                          last: i == formats.length - 1,
                          onTap: () => _cubit.selectFormat(formats[i].$1),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              if (ready)
                Row(
                  children: [
                    Expanded(child: SeenButton.secondary(label: l10n.repDownload, icon: SeenIcons.download, expand: true, onPressed: _cubit.download)),
                    const SizedBox(width: 10),
                    Expanded(child: SeenButton(label: l10n.repShare, expand: true, onPressed: _cubit.share)),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(child: SeenButton.secondary(label: l10n.commonCancel, expand: true, onPressed: exporting ? null : () => Navigator.of(context).pop())),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SeenButton(
                        label: exporting ? l10n.repExporting : (state.status == ReportExportStatus.failed ? l10n.commonRetry : l10n.repExport),
                        icon: exporting ? null : SeenIcons.download,
                        loading: exporting,
                        expand: true,
                        onPressed: exporting ? null : _cubit.export,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Text(widget.request.title, style: type.caption.copyWith(color: c.inkMuted), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        );
      },
    );
  }
}

class _FormatRow extends StatelessWidget {
  const _FormatRow({required this.title, required this.subtitle, required this.selected, required this.enabled, required this.last, required this.onTap});

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final bool last;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: DecoratedBox(
          decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: c.border))),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: const BorderRadius.all(SeenRadius.r12)),
                  child: SizedBox(width: 36, height: 36, child: Icon(SeenIcons.table, size: 20, color: c.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: type.bodyStrong.copyWith(color: enabled ? c.ink : c.inkMuted)),
                      Text(subtitle, style: type.caption.copyWith(color: enabled ? c.inkSecondary : c.inkMuted)),
                    ],
                  ),
                ),
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, size: 22, color: selected ? c.accent : c.borderStrong),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Ready extends StatelessWidget {
  const _Ready({required this.file});

  final ReportFile file;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final tone = SeenRequestStatus.completed.colors;
    final kb = (file.bytes.length / 1024).ceil();
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: tone.bg, borderRadius: const BorderRadius.all(SeenRadius.r22)),
          child: SizedBox(width: 56, height: 56, child: Icon(SeenIcons.check, size: 28, color: tone.fg)),
        ),
        const SizedBox(height: 10),
        Text(l10n.repReadyTitle, style: type.title),
        const SizedBox(height: 2),
        Text(l10n.repReadySub, style: type.caption.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: const BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(SeenRadius.lg)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(SeenIcons.table, size: 20, color: c.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Directionality(textDirection: TextDirection.ltr, child: Text(file.filename, style: type.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      Text('${s.digits(l10n.commonSizeKb('$kb'))} · ${s.digits(l10n.repRowsCount(file.rowCount))}', style: type.caption.copyWith(color: c.inkSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
