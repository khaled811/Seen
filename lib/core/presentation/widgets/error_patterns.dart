// Network / server error patterns (Figma SYS-02 / 02b): an inline section error
// with retry, a "taking longer than usual" notice, an error sheet for a failed
// action, and a full-screen server error.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_vectors.dart';
import 'actions.dart';
import 'chrome.dart';
import 'inline_banner.dart';
import 'screen_background.dart';
import 'sheets.dart';
import 'svg_icon.dart';

/// SYS-02 · 1: a section that failed to load, inside its own card, with Retry.
class SeenInlineError extends StatelessWidget {
  const SeenInlineError({super.key, required this.title, required this.retryLabel, required this.onRetry});

  final String title;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.r22),
        border: Border.all(color: c.border),
        boxShadow: SeenShadows.card,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: SeenRequestStatus.rejected.colors.bg,
                borderRadius: const BorderRadius.all(SeenRadius.r12),
              ),
              child: const SizedBox(width: 40, height: 40, child: Center(child: SeenSvgIcon(SeenVectors.notifAlert, size: 22))),
            ),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: t.label),
            const SizedBox(height: 8),
            Semantics(
              button: true,
              label: retryLabel,
              excludeSemantics: true,
              child: Material(
                color: SeenBrand.violet10,
                borderRadius: const BorderRadius.all(SeenRadius.r14),
                child: InkWell(
                  onTap: onRetry,
                  borderRadius: const BorderRadius.all(SeenRadius.r14),
                  child: SizedBox(
                    height: 40,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Center(child: Text(retryLabel, style: t.label.copyWith(color: SeenBrand.violet))),
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

/// SYS-02 · 2: shows an amber "the server is slow, still trying" notice with
/// Cancel once [loading] has lasted [after]; nothing before that, nothing after
/// loading ends. Owns its timer (cancelled in dispose / when loading stops).
class SeenSlowLoadNotice extends StatefulWidget {
  const SeenSlowLoadNotice({
    super.key,
    required this.loading,
    required this.message,
    required this.cancelLabel,
    this.onCancel,
    this.after = const Duration(seconds: 8),
  });

  final bool loading;
  final String message;
  final String cancelLabel;
  final VoidCallback? onCancel;
  final Duration after;

  @override
  State<SeenSlowLoadNotice> createState() => _SeenSlowLoadNoticeState();
}

class _SeenSlowLoadNoticeState extends State<SeenSlowLoadNotice> {
  Timer? _timer;
  bool _slow = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(covariant SeenSlowLoadNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading) _sync();
  }

  void _sync() {
    _timer?.cancel();
    if (widget.loading) {
      _timer = Timer(widget.after, () {
        if (mounted) setState(() => _slow = true);
      });
    } else {
      _slow = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.loading || !_slow) return const SizedBox.shrink();
    return SeenInlineBanner(
      tone: SeenBannerTone.warn,
      message: widget.message,
      actionLabel: widget.onCancel == null ? null : widget.cancelLabel,
      onAction: widget.onCancel,
    );
  }
}

/// SYS-02 · 3: the sheet for an action that failed. Resolves to `true` when the
/// user chose to retry. [detail] is the small grey line (error code / reference).
Future<bool> showSeenErrorSheet(
  BuildContext context, {
  required String title,
  String? detail,
  required String retryLabel,
  required String cancelLabel,
}) async {
  final retry = await showSeenSheet<bool>(
    context: context,
    title: title,
    subtitle: detail,
    builder: (_) => const SizedBox.shrink(),
    footerBuilder: (sheetContext) => Row(
      children: [
        Expanded(child: SeenButton(label: retryLabel, expand: true, onPressed: () => Navigator.of(sheetContext).pop(true))),
        const SizedBox(width: SeenSpace.s3),
        Expanded(
          child: SeenButton.secondary(label: cancelLabel, expand: true, onPressed: () => Navigator.of(sheetContext).pop(false)),
        ),
      ],
    ),
  );
  return retry ?? false;
}

/// SYS-02b: a whole screen that failed on the server. [detail] carries the error
/// code and reference for support.
class SeenFullScreenError extends StatelessWidget {
  const SeenFullScreenError({
    super.key,
    required this.title,
    required this.body,
    required this.retryLabel,
    required this.onRetry,
    this.supportLabel,
    this.onSupport,
  });

  final String title;
  final String body;
  final String retryLabel;
  final VoidCallback onRetry;
  final String? supportLabel;
  final VoidCallback? onSupport;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    final bad = SeenRequestStatus.rejected.colors;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: bad.bg, shape: BoxShape.circle, border: Border.all(color: c.border)),
                      child: SizedBox(
                        width: 128,
                        height: 128,
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: c.card,
                              borderRadius: const BorderRadius.all(SeenRadius.r20),
                              boxShadow: SeenShadows.stickyBar,
                            ),
                            child: const SizedBox(
                              width: 64,
                              height: 64,
                              child: Center(child: SeenSvgIcon(SeenVectors.notifAlert, size: 36)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(title, textAlign: TextAlign.center, style: t.h1),
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 310),
                    child: Text(body, textAlign: TextAlign.center, style: t.body.copyWith(color: c.inkSecondary)),
                  ),
                  if (supportLabel != null && onSupport != null) ...[
                    const SizedBox(height: 12),
                    SeenTextLink(label: supportLabel!, onTap: onSupport),
                  ],
                ],
              ),
            ),
          ),
        ),
        SeenActionBar(actions: [SeenButton(label: retryLabel, expand: true, onPressed: onRetry)]),
      ],
    );
  }
}

/// A page version of [SeenFullScreenError] (own background), for a route that
/// has nothing else to show.
class SeenFullScreenErrorPage extends StatelessWidget {
  const SeenFullScreenErrorPage({super.key, required this.error});

  final SeenFullScreenError error;

  @override
  Widget build(BuildContext context) => Scaffold(body: SeenScreenBackground(washHeight: 320, child: error));
}
