import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/arabic_digits.dart';
import '../../di/quran_module.dart';
import '../../domain/entities/ayah_match.dart';
import '../bloc/ayah_search_cubit.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_card.dart';
import '../widgets/spiritual_scaffold.dart';
import '../widgets/spiritual_top_bar.dart';
import 'quran_display_text.dart';

/// Full-text ayah search results ("البحث في نص الآيات عن «…»").
class QuranAyahSearchScreen extends StatelessWidget {
  const QuranAyahSearchScreen({
    super.key,
    required this.query,
    required this.onOpen,
    this.module,
  });

  final String query;

  /// Opens the reader at the tapped ayah.
  final void Function(int surah, int ayah) onOpen;
  final QuranModule? module;

  static Route<void> route({
    required String query,
    required void Function(int surah, int ayah) onOpen,
    QuranModule? module,
  }) =>
      MaterialPageRoute<void>(
        builder: (_) => QuranAyahSearchScreen(
          query: query,
          onOpen: onOpen,
          module: module,
        ),
      );

  @override
  Widget build(BuildContext context) {
    final m = module ?? QuranModule.instance;
    return BlocProvider(
      create: (_) => AyahSearchCubit(query: query, loadQuran: m.loadQuran)..search(),
      child: SpiritualTheme(
        child: Builder(
          builder: (context) => SpiritualScaffold(
            topBar: SpiritualTopBar(
              title: SpiritualStrings.searchResults,
              subtitle: '«$query»',
            ),
            body: BlocBuilder<AyahSearchCubit, AyahSearchState>(
              builder: (context, state) => switch (state) {
                AyahSearchLoading() => Center(
                    child: CircularProgressIndicator(
                      color: SpiritualTokens.of(context).accent,
                    ),
                  ),
                AyahSearchFailure() => const _Message(
                    SpiritualStrings.quranLoadFailed,
                  ),
                AyahSearchResults(:final matches, :final capped) =>
                  matches.isEmpty
                      ? const _Message(SpiritualStrings.noAyahMatches)
                      : _Results(
                          matches: matches,
                          capped: capped,
                          onOpen: onOpen,
                        ),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Center(
      child: Text(
        text,
        style: SpiritualType.label.copyWith(
          fontWeight: FontWeight.w500,
          color: t.inkBody,
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.matches,
    required this.capped,
    required this.onOpen,
  });

  final List<AyahMatch> matches;
  final bool capped;
  final void Function(int surah, int ayah) onOpen;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: matches.length + (capped ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: SpiritualSpace.s10),
      itemBuilder: (context, i) {
        if (i == matches.length) {
          return Padding(
            padding: const EdgeInsets.all(SpiritualSpace.s12),
            child: Text(
              SpiritualStrings.resultsCapped,
              textAlign: TextAlign.center,
              style: SpiritualType.caption.copyWith(color: t.inkMuted),
            ),
          );
        }
        final m = matches[i];
        final ayah = m.ayah;
        final surah = m.surah;
        return PressScale(
          onTap: () {
            Navigator.of(context).pop();
            onOpen(surah.number, ayah.number);
          },
          borderRadius: BorderRadius.circular(SpiritualRadius.card),
          child: SpiritualCard(
            compact: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        toArabicDigits(
                          '${SpiritualStrings.surahWord} ${surah.nameAr} · '
                          '${SpiritualStrings.ayahWord} ${ayah.number}',
                        ),
                        style: SpiritualType.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color: t.accent,
                        ),
                      ),
                    ),
                    Text(
                      toArabicDigits('${SpiritualStrings.pageWord} ${ayah.page}'),
                      style: SpiritualType.micro.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: t.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SpiritualSpace.s8),
                Text(
                  quranDisplayText(ayah.text),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: SpiritualType.quran.copyWith(
                    fontSize: 22,
                    height: 2,
                    color: t.inkPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
