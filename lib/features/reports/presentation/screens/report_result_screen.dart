// A report's result (design/gaps REP-03, REP-04, REP-06): the table with its totals, and its states:
// loading, no rows, too many rows, error and no permission. Export opens the export sheet.
//
// It runs the report it is given and does not know how a report is defined: the builder that
// produces a [ReportRequest] is separate (the contract does not publish the definition, DECISIONS Q34).
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/loading/seen_loader.dart';
import '../../../../core/presentation/widgets/report_table.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../system_status/presentation/widgets/access_denied_view.dart';
import '../../domain/entities/report.dart';
import '../bloc/report_cubits.dart';
import '../widgets/report_export_sheet.dart';

class ReportResultScreen extends StatelessWidget {
  const ReportResultScreen({super.key, required this.request, this.createCubit, this.createExport});

  final ReportRequest request;

  /// Test seams; default to the DI container.
  final ReportResultCubit Function()? createCubit;
  final ReportExportCubit Function()? createExport;

  static Route<void> route(ReportRequest request) => MaterialPageRoute<void>(builder: (_) => ReportResultScreen(request: request));

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createCubit ?? () => InjectionContainer.instance.createReportResultCubit(request))()..load(),
      child: _View(request: request, createExport: createExport),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.request, this.createExport});

  final ReportRequest request;
  final ReportExportCubit Function()? createExport;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return BlocBuilder<ReportResultCubit, ReportResultState>(
      builder: (context, state) {
        final data = state.data;
        final forbidden = state.issue?.kind == ReportIssueKind.forbidden;
        final canExport = data != null && data.rows.isNotEmpty;
        return Scaffold(
          backgroundColor: c.card,
          body: SeenScreenBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SeenScreenHeader(title: forbidden ? l10n.repTitle : request.title, subtitle: forbidden ? null : request.subtitle),
                  Expanded(child: _Body(state: state, request: request)),
                  if (!forbidden && !state.loading)
                    SeenActionBar(actions: [
                      SeenButton.secondary(
                        label: state.truncated && data == null ? l10n.repNarrowPeriod : l10n.repEdit,
                        icon: SeenIcons.refresh,
                        expand: true,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      if (state.issue == null && data != null)
                        SeenButton(
                          label: state.truncated ? l10n.repExportAll : l10n.repExport,
                          icon: SeenIcons.download,
                          expand: true,
                          onPressed: canExport
                              ? () => showReportExportSheet(context, request: request, rows: data.totalRows, columns: data.columns.length, createCubit: createExport)
                              : null,
                        )
                      else if (state.issue != null && state.issue!.kind != ReportIssueKind.tooLarge)
                        SeenButton(label: l10n.commonRetry, icon: SeenIcons.refresh, expand: true, onPressed: context.read<ReportResultCubit>().load),
                    ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.request});

  final ReportResultState state;
  final ReportRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final issue = state.issue;
    if (state.loading) {
      return const _Loading();
    }
    if (issue?.kind == ReportIssueKind.forbidden) {
      return AccessDeniedView(
        area: 'reports',
        message: l10n.repNoPermissionBody,
        onBack: () => Navigator.of(context).maybePop(),
      );
    }
    if (issue?.kind == ReportIssueKind.tooLarge) {
      return _Block(icon: SeenIcons.table, title: l10n.repTruncatedTitle, body: l10n.repTruncatedBody);
    }
    if (issue != null) {
      return _Block(
        icon: SeenIcons.table,
        title: l10n.repGenerateErrorTitle,
        body: issue.kind == ReportIssueKind.offline ? l10n.commonCheckConnection : l10n.repGenerateErrorBody,
        error: true,
      );
    }
    final data = state.data!;
    if (data.rows.isEmpty) {
      return _Block(icon: SeenIcons.search, title: l10n.repEmptyTitle, body: l10n.repEmptyBody);
    }
    final type = SeenType.of(context);
    final c = SeenColors.of(context);
    final table = ReportTable(
      columns: [
        for (var i = 0; i < data.columns.length; i++)
          ReportTableColumn(
            data.columns[i].label,
            width: i == 0 ? 104 : (data.columns[i].kind == ReportColumnKind.money ? 116 : (data.columns[i].isNumeric ? 84 : 120)),
            numeric: data.columns[i].isNumeric,
            ltr: i == 0 || data.columns[i].kind == ReportColumnKind.date,
          ),
      ],
      rows: data.rows,
      totals: data.totals,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (state.truncated) ...[
          SeenInlineBanner(tone: SeenBannerTone.warn, message: '${l10n.repTruncatedTitle}. ${l10n.repTruncatedBody}'),
          const SizedBox(height: 12),
        ],
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.border),
            borderRadius: const BorderRadius.all(SeenRadius.r22),
            boxShadow: SeenShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(SeenIcons.table, size: 20, color: c.accent),
                const SizedBox(width: 10),
                Text(s.digits(l10n.repRowsCount(data.totalRows)), style: type.title),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.border),
            borderRadius: const BorderRadius.all(SeenRadius.r22),
            boxShadow: SeenShadows.card,
          ),
          child: ClipRRect(borderRadius: const BorderRadius.all(SeenRadius.r22), child: table),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SeenLoader(size: 56),
          const SizedBox(height: 16),
          Text(l10n.repGenerating, style: type.title),
          const SizedBox(height: 4),
          Text(l10n.repGeneratingHint, style: type.caption.copyWith(color: c.inkSecondary)),
          const SizedBox(height: 20),
          const SizedBox(width: 200, child: SeenSkeletonBox(height: 8, radius: 4)),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.icon, required this.title, required this.body, this.error = false});

  final IconData icon;
  final String title;
  final String body;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final tone = error ? SeenRequestStatus.rejected.colors : SeenRequestStatus.newRequest.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: tone.bg, borderRadius: const BorderRadius.all(SeenRadius.r22)),
              child: SizedBox(width: 72, height: 72, child: Icon(icon, size: 32, color: tone.fg)),
            ),
            const SizedBox(height: 16),
            Text(title, style: type.h2, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(body, style: type.body.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
