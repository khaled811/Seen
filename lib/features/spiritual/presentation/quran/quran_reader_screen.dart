import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/seen_haptics.dart';
import '../../di/quran_module.dart';
import '../bloc/quran_reader_cubit.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_primary_button.dart';
import '../../domain/entities/last_read.dart';
import '../../domain/entities/reader_view_prefs.dart';
import '../../data/services/wakelock_screen_awake.dart';
import '../../domain/services/screen_awake.dart';
import 'auto_read.dart';
import 'ayah_sheets.dart';
import 'quran_ayah_tile.dart';
import 'quran_display_text.dart';
import 'quran_page_reader.dart';
import 'quran_reader_header.dart';

/// Quran reader (Screen 3). Opens in the style the user last chose: the ayah
/// list (one surah) or mushaf pages, and switches between them in place,
/// carrying the reading position across.
class QuranReaderScreen extends StatefulWidget {
  const QuranReaderScreen({
    super.key,
    required this.surah,
    this.ayah = 1,
    this.module,
    this.screenAwake,
  });

  final int surah;
  final int ayah;
  final QuranModule? module;

  /// Keeps the display on during hands-free reading (default: wakelock).
  final ScreenAwake? screenAwake;

  static Route<void> route({
    required int surah,
    int ayah = 1,
    QuranModule? module,
  }) =>
      MaterialPageRoute<void>(
        builder: (_) =>
            QuranReaderScreen(surah: surah, ayah: ayah, module: module),
      );

  @override
  State<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends State<QuranReaderScreen> {
  late final QuranModule _module = widget.module ?? QuranModule.instance;
  ReaderViewPrefs? _prefs;
  late LastRead _at = LastRead(surah: widget.surah, ayah: widget.ayah);

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final r = await _module.loadViewPrefs();
    if (!mounted) return;
    setState(() => _prefs = r.getOrElse((_) => const ReaderViewPrefs()));
  }

  void _show({required bool pages, required LastRead at}) {
    final next = (_prefs ?? const ReaderViewPrefs()).copyWith(pages: pages);
    setState(() {
      _prefs = next;
      _at = at;
    });
    unawaited(_module.saveViewPrefs(next));
  }

  @override
  Widget build(BuildContext context) {
    final prefs = _prefs;
    if (prefs == null) {
      final t = SpiritualTokens.of(context);
      return Scaffold(
        backgroundColor: t.bgReader,
        body: const SizedBox.shrink(),
      );
    }
    if (prefs.pages) {
      return QuranPageReader(
        key: ValueKey('pages-${_at.surah}:${_at.ayah}'),
        start: _at,
        module: _module,
        screenAwake: widget.screenAwake,
        onShowList: (at) => _show(pages: false, at: at),
      );
    }
    return QuranListReader(
      key: ValueKey('list-${_at.surah}:${_at.ayah}'),
      surah: _at.surah,
      ayah: _at.ayah,
      module: _module,
      screenAwake: widget.screenAwake,
      onShowPages: (ayah) =>
          _show(pages: true, at: LastRead(surah: _at.surah, ayah: ayah)),
    );
  }
}

/// The ayah-by-ayah reader for one surah.
///
/// Opens at [ayah]. Persists, the moment they change: the reading position
/// (2 s after scrolling stops, and on exit if the user scrolled), the font
/// size, and bookmarks.
class QuranListReader extends StatelessWidget {
  const QuranListReader({
    super.key,
    required this.surah,
    this.ayah = 1,
    this.module,
    this.onShowPages,
    this.screenAwake,
  });

  final int surah;
  final int ayah;
  final QuranModule? module;

  /// Switch to mushaf pages at this ayah of the surah.
  final ValueChanged<int>? onShowPages;
  final ScreenAwake? screenAwake;

  @override
  Widget build(BuildContext context) {
    final m = module ?? QuranModule.instance;
    return BlocProvider(
      create: (_) => QuranReaderCubit(
        surahNumber: surah,
        loadQuran: m.loadQuran,
        getReaderState: m.getReaderState,
        toggleBookmark: m.toggleBookmark,
        saveLastRead: m.saveLastRead,
        saveFontStep: m.saveFontStep,
      )..load(),
      child: SpiritualTheme(
        child: _ReaderView(
          initialAyah: ayah,
          onShowPages: onShowPages,
          screenAwake: screenAwake ?? const WakelockScreenAwake(),
        ),
      ),
    );
  }
}

class _ReaderView extends StatefulWidget {
  const _ReaderView({
    required this.initialAyah,
    required this.screenAwake,
    this.onShowPages,
  });

  final int initialAyah;
  final ScreenAwake screenAwake;
  final ValueChanged<int>? onShowPages;

  @override
  State<_ReaderView> createState() => _ReaderViewState();
}

class _ReaderViewState extends State<_ReaderView>
    with SingleTickerProviderStateMixin {
  static const _saveDelay = Duration(seconds: 2);

  // Owned here: created in initState, released in dispose.
  final _controller = ScrollController();
  final _listKey = GlobalKey();
  final _itemKeys = <int, GlobalKey>{};
  late final ValueNotifier<int> _topAyah = ValueNotifier(widget.initialAyah);
  final ValueNotifier<int?> _openSheetAyah = ValueNotifier(null);
  Timer? _saveTimer;
  late final QuranReaderCubit _cubit;

  // Hands-free reading: owned here, released in dispose().
  late final AutoScroller _scroller;
  bool _auto = false;
  AutoReadSpeed _speed = AutoReadSpeed.slow;

  /// True once the user has moved the text themselves; only then is leaving
  /// the screen allowed to overwrite the saved reading position.
  bool _userScrolled = false;

  @override
  void initState() {
    super.initState();
    _scroller = AutoScroller(
      vsync: this,
      controller: _controller,
      onEnd: () => _setAuto(false),
    );
    // Captured now: `dispose` must never look the cubit up through a context
    // that is already being torn down.
    _cubit = context.read<QuranReaderCubit>();
  }

  /// Starts or stops the slow downward scroll; the display stays on while it
  /// runs.
  void _setAuto(bool on) {
    if (_auto == on || !mounted) return;
    setState(() => _auto = on);
    if (on) {
      _userScrolled = true; // the position it reaches is worth saving
      _scroller.start(_speed.pixelsPerSecond);
      unawaited(widget.screenAwake.hold());
    } else {
      _scroller.stop();
      unawaited(widget.screenAwake.release());
    }
  }

  @override
  void dispose() {
    if (_auto) unawaited(widget.screenAwake.release());
    _scroller.dispose();
    _saveTimer?.cancel();
    if (_userScrolled && !_cubit.isClosed) {
      _cubit.saveLastRead(_topAyah.value);
    }
    _controller.dispose();
    _topAyah.dispose();
    _openSheetAyah.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(int ayah) => _itemKeys.putIfAbsent(ayah, GlobalKey.new);

  /// First ayah whose bottom edge is below the top of the list.
  int? _computeTopAyah() {
    final listBox = _listKey.currentContext?.findRenderObject();
    if (listBox is! RenderBox || !listBox.attached) return null;
    final listTop = listBox.localToGlobal(Offset.zero).dy;
    int? best;
    for (final entry in _itemKeys.entries) {
      final ctx = entry.value.currentContext;
      final box = ctx?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final bottom = box.localToGlobal(Offset.zero).dy + box.size.height;
      if (bottom > listTop + 8 && (best == null || entry.key < best)) {
        best = entry.key;
      }
    }
    return best;
  }

  void _refreshTopAyah() {
    final top = _computeTopAyah();
    if (top != null && top != _topAyah.value) _topAyah.value = top;
  }

  bool _refreshQueued = false;

  /// Scroll notifications arrive before the frame that lays out the new
  /// offset, so measure after that frame (at most once per frame).
  void _refreshTopAyahAfterFrame() {
    if (_refreshQueued) return;
    _refreshQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshQueued = false;
      if (mounted) _refreshTopAyah();
    });
  }

  bool _onScroll(ScrollNotification n) {
    if (n is ScrollStartNotification || n is ScrollUpdateNotification) {
      if (n is ScrollUpdateNotification && n.dragDetails != null) {
        _userScrolled = true;
        _setAuto(false); // touching the text takes over
      }
      _saveTimer?.cancel();
      _refreshTopAyahAfterFrame();
    } else if (n is ScrollEndNotification) {
      _refreshTopAyahAfterFrame();
      if (_userScrolled) {
        _saveTimer?.cancel();
        _saveTimer = Timer(_saveDelay, () {
          if (!mounted || _cubit.isClosed) return;
          _refreshTopAyah(); // layout is settled by now
          _cubit.saveLastRead(_topAyah.value);
        });
      }
    }
    return false;
  }

  /// Brings [ayah] to the top. Heights vary with the text, so jump to an
  /// estimate, then walk until the target has been built and snap to it.
  Future<void> _scrollToAyah(int ayah, double fontSize) async {
    if (ayah <= 1 || !mounted) return;
    final estimate = (ayah - 1) * (fontSize * 2.05 * 2 + 82);
    for (var i = 0; i < 40 && mounted; i++) {
      if (!mounted) return;
      final ctx = _keyFor(ayah).currentContext;
      if (ctx != null) {
        // `ctx` was read from its GlobalKey one line above, after the
        // `mounted` check, with no await in between.
        // ignore: use_build_context_synchronously
        await Scrollable.ensureVisible(ctx,
            alignment: 0, duration: Duration.zero);
        // We just put this ayah at the top; no need to measure.
        if (mounted) _topAyah.value = ayah;
        return;
      }
      if (!_controller.hasClients) {
        await WidgetsBinding.instance.endOfFrame;
        continue;
      }
      final pos = _controller.position;
      // Measure the ayahs that are built to learn the average height, then
      // jump by the number of ayahs still to go (not a fixed step).
      var builtMin = 1 << 30;
      var builtMax = 0;
      var heightSum = 0.0;
      var heightCount = 0;
      for (final e in _itemKeys.entries) {
        final box = e.value.currentContext?.findRenderObject();
        if (box is! RenderBox || !box.attached) continue;
        if (e.key < builtMin) builtMin = e.key;
        if (e.key > builtMax) builtMax = e.key;
        heightSum += box.size.height;
        heightCount++;
      }
      final double target;
      if (heightCount == 0) {
        target = estimate;
      } else {
        final avg = heightSum / heightCount;
        final floor = pos.viewportDimension * 0.9;
        target = ayah > builtMax
            ? pos.pixels +
                ((ayah - builtMax) * avg).clamp(floor, double.infinity)
            : pos.pixels -
                ((builtMin - ayah) * avg).clamp(floor, double.infinity);
      }
      _controller.jumpTo(target.clamp(0.0, pos.maxScrollExtent));
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Future<void> _changeFont(bool grow, QuranReaderLoaded state) async {
    SeenHaptics.select();
    final settle = SpiritualMotion.of(context, SpiritualMotion.fast) +
        const Duration(milliseconds: 40);
    final anchor = _topAyah.value;
    if (grow) {
      await _cubit.increaseFont();
    } else {
      await _cubit.decreaseFont();
    }
    // Keep the ayah the user was reading in place once the text has resized.
    await Future<void>.delayed(settle);
    if (!mounted) return;
    final latest = _cubit.state;
    if (latest is QuranReaderLoaded) {
      await _scrollToAyah(anchor, latest.fontSize);
    }
  }

  Future<void> _openTafsir(QuranReaderLoaded state, int index) async {
    final ayah = state.ayahs[index];
    _openSheetAyah.value = ayah.number;
    await showAyahTafsirSheet(context, surah: state.surah, ayah: ayah);
    if (mounted) _openSheetAyah.value = null;
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return BlocConsumer<QuranReaderCubit, QuranReaderState>(
      listenWhen: (p, c) =>
          (p is QuranReaderLoading && c is QuranReaderLoaded) ||
          (p is QuranReaderLoaded &&
              c is QuranReaderLoaded &&
              c.saveSeq != p.saveSeq),
      listener: (context, state) {
        if (state is! QuranReaderLoaded) return;
        if (state.saveFailed) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text(SpiritualStrings.saveFailed)),
            );
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: t.bgReader,
          body: SafeArea(
            child: switch (state) {
              QuranReaderLoading() => Center(
                  child: CircularProgressIndicator(color: t.accent),
                ),
              QuranReaderFailure() => _Failure(onRetry: _cubit.load),
              QuranReaderLoaded() => _loaded(context, state),
            },
          ),
        );
      },
    );
  }

  Widget _loaded(BuildContext context, QuranReaderLoaded state) {
    final basmala = state.basmala;
    final offset = basmala == null ? 0 : 1;
    // First frame after load: go to the requested ayah.
    if (!_didInitialScroll) {
      _didInitialScroll = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToAyah(widget.initialAyah, state.fontSize),
      );
    }
    return Column(
      children: [
        ValueListenableBuilder<int>(
          valueListenable: _topAyah,
          builder: (context, top, _) {
            final ayah =
                state.ayahs[(top - 1).clamp(0, state.ayahs.length - 1)];
            return QuranReaderHeader(
              surah: state.surah,
              page: ayah.page,
              bookmarked: state.bookmarked.contains(ayah.number),
              fontSize: state.fontSize,
              canShrink: state.canShrink,
              canGrow: state.canGrow,
              onBookmark: () {
                SeenHaptics.light();
                _cubit.toggleBookmark(top);
              },
              onSmaller: () => _changeFont(false, state),
              onBigger: () => _changeFont(true, state),
              autoRunning: _auto,
              onAuto: () => _setAuto(!_auto),
              onShowPages: widget.onShowPages == null
                  ? null
                  : () => widget.onShowPages!(top),
            );
          },
        ),
        AnimatedSize(
          duration: SpiritualMotion.of(context, SpiritualMotion.base),
          alignment: Alignment.topCenter,
          child: _auto
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpiritualSpace.s16,
                    SpiritualSpace.s8,
                    SpiritualSpace.s16,
                    SpiritualSpace.s4,
                  ),
                  child: AutoReadSpeedPicker(
                    speed: _speed,
                    onChanged: (v) {
                      setState(() => _speed = v);
                      _scroller.changeSpeed(v.pixelsPerSecond);
                    },
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: ListView.builder(
              key: _listKey,
              controller: _controller,
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
              itemCount: state.ayahs.length + offset,
              itemBuilder: (context, i) {
                if (basmala != null && i == 0) {
                  return _Basmala(text: basmala);
                }
                final index = i - offset;
                final ayah = state.ayahs[index];
                return KeyedSubtree(
                  key: _keyFor(ayah.number),
                  child: QuranAyahTile(
                    ayah: ayah,
                    fontSize: state.fontSize,
                    bookmarked: state.bookmarked.contains(ayah.number),
                    openSheetAyah: _openSheetAyah,
                    onOpenSheet: () => _openTafsir(state, index),
                    onLongPress: () {
                      SeenHaptics.select();
                      showAyahCopySheet(
                        context,
                        surah: state.surah,
                        ayah: ayah,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  bool _didInitialScroll = false;
}

class _Basmala extends StatelessWidget {
  const _Basmala({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
      child: Text(
        quranDisplayText(text),
        textAlign: TextAlign.center,
        style: SpiritualType.quran.copyWith(
          fontSize: 26,
          height: 2,
          color: t.inkPrimary,
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry});

  final Future<void> Function() onRetry;

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
              onPressed: () => onRetry(),
            ),
          ],
        ),
      ),
    );
  }
}
