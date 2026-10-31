// Two-step verification flow (Figma SEC-02..04): scan the QR, type the first code, save the
// recovery codes. "Generate new codes" (SEC-01) reuses the same code and codes steps.
// The secret and the codes are held by the cubit only; nothing is logged or written to disk
// except the temporary file handed to the share sheet, which is deleted right after.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/components.dart';
import '../../../../core/presentation/widgets/feedback.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/two_factor.dart';
import '../bloc/two_factor_cubits.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';

/// Pops with `true` once the recovery codes were saved ("Done").
/// The secret key and the recovery codes: the app's own font with fixed-width digits (the
/// monospaced family is not bundled), spaced so that look-alike characters stay apart.
TextStyle _codeStyle(SeenType type) => type.bodyStrong.copyWith(letterSpacing: 1, fontFeatures: const [FontFeature.tabularFigures()]);

class TwoFactorSetupScreen extends StatelessWidget {
  const TwoFactorSetupScreen({super.key, required this.mode, this.createCubit, this.saveCodes});

  final TwoFactorFlowMode mode;

  /// Test seam; defaults to the DI container.
  final TwoFactorFlowCubit Function()? createCubit;

  /// Test seam for the "Download" action; defaults to the share sheet.
  final Future<void> Function(List<String> codes)? saveCodes;

  static Route<bool> route(TwoFactorFlowMode mode) =>
      MaterialPageRoute<bool>(builder: (_) => TwoFactorSetupScreen(mode: mode));

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) {
        final cubit = (createCubit ?? () => InjectionContainer.instance.createTwoFactorFlowCubit(mode))();
        cubit.start();
        return cubit;
      },
      child: _Flow(mode: mode, saveCodes: saveCodes ?? _shareCodes),
    );
  }

  /// Hands the codes to the share sheet as `seen-recovery-codes.txt`, then removes the file.
  static Future<void> _shareCodes(List<String> codes) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/seen-recovery-codes.txt');
    try {
      await file.writeAsString('${codes.join('\n')}\n', flush: true);
      await Share.shareXFiles([XFile(file.path, mimeType: 'text/plain')]);
    } finally {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}

class _Flow extends StatefulWidget {
  const _Flow({required this.mode, required this.saveCodes});

  final TwoFactorFlowMode mode;
  final Future<void> Function(List<String> codes) saveCodes;

  @override
  State<_Flow> createState() => _FlowState();
}

class _FlowState extends State<_Flow> {
  // Owned here, disposed in dispose().
  final _code = TextEditingController();
  bool _saved = false;
  bool _keyCopied = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  bool get _enable => widget.mode == TwoFactorFlowMode.enable;

  Future<void> _copyKey(TwoFactorSetup setup) async {
    await Clipboard.setData(ClipboardData(text: setup.secret));
    if (!mounted) {
      return;
    }
    setState(() => _keyCopied = true);
    showSeenToast(context, message: AppLocalizations.of(context)!.secKeyCopied);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _keyCopied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    return BlocConsumer<TwoFactorFlowCubit, TwoFactorFlowState>(
      // A wrong code keeps what was typed (the field shows the error); a new step starts empty.
      listenWhen: (a, b) => a.step != b.step,
      listener: (context, state) => _code.clear(),
      buildWhen: (a, b) => a != b,
      builder: (context, state) {
        final step = state.step;
        final title = _enable ? l10n.secSetupTitle : l10n.secRegenerate;
        final stepNumber = switch (step) {
          TwoFactorStep.scan => 1,
          TwoFactorStep.code => 2,
          TwoFactorStep.codes => 3,
        };
        return PopScope(
          // The codes are shown once: leaving before "Done" would lose them.
          canPop: step != TwoFactorStep.codes,
          child: Scaffold(
            backgroundColor: c.card,
            body: SeenScreenBackground(
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    SeenScreenHeader(
                      title: step == TwoFactorStep.codes ? l10n.secRecoveryCodes : title,
                      subtitle: _enable ? SeenStrings.of(context).digits(l10n.secStepOf(stepNumber, 3)) : null,
                      showBack: step != TwoFactorStep.codes,
                    ),
                    if (_enable)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                        child: SeenProgressRule(current: stepNumber),
                      ),
                    Expanded(
                      child: switch (step) {
                        TwoFactorStep.scan => _Scan(state: state, keyCopied: _keyCopied, onCopy: _copyKey),
                        TwoFactorStep.code => _Code(state: state, controller: _code),
                        TwoFactorStep.codes => _Codes(
                            codes: state.codes,
                            saved: _saved,
                            onSaved: (v) => setState(() => _saved = v),
                            onDownload: () => widget.saveCodes(state.codes),
                          ),
                      },
                    ),
                    _Sticky(state: state, code: _code, saved: _saved),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ───────────────────────── SEC-02 ─────────────────────────

class _Scan extends StatelessWidget {
  const _Scan({required this.state, required this.keyCopied, required this.onCopy});

  final TwoFactorFlowState state;
  final bool keyCopied;
  final Future<void> Function(TwoFactorSetup) onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final setup = state.setup;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(l10n.secScanTitle, style: type.h2),
        const SizedBox(height: 6),
        Text(l10n.secScanBody, style: type.body.copyWith(color: c.inkSecondary)),
        const SizedBox(height: 14),
        if (state.setupFailed)
          _SetupError(onRetry: () => context.read<TwoFactorFlowCubit>().start())
        else
          DecoratedBox(
            decoration: BoxDecoration(
              color: c.card,
              border: Border.all(color: c.border),
              borderRadius: const BorderRadius.all(SeenRadius.r22),
              boxShadow: SeenShadows.card,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: 200,
                    height: 200,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: c.border),
                      borderRadius: const BorderRadius.all(SeenRadius.lg),
                    ),
                    child: setup == null
                        ? const SeenSkeletonBox(height: 176, width: 176)
                        : Semantics(
                            image: true,
                            label: l10n.secScanTitle,
                            child: QrImageView(data: setup.provisioningUri, size: 176, padding: EdgeInsets.zero),
                          ),
                  ),
                  const SizedBox(height: 14),
                  Text(l10n.secManualKey, style: type.caption.copyWith(color: c.inkSecondary)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 54,
                          alignment: AlignmentDirectional.centerStart,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: c.accentSoft,
                            border: Border.all(color: c.border),
                            borderRadius: const BorderRadius.all(SeenRadius.lg),
                          ),
                          child: setup == null
                              ? const SeenSkeletonBox(height: 14, width: 180)
                              : Directionality(
                                  textDirection: TextDirection.ltr,
                                  child: Text(setup.groupedSecret, style: _codeStyle(type), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SeenIconButton(
                        icon: keyCopied ? SeenIcons.check : SeenIcons.copy,
                        semanticLabel: l10n.secCopyKey,
                        onPressed: setup == null ? null : () => onCopy(setup),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SetupError extends StatelessWidget {
  const _SetupError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final type = SeenType.of(context);
    final c = SeenColors.of(context);
    return Column(
      children: [
        const SizedBox(height: 24),
        Text(l10n.secSetupErrorTitle, style: type.title, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(l10n.commonCheckConnection, style: type.body.copyWith(color: c.inkSecondary), textAlign: TextAlign.center),
        const SizedBox(height: 16),
        SeenButton.outline(label: l10n.commonRetry, size: SeenButtonSize.small, onPressed: onRetry),
      ],
    );
  }
}

// ───────────────────────── SEC-03 ─────────────────────────

class _Code extends StatelessWidget {
  const _Code({required this.state, required this.controller});

  final TwoFactorFlowState state;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final cubit = context.read<TwoFactorFlowCubit>();
    final issue = state.issue;
    final wrong = issue?.kind == TwoFactorIssueKind.wrongCode;
    Widget? banner;
    if (state.locked) {
      banner = SeenInlineBanner(
        tone: SeenBannerTone.error,
        message: '${l10n.secLockedTitle}. ${SeenStrings.of(context).digits(l10n.secLockedBody(issue?.minutes ?? 15))}',
      );
    } else if (issue != null && !wrong) {
      banner = SeenInlineBanner(
        tone: issue.kind == TwoFactorIssueKind.offline ? SeenBannerTone.offline : SeenBannerTone.error,
        message: issue.kind == TwoFactorIssueKind.offline ? l10n.commonCheckConnection : l10n.commonErrorTitle,
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(l10n.secCodeTitle, style: type.h2),
        const SizedBox(height: 6),
        Text(l10n.secCodeBody, style: type.body.copyWith(color: c.inkSecondary)),
        const SizedBox(height: 20),
        Directionality(
          textDirection: TextDirection.ltr,
          child: SeenOtpInput(
            controller: controller,
            error: wrong,
            onChanged: (_) => cubit.edited(),
            onCompleted: state.locked || state.verifying ? null : cubit.submit,
          ),
        ),
        const SizedBox(height: 12),
        if (wrong)
          // The server does not say how many tries are left, so the plain wording is used.
          Text(l10n.secCodeWrong(0), style: type.caption.copyWith(color: SeenRequestStatus.rejected.colors.fg))
        else
          Row(
            children: [
              Icon(SeenIcons.clock, size: 14, color: c.inkSecondary),
              const SizedBox(width: 6),
              Expanded(child: Text(l10n.secCodeRefreshHint, style: type.caption.copyWith(color: c.inkSecondary))),
            ],
          ),
        if (banner != null) ...[const SizedBox(height: 14), banner],
      ],
    );
  }
}

// ───────────────────────── SEC-04 ─────────────────────────

class _Codes extends StatelessWidget {
  const _Codes({required this.codes, required this.saved, required this.onSaved, required this.onDownload});

  final List<String> codes;
  final bool saved;
  final ValueChanged<bool> onSaved;
  final Future<void> Function() onDownload;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      children: [
        Text(l10n.secCodesTitle, style: type.h2),
        const SizedBox(height: 6),
        Text(l10n.secCodesBody, style: type.body.copyWith(color: c.inkSecondary)),
        const SizedBox(height: 14),
        SeenInlineBanner(tone: SeenBannerTone.warn, message: l10n.secCodesOnce),
        const SizedBox(height: 14),
        DecoratedBox(
          decoration: BoxDecoration(
            color: c.card,
            border: Border.all(color: c.border),
            borderRadius: const BorderRadius.all(SeenRadius.r22),
            boxShadow: SeenShadows.card,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < codes.length; i++) _CodePill(index: i + 1, code: codes[i]),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SeenButton.secondary(
                label: l10n.secCopyAll,
                size: SeenButtonSize.small,
                icon: SeenIcons.copy,
                expand: true,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: codes.join('\n')));
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SeenButton.secondary(
                label: l10n.secDownload,
                size: SeenButtonSize.small,
                icon: SeenIcons.download,
                expand: true,
                onPressed: onDownload,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => onSaved(!saved),
          borderRadius: const BorderRadius.all(SeenRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Checkbox(value: saved, onChanged: (v) => onSaved(v ?? false), activeColor: c.accent),
                Expanded(child: Text(l10n.secSavedCheck, style: type.body)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CodePill extends StatelessWidget {
  const _CodePill({required this.index, required this.code});

  final int index;
  final String code;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Container(
      width: 154,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: const BorderRadius.all(SeenRadius.md)),
      child: Row(
        children: [
          Text(index.toString().padLeft(2, '0'), style: type.caption.copyWith(color: c.inkMuted)),
          const SizedBox(width: 8),
          Expanded(child: Text(code, style: _codeStyle(type).copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// ───────────────────────── sticky actions ─────────────────────────

class _Sticky extends StatelessWidget {
  const _Sticky({required this.state, required this.code, required this.saved});

  final TwoFactorFlowState state;
  final TextEditingController code;
  final bool saved;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<TwoFactorFlowCubit>();
    return switch (state.step) {
      TwoFactorStep.scan => SeenActionBar(
          actions: [
            SeenButton(
              label: l10n.commonNext,
              expand: true,
              onPressed: state.setup == null ? null : cubit.toCode,
            ),
          ],
        ),
      TwoFactorStep.code => ListenableBuilder(
          listenable: code,
          builder: (context, _) => SeenActionBar(
            actions: [
              SeenButton(
                label: state.verifying ? l10n.secVerifying : l10n.secVerify,
                expand: true,
                loading: state.verifying,
                onPressed: state.verifying || state.locked || code.text.length < 6 ? null : () => cubit.submit(code.text),
              ),
            ],
          ),
        ),
      TwoFactorStep.codes => SeenActionBar(
          actions: [
            SeenButton(
              label: l10n.commonDone,
              expand: true,
              onPressed: saved ? () => Navigator.of(context).pop(true) : null,
            ),
          ],
        ),
    };
  }
}
