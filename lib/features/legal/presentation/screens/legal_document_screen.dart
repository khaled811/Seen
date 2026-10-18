// Terms of use and privacy policy (Figma AUTH-09 / AUTH-10): the text in Arabic or English
// (independent of the app language), the date it was last updated, and a note when the
// saved copy is shown because the device is offline. Works before sign-in.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_strings.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/inline_banner.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/presentation/widgets/skeleton.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/legal_document.dart';
import '../bloc/legal_cubit.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({super.key, required this.kind, this.createCubit});

  final LegalKind kind;

  /// Test seam; defaults to the DI container.
  final LegalCubit Function(LegalLanguage initial)? createCubit;

  static Route<void> route(LegalKind kind) => MaterialPageRoute<void>(builder: (_) => LegalDocumentScreen(kind: kind));

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final initial = s.isArabic ? LegalLanguage.ar : LegalLanguage.en;
    return BlocProvider(
      create: (_) => (createCubit ?? (l) => InjectionContainer.instance.createLegalCubit(kind, l))(initial)..load(),
      child: Scaffold(
        backgroundColor: SeenColors.of(context).card,
        body: SeenScreenBackground(
          child: SafeArea(
            bottom: false,
            child: BlocBuilder<LegalCubit, LegalState>(
              builder: (context, state) {
                final doc = state.result?.document;
                return Column(
                  children: [
                    SeenScreenHeader(
                      title: kind == LegalKind.terms ? s.termsTitle : s.privacyTitle,
                      subtitle: doc == null ? null : s.legalUpdated(doc.updatedAt),
                    ),
                    Expanded(child: _Body(state: state)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final LegalState state;

  @override
  Widget build(BuildContext context) {
    final s = SeenStrings.of(context);
    final t = SeenType.of(context);
    final c = SeenColors.of(context);
    final cubit = context.read<LegalCubit>();
    final result = state.result;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, SeenSpace.s6),
      children: [
        _LanguageSwitch(selected: state.language, onSelected: cubit.setLanguage),
        const SizedBox(height: 16),
        if (state.status == LegalStatus.loading)
          const ExcludeSemantics(child: _TextSkeleton())
        else if (state.status == LegalStatus.failure)
          Column(
            children: [
              const SizedBox(height: 32),
              Text(s.legalLoadFailed, textAlign: TextAlign.center, style: t.body),
              const SizedBox(height: SeenSpace.s3),
              SeenButton(label: s.retryAction, onPressed: cubit.load),
            ],
          )
        else if (result != null) ...[
          // The text keeps its own language and direction, whatever the app uses.
          Directionality(
            textDirection: result.document.language == LegalLanguage.ar ? TextDirection.rtl : TextDirection.ltr,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final section in result.document.sections) ...[
                  Text(section.heading, style: t.title),
                  const SizedBox(height: 8),
                  Text(section.body, style: t.body.copyWith(color: c.inkSecondary)),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
          if (result.fromCache) SeenInlineBanner(tone: SeenBannerTone.offline, message: s.legalOfflineCopy),
        ],
      ],
    );
  }
}

class _TextSkeleton extends StatelessWidget {
  const _TextSkeleton();

  @override
  Widget build(BuildContext context) {
    return SeenSkeletonGroup(
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            const Align(alignment: AlignmentDirectional.centerStart, child: SeenSkeletonBox(width: 140, height: 16)),
            const SizedBox(height: 10),
            const SeenSkeletonBox(height: 12),
            const SizedBox(height: 6),
            const SeenSkeletonBox(height: 12),
            const SizedBox(height: 6),
            const Align(alignment: AlignmentDirectional.centerStart, child: SeenSkeletonBox(width: 200, height: 12)),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

/// "Arabic | English" (Figma: a pale track with a white selected pill).
class _LanguageSwitch extends StatelessWidget {
  const _LanguageSwitch({required this.selected, required this.onSelected});

  final LegalLanguage selected;
  final ValueChanged<LegalLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    Widget pill(LegalLanguage lang, String label) {
      final on = lang == selected;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          excludeSemantics: true,
          child: Material(
            color: on ? c.card : Colors.transparent,
            elevation: 0,
            borderRadius: const BorderRadius.all(Radius.circular(9)),
            child: InkWell(
              onTap: () => onSelected(lang),
              borderRadius: const BorderRadius.all(Radius.circular(9)),
              child: SizedBox(
                height: 34,
                child: Center(child: Text(label, style: t.label.copyWith(color: on ? c.ink : c.inkSecondary))),
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(color: SeenBrand.violet05, borderRadius: BorderRadius.all(Radius.circular(12))),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            pill(LegalLanguage.ar, 'العربية'),
            const SizedBox(width: 4),
            pill(LegalLanguage.en, 'English'),
          ],
        ),
      ),
    );
  }
}
