// Read a passport from a photo (design/gaps PASS-02..04): capture, reading, review. The photo is
// taken with the system camera or chosen from the gallery, sent once, read by the server and then
// deleted. What the server read are suggestions: the person chooses what goes into the form.
//
// Pops with the chosen values (field key -> value), or null when the person goes on by hand.
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
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/suggestion_row.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../../system_status/presentation/widgets/permission_denied_sheet.dart';
import '../../domain/entities/passport_reading.dart';
import '../../domain/services/passport_photo_picker.dart';
import '../bloc/passport_scan_cubit.dart';

class PassportScanScreen extends StatelessWidget {
  const PassportScanScreen({super.key, required this.fields, this.createCubit});

  /// The form's fields in the order the form shows them: key -> label.
  final Map<String, String> fields;

  /// Test seam; defaults to the DI container.
  final PassportScanCubit Function(List<String> fieldKeys)? createCubit;

  static Future<Map<String, String>?> open(BuildContext context, {required Map<String, String> fields}) =>
      Navigator.of(context).push<Map<String, String>>(MaterialPageRoute(builder: (_) => PassportScanScreen(fields: fields)));

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => (createCubit ?? InjectionContainer.instance.createPassportScanCubit)(fields.keys.toList()),
      child: _Flow(fields: fields),
    );
  }
}

class _Flow extends StatelessWidget {
  const _Flow({required this.fields});

  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return BlocConsumer<PassportScanCubit, PassportScanState>(
      listenWhen: (a, b) => a.pickerDenied != b.pickerDenied && b.pickerDenied != null,
      listener: (context, state) {
        showPermissionDeniedSheet(context, permission: state.pickerDenied == 'camera' ? DeniedPermission.camera : DeniedPermission.photos);
      },
      builder: (context, state) {
        final review = state.stage == PassportStage.review;
        return Scaffold(
          backgroundColor: c.card,
          body: SeenScreenBackground(
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  SeenScreenHeader(
                    title: review ? l10n.passReviewTitle : l10n.passCaptureTitle,
                    subtitle: review ? l10n.passReviewSub : null,
                    showBack: review,
                    onBack: review ? context.read<PassportScanCubit>().retake : null,
                    trailing: review
                        ? null
                        : SeenRoundIconButton(icon: SeenIcons.x, semanticLabel: l10n.commonClose, onPressed: () => Navigator.of(context).pop()),
                  ),
                  Expanded(child: _Content(state: state, fields: fields)),
                  _Actions(state: state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.state, required this.fields});

  final PassportScanState state;
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return switch (state.stage) {
      PassportStage.capture => _Capture(notImage: state.notImage),
      PassportStage.reading => const _Reading(),
      PassportStage.review => _Review(state: state, fields: fields),
      PassportStage.failed => _Message(
          tone: SeenBannerTone.error,
          title: l10n.passFailedTitle,
          body: switch (state.issue?.kind) {
            PassportIssueKind.offline => l10n.commonCheckConnection,
            PassportIssueKind.rateLimited || PassportIssueKind.forbidden || PassportIssueKind.generic || PassportIssueKind.tooLarge => l10n.commonErrorTitle,
            _ => l10n.passFailedBody,
          },
        ),
      PassportStage.unavailable => _Unavailable(),
    };
  }
}

// ───────────────────────── capture ─────────────────────────

class _Capture extends StatelessWidget {
  const _Capture({required this.notImage});

  final bool notImage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (notImage) ...[SeenInlineBanner(tone: SeenBannerTone.warn, message: l10n.passNotImage), const SizedBox(height: 12)],
        // The guide the page goes into. The system camera does the shooting, so this is an
        // illustration of the frame, on a light surface (never a dark viewfinder).
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.accentSoft,
            border: Border.all(color: c.border),
            borderRadius: const BorderRadius.all(SeenRadius.r22),
          ),
          child: SizedBox(
            height: 360,
            child: Center(
              child: SizedBox(
                width: 300,
                height: 212,
                child: CustomPaint(
                  painter: _GuidePainter(c.borderStrong, c.accent),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(SeenIcons.passport, size: 36, color: c.accent),
                        const SizedBox(height: 10),
                        Text(l10n.passGuideTitle, style: type.title, textAlign: TextAlign.center),
                        const SizedBox(height: 4),
                        Text(l10n.passGuideSub, style: type.caption.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _Tip(icon: SeenIcons.camera, label: l10n.passTipLight)),
            const SizedBox(width: 10),
            Expanded(child: _Tip(icon: SeenIcons.scan, label: l10n.passTipGlare)),
            const SizedBox(width: 10),
            Expanded(child: _Tip(icon: SeenIcons.passport, label: l10n.passTipFull)),
          ],
        ),
      ],
    );
  }
}

class _Tip extends StatelessWidget {
  const _Tip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(color: c.accentSoft, borderRadius: const BorderRadius.all(SeenRadius.r12)),
          child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20, color: c.accent)),
        ),
        const SizedBox(height: 6),
        Text(label, style: SeenType.of(context).caption.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
      ],
    );
  }
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.dash, this.corner);

  final Color dash;
  final Color corner;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final dashed = Paint()
      ..color = dash
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()..addRRect(rect);
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 6), dashed);
        d += 12;
      }
    }
    final bracket = Paint()
      ..color = corner
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const l = 28.0;
    void corner4(Offset o, double dx, double dy) {
      canvas.drawLine(o, o.translate(dx * l, 0), bracket);
      canvas.drawLine(o, o.translate(0, dy * l), bracket);
    }

    corner4(Offset.zero, 1, 1);
    corner4(Offset(size.width, 0), -1, 1);
    corner4(Offset(0, size.height), 1, -1);
    corner4(Offset(size.width, size.height), -1, -1);
  }

  @override
  bool shouldRepaint(_GuidePainter old) => old.dash != dash || old.corner != corner;
}

// ───────────────────────── reading / messages ─────────────────────────

class _Reading extends StatelessWidget {
  const _Reading();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SeenLoader(size: 44),
          const SizedBox(height: 16),
          Text(l10n.passReading, style: type.title),
          const SizedBox(height: 4),
          Text(l10n.passReadingHint, style: type.caption.copyWith(color: c.inkSecondary)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.tone, required this.title, required this.body});

  final SeenBannerTone tone;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [SeenInlineBanner(tone: tone, message: '$title. $body')],
      );
}

class _Unavailable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(color: c.accentSoft, borderRadius: const BorderRadius.all(SeenRadius.r22)),
              child: SizedBox(width: 72, height: 72, child: Icon(SeenIcons.scan, size: 32, color: c.accent)),
            ),
            const SizedBox(height: 16),
            Text(l10n.passUnavailableTitle, style: type.h2, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(l10n.passUnavailableBody, style: type.body.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── review ─────────────────────────

class _Review extends StatelessWidget {
  const _Review({required this.state, required this.fields});

  final PassportScanState state;
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final cubit = context.read<PassportScanCubit>();
    final anyLow = state.rows.any((r) => !r.suggestion.checked);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
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
                DecoratedBox(
                  decoration: BoxDecoration(color: c.accentSoft, borderRadius: const BorderRadius.all(SeenRadius.r12)),
                  child: SizedBox(width: 44, height: 44, child: Icon(SeenIcons.passport, size: 24, color: c.accent)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.digits(l10n.passReadCount(state.rows.length)), style: type.bodyStrong),
                      Text(l10n.passReviewHint, style: type.caption.copyWith(color: c.inkSecondary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.border),
            borderRadius: const BorderRadius.all(SeenRadius.r22),
            boxShadow: SeenShadows.card,
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.all(SeenRadius.r22),
            child: Column(
              children: [
                for (var i = 0; i < state.rows.length; i++)
                  SuggestionRow(
                    first: i == 0,
                    field: fields[state.rows[i].suggestion.key] ?? state.rows[i].suggestion.key,
                    value: state.rows[i].suggestion.value,
                    checked: state.rows[i].selected,
                    confidence: state.rows[i].suggestion.checked ? SuggestionConfidence.high : SuggestionConfidence.low,
                    lowConfidenceLabel: l10n.passLowConfidence,
                    appliedLabel: l10n.passAppliedChip,
                    onChanged: (_) => cubit.toggle(state.rows[i].suggestion.key),
                  ),
              ],
            ),
          ),
        ),
        if (anyLow) ...[
          const SizedBox(height: 10),
          Text(l10n.passLowNote, style: type.caption.copyWith(color: c.inkSecondary)),
        ],
      ],
    );
  }
}

// ───────────────────────── sticky actions ─────────────────────────

class _Actions extends StatelessWidget {
  const _Actions({required this.state});

  final PassportScanState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final s = SeenStrings.of(context);
    final cubit = context.read<PassportScanCubit>();
    return switch (state.stage) {
      PassportStage.capture => SeenActionBar(actions: [
          SeenButton.secondary(label: l10n.passFromPhotos, icon: SeenIcons.image, expand: true, onPressed: () => cubit.capture(PassportPhotoSource.gallery)),
          SeenButton(label: l10n.passCapture, icon: SeenIcons.camera, expand: true, onPressed: () => cubit.capture(PassportPhotoSource.camera)),
        ]),
      PassportStage.reading => SeenActionBar(actions: [SeenButton.secondary(label: l10n.commonCancel, expand: true, onPressed: cubit.cancel)]),
      PassportStage.failed => SeenActionBar(actions: [
          SeenButton.secondary(label: l10n.passManual, expand: true, onPressed: () => Navigator.of(context).pop()),
          SeenButton(label: l10n.passRetake, icon: SeenIcons.camera, expand: true, onPressed: cubit.retake),
        ]),
      PassportStage.unavailable => SeenActionBar(actions: [
          SeenButton(label: l10n.passContinueManual, expand: true, onPressed: () => Navigator.of(context).pop()),
        ]),
      PassportStage.review => SeenActionBar(actions: [
          SeenButton.secondary(label: l10n.passRetake, expand: true, onPressed: cubit.retake),
          SeenButton(
            label: s.digits(l10n.passApply(state.selectedCount)),
            expand: true,
            onPressed: state.selectedCount == 0 ? null : () => Navigator.of(context).pop(cubit.chosen),
          ),
        ]),
    };
  }
}
