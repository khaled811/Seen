import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/arabic_digits.dart';
import '../../core/seen_haptics.dart';
import '../../di/quran_module.dart';
import '../../domain/entities/last_read.dart';
import '../../domain/entities/quran_data.dart';
import '../bloc/quran_page_cubit.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_primary_button.dart';
import '../../data/services/wakelock_screen_awake.dart';
import '../../domain/services/screen_awake.dart';
import 'auto_read.dart';
import 'quran_display_text.dart';

/// Colours of a mushaf page, taken from the app's theme tokens.
class MushafPalette {
  const MushafPalette({
    required this.bg,
    required this.text,
    required this.muted,
    required this.marker,
    required this.bannerFill,
    required this.bannerBorder,
    required this.accent,
  });

  final Color bg;
  final Color text;
  final Color muted;
  final Color marker;
  final Color bannerFill;
  final Color bannerBorder;
  final Color accent;

  static MushafPalette paper(SpiritualTokens t) => MushafPalette(
        bg: t.bgReader,
        text: t.inkPrimary,
        muted: t.inkMuted,
        marker: t.octagonStroke,
        bannerFill: t.surface,
        bannerBorder: t.readerDivider,
        accent: t.accent,
      );
}

/// Quran as mushaf pages (604): swipe to turn, page number at the bottom,
/// surah and juz at the top. Opens on the page holding [start].
class QuranPageReader extends StatelessWidget {
  const QuranPageReader({
    super.key,
    required this.start,
    required this.onShowList,
    this.module,
    this.screenAwake,
  });

  final LastRead start;

  /// Switch to the ayah list at this position.
  final void Function(LastRead position) onShowList;
  final QuranModule? module;

  /// Keeps the display on during hands-free reading.
  final ScreenAwake? screenAwake;

  @override
  Widget build(BuildContext context) {
    final m = module ?? QuranModule.instance;
    return BlocProvider(
      create: (_) => QuranPageCubit(
        start: start,
        loadQuran: m.loadQuran,
        getReaderState: m.getReaderState,
        toggleBookmark: m.toggleBookmark,
        saveLastRead: m.saveLastRead,
        saveFontStep: m.saveFontStep,
      )..load(),
      child: SpiritualTheme(
        child: _PageReaderView(
          onShowList: onShowList,
          screenAwake: screenAwake ?? const WakelockScreenAwake(),
        ),
      ),
    );
  }
}

class _PageReaderView extends StatefulWidget {
  const _PageReaderView({required this.onShowList, required this.screenAwake});

  final void Function(LastRead position) onShowList;
  final ScreenAwake screenAwake;

  @override
  State<_PageReaderView> createState() => _PageReaderViewState();
}

class _PageReaderViewState extends State<_PageReaderView> {
  // Owned here: created when the pages first appear, disposed in dispose().
  PageController? _controller;
  late final QuranPageCubit _cubit;

  bool _auto = false;
  AutoReadSpeed _speed = AutoReadSpeed.slow;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<QuranPageCubit>();
  }

  @override
  void dispose() {
    if (_auto) unawaited(widget.screenAwake.release());
    _controller?.dispose();
    super.dispose();
  }

  /// Starts or stops hands-free reading; the display stays on while it runs.
  void _setAuto(bool on) {
    if (_auto == on || !mounted) return;
    setState(() => _auto = on);
    unawaited(on ? widget.screenAwake.hold() : widget.screenAwake.release());
  }

  /// The current page has been read: turn to the next, or stop at the end.
  void _pageFinished(int page, int pageCount) {
    if (!_auto || !mounted) return;
    if (page >= pageCount) {
      _setAuto(false);
      return;
    }
    _controller?.nextPage(
      duration: SpiritualMotion.of(context, SpiritualMotion.slow),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final palette = MushafPalette.paper(t);
    return BlocConsumer<QuranPageCubit, QuranPageState>(
      listenWhen: (p, c) =>
          p is QuranPageLoaded && c is QuranPageLoaded && c.saveSeq != p.saveSeq,
      listener: (context, state) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text(SpiritualStrings.saveFailed)),
          );
      },
      buildWhen: (p, c) =>
          p.runtimeType != c.runtimeType ||
          (p is QuranPageLoaded &&
              c is QuranPageLoaded &&
              (p.page != c.page ||
                  p.fontStep != c.fontStep ||
                  p.bookmarked != c.bookmarked)),
      builder: (context, state) {
        return Scaffold(
          backgroundColor: palette.bg,
          body: SafeArea(
            child: switch (state) {
              QuranPageLoading() => Center(
                  child: CircularProgressIndicator(color: palette.accent),
                ),
              QuranPageFailure() => _Failure(onRetry: _cubit.load, palette: palette),
              QuranPageLoaded() => _loaded(context, state, palette),
            },
          ),
        );
      },
    );
  }

  Widget _loaded(BuildContext context, QuranPageLoaded s, MushafPalette p) {
    // RTL: page 1 on the right; the next page lies to the left.
    final controller = _controller ??= PageController(initialPage: s.page - 1);
    final first = s.data.ayahsOnPage(s.page).first;
    final pageCount = s.data.pages.length;
    return Column(
      children: [
        _TopBar(
          palette: p,
          surah: s.data.surah(first.surah).nameAr,
          juz: first.juz,
          bookmarked: s.bookmarked,
          auto: _auto,
          onBack: () => Navigator.maybePop(context),
          onList: () {
            final at = _cubit.position;
            if (at != null) widget.onShowList(at);
          },
          onAuto: () => _setAuto(!_auto),
          onBookmark: () {
            SeenHaptics.light();
            _cubit.toggleBookmark();
          },
        ),
        AnimatedSize(
          duration: SpiritualMotion.of(context, SpiritualMotion.base),
          alignment: Alignment.topCenter,
          child: _auto
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SpiritualSpace.s16,
                    SpiritualSpace.s4,
                    SpiritualSpace.s16,
                    SpiritualSpace.s8,
                  ),
                  child: AutoReadSpeedPicker(
                    speed: _speed,
                    onChanged: (v) => setState(() => _speed = v),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
        Expanded(
          // Touching the page by hand takes over: hands-free reading stops.
          child: NotificationListener<ScrollStartNotification>(
            onNotification: (n) {
              if (n.dragDetails != null) _setAuto(false);
              return false;
            },
            child: PageView.builder(
              controller: controller,
              itemCount: pageCount,
              onPageChanged: (i) => _cubit.onPageChanged(i + 1),
              itemBuilder: (context, i) => _AutoPage(
                active: _auto && s.page == i + 1,
                pixelsPerSecond: _speed.pixelsPerSecond,
                onFinished: () => _pageFinished(i + 1, pageCount),
                child: MushafPageView(
                  data: s.data,
                  page: i + 1,
                  fontSize: s.fontSize,
                  palette: p,
                ),
              ),
            ),
          ),
        ),
        _BottomBar(
          palette: p,
          page: s.page,
          canShrink: s.canShrink,
          canGrow: s.canGrow,
          onSmaller: () {
            SeenHaptics.select();
            _cubit.decreaseFont();
          },
          onBigger: () {
            SeenHaptics.select();
            _cubit.increaseFont();
          },
        ),
      ],
    );
  }
}

/// Scrolls one page's text down at a steady pace while [active], then reports
/// [onFinished]. The pace carries on for a while after the end of the text, so
/// a page that fits the screen is still shown for a reading time before it
/// turns.
class _AutoPage extends StatefulWidget {
  const _AutoPage({
    required this.active,
    required this.pixelsPerSecond,
    required this.onFinished,
    required this.child,
  });

  final bool active;
  final double pixelsPerSecond;
  final VoidCallback onFinished;
  final Widget child;

  @override
  State<_AutoPage> createState() => _AutoPageState();
}

class _AutoPageState extends State<_AutoPage>
    with SingleTickerProviderStateMixin {
  // Owned here: both created in initState, released in dispose().
  final _controller = ScrollController();
  late final AutoScroller _scroller;

  @override
  void initState() {
    super.initState();
    _scroller = AutoScroller(
      vsync: this,
      controller: _controller,
      onEnd: () => widget.onFinished(),
    );
    if (widget.active) _scroller.start(widget.pixelsPerSecond);
  }

  @override
  void didUpdateWidget(_AutoPage old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      if (_controller.hasClients) _controller.jumpTo(0);
      _scroller.start(widget.pixelsPerSecond);
    } else if (!widget.active && old.active) {
      _scroller.stop();
    } else if (widget.active) {
      _scroller.changeSpeed(widget.pixelsPerSecond);
    }
  }

  @override
  void dispose() {
    _scroller.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        _scroller.tail = box.maxHeight * 0.6;
        return SingleChildScrollView(
          controller: _controller,
          padding: const EdgeInsets.fromLTRB(
            SpiritualSpace.s20,
            SpiritualSpace.s8,
            SpiritualSpace.s20,
            SpiritualSpace.s16,
          ),
          child: widget.child,
        );
      },
    );
  }
}

/// The text of one mushaf page: surah banners with the basmala where a surah
/// begins, and the ayahs as continuous justified text with a numbered marker
/// after each. Place it in a scroll view: it is as tall as its text.
class MushafPageView extends StatelessWidget {
  const MushafPageView({
    super.key,
    required this.data,
    required this.page,
    required this.fontSize,
    required this.palette,
  });

  final QuranData data;
  final int page;
  final double fontSize;
  final MushafPalette palette;

  @override
  Widget build(BuildContext context) {
    final ayahs = data.ayahsOnPage(page);
    final children = <Widget>[];
    var run = <InlineSpan>[];

    void flush() {
      if (run.isEmpty) return;
      children.add(
        SizedBox(
          width: double.infinity,
          child: Text.rich(
            TextSpan(children: run),
            textAlign: TextAlign.justify,
            style: SpiritualType.quran.copyWith(
              fontSize: fontSize,
              height: 1.8,
              color: palette.text,
            ),
          ),
        ),
      );
      run = <InlineSpan>[];
    }

    for (final a in ayahs) {
      if (a.number == 1) {
        flush();
        children.add(_SurahBanner(
          name: '${SpiritualStrings.surahWord} ${data.surah(a.surah).nameAr}',
          palette: palette,
        ));
        if (a.surah != 1 && a.surah != 9) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: SpiritualSpace.s4),
            child: Text(
              quranDisplayText(data.ayah(1, 1)!.text),
              textAlign: TextAlign.center,
              style: SpiritualType.quran.copyWith(
                fontSize: fontSize,
                height: 1.8,
                color: palette.text,
              ),
            ),
          ));
        }
      }
      run
        ..add(TextSpan(text: '${quranDisplayText(a.text)} '))
        ..add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _AyahMarker(
            number: a.number,
            size: fontSize * 0.95,
            color: palette.marker,
            textColor: palette.text,
          ),
        ))
        ..add(const TextSpan(text: ' '));
    }
    flush();

    return Semantics(
      label: '${SpiritualStrings.pageWord} ${toArabicDigits(page)}',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _SurahBanner extends StatelessWidget {
  const _SurahBanner({required this.name, required this.palette});

  final String name;
  final MushafPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: SpiritualSpace.s8),
      padding: const EdgeInsets.symmetric(vertical: SpiritualSpace.s8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.bannerFill,
        borderRadius: BorderRadius.circular(SpiritualRadius.control),
        border: Border.all(color: palette.bannerBorder),
      ),
      child: Semantics(
        header: true,
        child: Text(
          name,
          style: SpiritualType.section.copyWith(color: palette.text),
        ),
      ),
    );
  }
}

/// End-of-ayah marker: a ring with the ayah number.
class _AyahMarker extends StatelessWidget {
  const _AyahMarker({
    required this.number,
    required this.size,
    required this.color,
    required this.textColor,
  });

  final int number;
  final double size;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.4),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Text(
            toArabicDigits(number),
            style: TextStyle(
              fontFamily: SpiritualFonts.ui,
              fontSize: size * 0.45,
              fontWeight: FontWeight.w700,
              height: 1,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      onTap: onTap,
      scale: 0.92,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(24),
      child: Opacity(
        opacity: onTap == null ? 0.4 : 1,
        child: SizedBox(
          width: SpiritualSpace.minTap,
          height: SpiritualSpace.minTap,
          child: Icon(icon, size: 24, color: color),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.palette,
    required this.surah,
    required this.juz,
    required this.bookmarked,
    required this.auto,
    required this.onBack,
    required this.onList,
    required this.onAuto,
    required this.onBookmark,
  });

  final MushafPalette palette;
  final String surah;
  final int juz;
  final bool bookmarked;
  final bool auto;
  final VoidCallback onBack;
  final VoidCallback onList;
  final VoidCallback onAuto;
  final VoidCallback onBookmark;

  @override
  Widget build(BuildContext context) {
    final label = SpiritualType.caption.copyWith(
      color: palette.muted,
      fontWeight: FontWeight.w700,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s4),
      child: Column(
        children: [
          Row(
            children: [
              _BarButton(
                icon: Icons.arrow_back,
                label: SpiritualStrings.back,
                color: palette.text,
                onTap: onBack,
              ),
              const Spacer(),
              _BarButton(
                icon: bookmarked ? Icons.bookmark : Icons.bookmark_border,
                label: SpiritualStrings.saveReadingPosition,
                color: palette.accent,
                onTap: onBookmark,
              ),
              _BarButton(
                icon: auto ? Icons.pause_circle_outline : Icons.play_circle_outline,
                label: auto
                    ? SpiritualStrings.autoStop
                    : SpiritualStrings.autoStart,
                color: auto ? palette.accent : palette.text,
                onTap: onAuto,
              ),
              _BarButton(
                icon: Icons.view_agenda_outlined,
                label: SpiritualStrings.readerListView,
                color: palette.text,
                onTap: onList,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SpiritualSpace.s16,
              vertical: SpiritualSpace.s2,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  toArabicDigits('${SpiritualStrings.juzWord} $juz'),
                  style: label,
                ),
                Text(surah, style: label),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.palette,
    required this.page,
    required this.canShrink,
    required this.canGrow,
    required this.onSmaller,
    required this.onBigger,
  });

  final MushafPalette palette;
  final int page;
  final bool canShrink;
  final bool canGrow;
  final VoidCallback onSmaller;
  final VoidCallback onBigger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SpiritualSpace.s8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _BarButton(
            icon: Icons.text_decrease,
            label: SpiritualStrings.fontSmaller,
            color: palette.text,
            onTap: canShrink ? onSmaller : null,
          ),
          const SizedBox(width: SpiritualSpace.s16),
          Semantics(
            label: '${SpiritualStrings.pageWord} ${toArabicDigits(page)}',
            child: ExcludeSemantics(
              child: Container(
                constraints: const BoxConstraints(minWidth: 72, minHeight: 36),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(SpiritualRadius.pill),
                  border: Border.all(color: palette.bannerBorder, width: 1.5),
                ),
                child: Text(
                  toArabicDigits(page),
                  style: SpiritualType.label.copyWith(color: palette.text),
                ),
              ),
            ),
          ),
          const SizedBox(width: SpiritualSpace.s16),
          _BarButton(
            icon: Icons.text_increase,
            label: SpiritualStrings.fontBigger,
            color: palette.text,
            onTap: canGrow ? onBigger : null,
          ),
        ],
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.onRetry, required this.palette});

  final Future<void> Function() onRetry;
  final MushafPalette palette;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            SpiritualStrings.quranLoadFailed,
            style: SpiritualType.bodyStrong.copyWith(color: palette.text),
          ),
          const SizedBox(height: SpiritualSpace.s16),
          SpiritualPrimaryButton(
            label: SpiritualStrings.retry,
            onPressed: () => onRetry(),
          ),
        ],
      ),
    );
  }
}
