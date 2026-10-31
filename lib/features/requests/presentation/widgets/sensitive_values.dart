// Sensitive traveler values on a request (design/gaps PRIV-01..03): hidden by default, shown
// one at a time for 30 seconds after an audited reveal, never kept. The block is additive: until
// the values are loaded (or if they cannot be) nothing is drawn, so the screen is unchanged.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/platform/secure_screen.dart';
import '../../../../core/preferences/reveal_intro_store.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/reveal/reveal_controller.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/countdown_pill.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/sheets.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/sensitive_value.dart';
import '../../domain/repositories/sensitive_values_repository.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';

/// What the screen knows about a request's sensitive values, and the one reveal in progress.
class SensitiveValuesModel extends ChangeNotifier {
  SensitiveValuesModel({required this.requestId, required SensitiveValuesRepository repository, RevealIntroStore? introStore})
      : _repository = repository,
        _intro = introStore ?? RevealIntroStore() {
    reveal = RevealController(fetch: _fetch, onSecureChanged: SecureScreen.set)..addListener(notifyListeners);
    _load();
  }

  final String requestId;
  final SensitiveValuesRepository _repository;
  final RevealIntroStore _intro;
  late final RevealController reveal;

  List<TravelerSensitive> travelers = const [];
  bool _disposed = false;

  Future<void> _load() async {
    final result = await _repository.forRequest(requestId);
    if (_disposed) {
      return;
    }
    result.fold((_) {}, (list) {
      travelers = list;
      notifyListeners();
    });
  }

  Future<String> _fetch(String id) async {
    final result = await _repository.reveal(id);
    return result.fold((f) => throw _revealFailure(f), (value) => value);
  }

  Object _revealFailure(Failure failure) {
    if (failure is ForbiddenFailure || (failure is ServerFailure && failure.code == 'permission_denied')) {
      return RevealForbidden();
    }
    if (failure is ServerFailure && failure.code == 'too_many_attempts') {
      final minutes = failure.details['minutes'];
      final m = minutes is num ? minutes.toInt() : int.tryParse('$minutes');
      return RevealRateLimited(Duration(minutes: m ?? 60));
    }
    return StateError('reveal failed');
  }

  /// The traveler at [index] (the request's order), or null when the values are not loaded.
  TravelerSensitive? traveler(int index) => index >= 0 && index < travelers.length ? travelers[index] : null;

  Future<bool> introSeen() => _intro.seen();

  Future<void> markIntroSeen() => _intro.markSeen();

  @override
  void dispose() {
    _disposed = true;
    reveal
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}

/// Owns the [SensitiveValuesModel] for one request screen and shares it with the blocks below.
class SensitiveValuesScope extends StatefulWidget {
  const SensitiveValuesScope({super.key, required this.requestId, required this.child, this.repository, this.introStore});

  final String requestId;
  final Widget child;

  /// Test seam; defaults to the DI container.
  final SensitiveValuesRepository? repository;
  final RevealIntroStore? introStore;

  static SensitiveValuesModel? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ScopeData>()?.notifier;

  @override
  State<SensitiveValuesScope> createState() => _SensitiveValuesScopeState();
}

class _SensitiveValuesScopeState extends State<SensitiveValuesScope> {
  // Created here, disposed in dispose().
  late final SensitiveValuesModel _model = SensitiveValuesModel(
    requestId: widget.requestId,
    repository: widget.repository ?? InjectionContainer.instance.sensitiveValuesRepository,
    introStore: widget.introStore,
  );

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _ScopeData(notifier: _model, child: widget.child);
}

class _ScopeData extends InheritedNotifier<SensitiveValuesModel> {
  const _ScopeData({required SensitiveValuesModel notifier, required super.child}) : super(notifier: notifier);
}

/// The sensitive values of the traveler at [index], with their reveal controls.
class TravelerSensitiveBlock extends StatelessWidget {
  const TravelerSensitiveBlock({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final model = SensitiveValuesScope.maybeOf(context);
    final traveler = model?.traveler(index);
    if (model == null || traveler == null || traveler.values.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final reveal = model.reveal;
    final blocked = reveal.blockedFor;
    // The screen-level messages (limit, failure, no permission) show once, on the first traveler.
    final first = model.travelers.indexWhere((t) => t.values.isNotEmpty) == index;
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final value in traveler.values) _ValueRow(model: model, value: value),
          if (first && blocked != null) ...[
            const SizedBox(height: 8),
            SeenInlineBanner(tone: SeenBannerTone.warn, message: SeenStrings.of(context).digits(l10n.privRateLimited((blocked.inSeconds / 60).ceil()))),
          ],
          if (first && reveal.failed) ...[
            const SizedBox(height: 8),
            SeenInlineBanner(tone: SeenBannerTone.error, message: '${l10n.privLoadErrorTitle}. ${l10n.privLoadErrorBody}'),
          ],
          if (reveal.forbidden) ...[
            if (first) ...[
              const SizedBox(height: 8),
              _NoPermission(title: l10n.privNoPermissionTitle, body: l10n.privNoPermissionBody),
            ],
          ] else ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(SeenIcons.lock, size: 12, color: c.inkSecondary),
                const SizedBox(width: 6),
                Expanded(child: Text(l10n.privMaskedNote, style: type.caption.copyWith(color: c.inkSecondary))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.model, required this.value});

  final SensitiveValuesModel model;
  final SensitiveValue value;

  Future<void> _reveal(BuildContext context) async {
    if (!await model.introSeen()) {
      if (!context.mounted) {
        return;
      }
      final go = await showSeenSheet<bool>(
        context: context,
        title: AppLocalizations.of(context)!.privIntroTitle,
        subtitle: AppLocalizations.of(context)!.privIntroSub,
        builder: (_) => const _IntroBody(),
        footerBuilder: (ctx) => _IntroActions(
          onReveal: () => Navigator.of(ctx).pop(true),
          onCancel: () => Navigator.of(ctx).pop(false),
        ),
      );
      if (go != true) {
        return;
      }
      await model.markIntroSeen();
    }
    await model.reveal.reveal(value.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final reveal = model.reveal;
    final clear = reveal.valueOf(value.id);
    final loading = reveal.isLoading(value.id);
    final disabled = reveal.forbidden || reveal.blockedFor != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value.label, style: type.caption.copyWith(color: c.inkSecondary)),
                const SizedBox(height: 2),
                if (loading)
                  const SeenSkeletonBox(width: 118, height: 14)
                else if (clear != null)
                  // Not selectable: a sensitive value is never copyable.
                  Directionality(textDirection: TextDirection.ltr, child: Text(clear, style: type.bodyStrong))
                else
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(value.masked, style: type.body.copyWith(color: c.inkSecondary, letterSpacing: 1.1)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (clear != null) ...[
            CountdownPill(
              seconds: reveal.secondsLeft,
              text: SeenStrings.of(context).digits(l10n.privCountdown(reveal.secondsLeft)),
              semanticLabel: SeenStrings.of(context).digits(l10n.privCountdownA11y(reveal.secondsLeft)),
              announce: reveal.secondsLeft == 10,
            ),
            const SizedBox(width: 8),
            SeenButton.secondary(label: l10n.privHide, size: SeenButtonSize.small, icon: SeenIcons.eyeSlash, onPressed: reveal.hide),
          ] else
            SeenIconButton(
              icon: reveal.forbidden ? SeenIcons.lock : SeenIcons.eye,
              semanticLabel: reveal.forbidden ? l10n.privNoPermissionTitle : (loading ? l10n.privRevealing : l10n.privReveal),
              onPressed: disabled || loading ? null : () => _reveal(context),
            ),
        ],
      ),
    );
  }
}

class _NoPermission extends StatelessWidget {
  const _NoPermission({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(color: c.accentSoft, borderRadius: const BorderRadius.all(SeenRadius.lg)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(SeenIcons.lock, size: 18, color: c.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: type.label),
                  const SizedBox(height: 2),
                  Text(body, style: type.caption.copyWith(color: c.inkSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroBody extends StatelessWidget {
  const _IntroBody();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Column(
        children: [
          _IntroLine(icon: SeenIcons.shield, title: l10n.privIntroLoggedTitle, body: l10n.privIntroLoggedBody),
          _IntroLine(icon: SeenIcons.timer, title: l10n.privIntroTimerTitle, body: l10n.privIntroTimerBody),
          _IntroLine(icon: SeenIcons.lock, title: l10n.privIntroCopyTitle, body: l10n.privIntroCopyBody),
        ],
      ),
    );
  }
}

class _IntroLine extends StatelessWidget {
  const _IntroLine({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(color: c.accentSoft, borderRadius: const BorderRadius.all(SeenRadius.r12)),
            child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20, color: c.accent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: type.bodyStrong),
                Text(body, style: type.caption.copyWith(color: c.inkSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IntroActions extends StatelessWidget {
  const _IntroActions({required this.onReveal, required this.onCancel});

  final VoidCallback onReveal;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          Expanded(child: SeenButton.secondary(label: l10n.commonCancel, expand: true, onPressed: onCancel)),
          const SizedBox(width: 10),
          Expanded(child: SeenButton(label: l10n.privReveal, icon: SeenIcons.eye, expand: true, onPressed: onReveal)),
        ],
      ),
    );
  }
}
