import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/seen_haptics.dart';
import '../../di/quran_module.dart';
import '../bloc/quran_index_bloc.dart';
import '../bloc/quran_index_event.dart';
import '../bloc/quran_index_state.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_icon_button.dart';
import '../widgets/spiritual_primary_button.dart';
import '../widgets/spiritual_segmented.dart';
import 'last_read_card.dart';
import 'quran_ayah_search_screen.dart';
import 'quran_reader_screen.dart';
import 'quran_row_tile.dart';
import 'quran_search_field.dart';

/// Quran index (Screen 4): surah / juz / bookmark lists and instant search.
///
/// [embedded] is the "المصحف" tab of the Manasik shell (no back button, and
/// the shell's bottom bar is already on screen). [onReturned] runs when the
/// user comes back from the reader, so the caller can refresh anything that
/// shows reading progress (the dashboard).
class QuranIndexScreen extends StatelessWidget {
  const QuranIndexScreen({
    super.key,
    this.embedded = false,
    this.onReturned,
    this.module,
  });

  final bool embedded;
  final VoidCallback? onReturned;
  final QuranModule? module;

  static Route<void> route({VoidCallback? onReturned}) => MaterialPageRoute<void>(
        builder: (_) => QuranIndexScreen(onReturned: onReturned),
      );

  @override
  Widget build(BuildContext context) {
    final m = module ?? QuranModule.instance;
    return BlocProvider(
      create: (_) => QuranIndexBloc(
        loadQuran: m.loadQuran,
        getReaderState: m.getReaderState,
        toggleBookmark: m.toggleBookmark,
      )..add(const QuranIndexStarted()),
      child: SpiritualTheme(
        child: _IndexView(
          embedded: embedded,
          onReturned: onReturned,
          module: m,
        ),
      ),
    );
  }
}

class _IndexView extends StatelessWidget {
  const _IndexView({
    required this.embedded,
    required this.onReturned,
    required this.module,
  });

  final bool embedded;
  final VoidCallback? onReturned;
  final QuranModule module;

  Future<void> _openReader(
    BuildContext context,
    int surah,
    int ayah,
  ) async {
    final bloc = context.read<QuranIndexBloc>();
    await Navigator.of(context).push(
      QuranReaderScreen.route(surah: surah, ayah: ayah, module: module),
    );
    if (bloc.isClosed) return;
    bloc.add(const QuranIndexRefreshed());
    onReturned?.call();
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final bloc = context.read<QuranIndexBloc>();
    return Scaffold(
      backgroundColor: t.bg,
      body: SafeArea(
        bottom: !embedded,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: [
                  _TitleRow(embedded: embedded),
                  const SizedBox(height: SpiritualSpace.s12),
                  QuranSearchField(
                    onChanged: (q) => bloc.add(QuranIndexQueryChanged(q)),
                    onCleared: () =>
                        bloc.add(const QuranIndexQueryChanged('', immediate: true)),
                  ),
                  const SizedBox(height: SpiritualSpace.s12),
                  BlocBuilder<QuranIndexBloc, QuranIndexState>(
                    buildWhen: (p, c) =>
                        (p is QuranIndexLoaded ? p.tab : null) !=
                        (c is QuranIndexLoaded ? c.tab : null),
                    builder: (context, state) => Semantics(
                      label: SpiritualStrings.browseBy,
                      container: true,
                      child: SpiritualSegmented<QuranIndexTab>(
                        options: const [
                          SegmentOption(
                            value: QuranIndexTab.surahs,
                            label: SpiritualStrings.tabSurahs,
                          ),
                          SegmentOption(
                            value: QuranIndexTab.juz,
                            label: SpiritualStrings.tabJuz,
                          ),
                          SegmentOption(
                            value: QuranIndexTab.bookmarks,
                            label: SpiritualStrings.tabBookmarks,
                          ),
                        ],
                        value: state is QuranIndexLoaded
                            ? state.tab
                            : QuranIndexTab.surahs,
                        onChanged: (tab) {
                          SeenHaptics.select();
                          bloc.add(QuranIndexTabChanged(tab));
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: BlocBuilder<QuranIndexBloc, QuranIndexState>(
                builder: (context, state) => switch (state) {
                  QuranIndexLoading() => Center(
                      child: CircularProgressIndicator(color: t.accent),
                    ),
                  QuranIndexFailure() => _Failure(
                      onRetry: () => bloc.add(const QuranIndexStarted()),
                    ),
                  QuranIndexLoaded() => _Content(
                      state: state,
                      onOpen: (s, a) => _openReader(context, s, a),
                      module: module,
                    ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleRow extends StatelessWidget {
  const _TitleRow({required this.embedded});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: SpiritualSpace.minTap,
            child: embedded
                ? null
                : SpiritualIconButton(
                    icon: Icons.arrow_back,
                    semanticLabel: SpiritualStrings.back,
                    onPressed: () => Navigator.maybePop(context),
                  ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                SpiritualStrings.svcQuran,
                textAlign: TextAlign.center,
                style: SpiritualType.title.copyWith(color: t.inkPrimary),
              ),
            ),
          ),
          const SizedBox(width: SpiritualSpace.minTap),
        ],
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.state,
    required this.onOpen,
    required this.module,
  });

  final QuranIndexLoaded state;
  final void Function(int surah, int ayah) onOpen;
  final QuranModule module;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final bloc = context.read<QuranIndexBloc>();
    final lastRead = state.lastRead;
    final rows = state.rows;
    final isBookmarks = state.tab == QuranIndexTab.bookmarks;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (!state.isSearching && lastRead != null) ...[
                LastReadCard(
                  lastRead: lastRead,
                  onResume: () => onOpen(lastRead.surah, lastRead.ayah),
                ),
                const SizedBox(height: SpiritualSpace.s12),
              ],
              if (state.isSearching) ...[
                _AyahSearchRow(
                  query: state.query.trim(),
                  onTap: () => Navigator.of(context).push(
                    QuranAyahSearchScreen.route(
                      query: state.query.trim(),
                      module: module,
                      onOpen: onOpen,
                    ),
                  ),
                ),
                const SizedBox(height: SpiritualSpace.s12),
              ],
            ]),
          ),
        ),
        if (rows.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverToBoxAdapter(
              child: _EmptyCard(
                message: isBookmarks && !state.isSearching
                    ? SpiritualStrings.noBookmarks
                    : SpiritualStrings.noMatches,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: DecoratedSliver(
              decoration: BoxDecoration(
                color: t.surface,
                borderRadius: BorderRadius.circular(SpiritualRadius.tile),
                border: Border.all(color: t.borderCard),
                boxShadow: SpiritualTokens.cardShadow,
              ),
              sliver: SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: SpiritualSpace.s4,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final row = rows[i];
                      final isLast = i == rows.length - 1;
                      Widget tile = DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isLast ? Colors.transparent : t.borderCard,
                            ),
                          ),
                        ),
                        child: QuranRowTile(
                          row: row,
                          onTap: () => onOpen(row.surah, row.ayah),
                        ),
                      );
                      if (isBookmarks) {
                        tile = _SwipeToDelete(
                          row: row,
                          bloc: bloc,
                          child: tile,
                        );
                      }
                      return KeyedSubtree(
                        key: ValueKey('row-${state.tab.name}-${row.surah}-${row.ayah}'),
                        child: tile,
                      );
                    },
                    childCount: rows.length,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SwipeToDelete extends StatelessWidget {
  const _SwipeToDelete({
    required this.row,
    required this.bloc,
    required this.child,
  });

  final QuranIndexRow row;
  final QuranIndexBloc bloc;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Dismissible(
      key: ValueKey('dismiss-${row.surah}-${row.ayah}'),
      direction: DismissDirection.horizontal,
      background: _SwipeBackground(color: t.accentTint, color2: t.accent),
      onDismissed: (_) {
        SeenHaptics.light();
        bloc.add(QuranIndexBookmarkRemoved(row.surah, row.ayah));
        final at = row.bookmarkedAtMs;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: const Text(SpiritualStrings.bookmarkRemoved),
              action: SnackBarAction(
                label: SpiritualStrings.undoAction,
                onPressed: () {
                  if (at != null && !bloc.isClosed) {
                    bloc.add(QuranIndexBookmarkRestored(
                      row.surah,
                      row.ayah,
                      DateTime.fromMillisecondsSinceEpoch(at),
                    ));
                  }
                },
              ),
            ),
          );
      },
      child: child,
    );
  }
}

class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground({required this.color, required this.color2});

  final Color color;
  final Color color2;

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: color,
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Icon(Icons.bookmark_remove_outlined, color: color2),
          ),
        ),
      );
}

class _AyahSearchRow extends StatelessWidget {
  const _AyahSearchRow({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final radius = BorderRadius.circular(SpiritualRadius.button);
    return PressScale(
      onTap: onTap,
      borderRadius: radius,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: t.accentTint, borderRadius: radius),
        child: Row(
          children: [
            Icon(Icons.search, size: 20, color: t.accent),
            const SizedBox(width: SpiritualSpace.s12),
            Expanded(
              child: Text(
                'البحث في نص الآيات عن «$query»',
                style: SpiritualType.label.copyWith(color: t.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(SpiritualRadius.tile),
        border: Border.all(color: t.borderCard),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: SpiritualType.label.copyWith(
          fontWeight: FontWeight.w500,
          color: t.inkBody,
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SpiritualSpace.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              SpiritualStrings.quranLoadFailed,
              style: SpiritualType.bodyStrong.copyWith(color: t.inkPrimary),
            ),
            const SizedBox(height: SpiritualSpace.s16),
            SpiritualPrimaryButton(
              label: SpiritualStrings.retry,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
