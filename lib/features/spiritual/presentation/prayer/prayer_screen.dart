import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/seen_haptics.dart';
import '../../core/time_format.dart';
import '../../di/prayer_module.dart';
import '../../domain/entities/location_fix.dart';
import '../../domain/entities/prayer_id.dart';
import '../bloc/prayer_bloc.dart';
import '../bloc/prayer_event.dart';
import '../bloc/prayer_state.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_icon_button.dart';
import '../widgets/spiritual_segmented.dart';
import '../widgets/spiritual_top_bar.dart';
import 'horizon_card.dart';
import 'month_table.dart';
import 'prayer_rows_card.dart';
import 'prayer_settings_sheet.dart';
import 'prayer_texts.dart';

/// Prayer times and adhan (Screen 5).
class PrayerScreen extends StatelessWidget {
  const PrayerScreen({super.key, this.module});

  final PrayerModule? module;

  static Route<void> route({PrayerModule? module}) =>
      MaterialPageRoute<void>(builder: (_) => PrayerScreen(module: module));

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          PrayerBloc(module ?? PrayerModule.instance)..add(const PrayerStarted()),
      child: const SpiritualTheme(child: _PrayerView()),
    );
  }
}

class _PrayerView extends StatefulWidget {
  const _PrayerView();

  @override
  State<_PrayerView> createState() => _PrayerViewState();
}

class _PrayerViewState extends State<_PrayerView> {
  // Owned here: released in dispose.
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// In month view, bring today's row near the top (rows have a fixed height).
  void _scrollToToday(PrayerLoaded s) {
    final rowExtent = monthRowExtentOf(context);
    final month = s.month;
    if (month == null) return;
    final idx = MonthTableSliver.todayIndex(month, s.now);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      if (idx == null) {
        _controller.jumpTo(0);
        return;
      }
      // The header is pinned outside this scroll view, so only the table
      // padding and its heading row sit above the first day.
      // The heading row is pinned, so it does not scroll away: row i starts
      // at 8 (table padding) + heading + i rows; show it two rows below the
      // pinned heading, for context.
      final target = 8 + (idx * rowExtent) - rowExtent * 2;
      _controller.jumpTo(
        target.clamp(0.0, _controller.position.maxScrollExtent),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return BlocConsumer<PrayerBloc, PrayerState>(
      listenWhen: (p, c) =>
          c is PrayerLoaded &&
          (p is! PrayerLoaded ||
              c.saveSeq != p.saveSeq ||
              (c.view != p.view || c.date != p.date) && c.view == PrayerView.month),
      listener: (context, state) {
        if (state is! PrayerLoaded) return;
        if (state.saveFailed) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(content: Text(SpiritualStrings.saveFailed)),
            );
        }
        if (state.view == PrayerView.month) _scrollToToday(state);
      },
      builder: (context, state) => Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: switch (state) {
            PrayerLoading() => Center(
                child: CircularProgressIndicator(color: t.accent),
              ),
            PrayerLoaded() => _content(context, state),
          },
        ),
      ),
    );
  }

  Widget _content(BuildContext context, PrayerLoaded s) {
    final bloc = context.read<PrayerBloc>();
    return Column(
      children: [
        // Pinned: title, tabs, date navigator and any location notice stay in
        // view while the day or the month table scrolls underneath.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SpiritualTopBar(
                title: SpiritualStrings.prayerTitle,
                subtitle: '${s.resolved.location.name} · ${s.prefs.method.nameAr}',
                trailing: SpiritualIconButton(
                  icon: Icons.tune,
                  semanticLabel: SpiritualStrings.prayerSettings,
                  onPressed: () => showPrayerSettingsSheet(context, bloc),
                ),
              ),
              const SizedBox(height: 14),
              Semantics(
                label: SpiritualStrings.viewMode,
                container: true,
                child: SpiritualSegmented<PrayerView>(
                  options: const [
                    SegmentOption(
                      value: PrayerView.day,
                      label: SpiritualStrings.viewDay,
                    ),
                    SegmentOption(
                      value: PrayerView.month,
                      label: SpiritualStrings.viewMonth,
                    ),
                  ],
                  value: s.view,
                  onChanged: (v) {
                    SeenHaptics.select();
                    bloc.add(PrayerViewChanged(v));
                  },
                ),
              ),
              const SizedBox(height: 14),
              _DateNavigator(state: s),
              const SizedBox(height: 14),
            ],
          ),
        ),
        Expanded(
          child: s.view == PrayerView.day
              ? _dayBody(context, s, bloc)
              : _monthBody(s),
        ),
      ],
    );
  }

  bool _hasLocationNotice(PrayerLoaded s) =>
      s.resolved.isFallback || s.resolved.status == LocationStatus.lastKnown;

  Widget _dayBody(BuildContext context, PrayerLoaded s, PrayerBloc bloc) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        // Scrolls with the content (not pinned) so it can never crowd the
        // screen at large text sizes.
        if (_hasLocationNotice(s)) ...[
          _LocationBanner(state: s),
          const SizedBox(height: 14),
        ],
        AnimatedSwitcher(
          duration: SpiritualMotion.of(context, SpiritualMotion.base),
          child: KeyedSubtree(
            key: ValueKey(s.date),
            child: Column(
              children: [
                HorizonCard(
                  day: s.day,
                  reference: s.reference,
                  now: s.now,
                  isToday: s.isToday,
                  selected: s.selected,
                  onSelected: (id) {
                    SeenHaptics.select();
                    bloc.add(PrayerMarkerSelected(id));
                  },
                ),
                const SizedBox(height: 14),
                PrayerRowsCard(
                  day: s.day,
                  prefs: s.prefs,
                  reference: s.reference,
                  now: s.now,
                  next: s.nextPrayer,
                  onCycle: (id) {
                    if (s.prefs.modeOf(id).next == AlertMode.vibrate) {
                      SeenHaptics.vibrate(40);
                    } else {
                      SeenHaptics.select();
                    }
                    bloc.add(PrayerAlertCycled(id));
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const PrayerAlertHint(),
      ],
    );
  }

  Widget _monthBody(PrayerLoaded s) {
    final month = s.month;
    if (month == null) return const SizedBox.shrink();
    return CustomScrollView(
      controller: _controller,
      slivers: [
        if (_hasLocationNotice(s))
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            sliver: SliverToBoxAdapter(child: _LocationBanner(state: s)),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          sliver: MonthTableSliver(month: month, today: s.now),
        ),
      ],
    );
  }
}

class _DateNavigator extends StatelessWidget {
  const _DateNavigator({required this.state});

  final PrayerLoaded state;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final bloc = context.read<PrayerBloc>();
    final month = state.view == PrayerView.month ? state.month : null;
    final main = month != null
        ? PrayerTexts.monthTitle(month)
        : PrayerTexts.dayTitle(state.date, state.hijri);
    final sub = month != null
        ? PrayerTexts.gregorianSpan(month)
        : formatGregorianDate(state.date);
    return Row(
      children: [
        // In RTL the first button is on the right: "previous".
        SpiritualIconButton(
          icon: Icons.chevron_left,
          semanticLabel: SpiritualStrings.previous,
          filled: false,
          onPressed: () => bloc.add(const PrayerDateShifted(-1)),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: SpiritualMotion.of(context, SpiritualMotion.fast),
            child: Column(
              key: ValueKey('$main$sub'),
              children: [
                Semantics(
                  liveRegion: true,
                  child: Text(
                    main,
                    textAlign: TextAlign.center,
                    style: SpiritualType.bodyStrong.copyWith(
                      fontWeight: FontWeight.w800,
                      color: t.inkPrimary,
                    ),
                  ),
                ),
                Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: SpiritualType.micro.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: t.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        SpiritualIconButton(
          icon: Icons.chevron_right,
          semanticLabel: SpiritualStrings.next,
          filled: false,
          onPressed: () => bloc.add(const PrayerDateShifted(1)),
        ),
      ],
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.state});

  final PrayerLoaded state;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final bloc = context.read<PrayerBloc>();
    final status = state.resolved.status;
    final hint = locationHint(status);
    if (hint == null) return const SizedBox.shrink();
    final (String? label, PrayerEvent? event) = switch (status) {
      LocationStatus.fallbackDeniedForever ||
      LocationStatus.fallbackServiceOff =>
        (SpiritualStrings.openSettings, const PrayerOpenSettingsRequested()),
      LocationStatus.fallbackDenied || LocationStatus.fallbackUnavailable =>
        (SpiritualStrings.allow, const PrayerCitySelected(null)),
      _ => (null, null),
    };
    return Container(
      padding: const EdgeInsets.all(SpiritualSpace.s14),
      decoration: BoxDecoration(
        color: t.accentTint,
        borderRadius: BorderRadius.circular(SpiritualRadius.button),
      ),
      child: Row(
        children: [
          Icon(Icons.location_off_outlined, size: 22, color: t.accent),
          const SizedBox(width: SpiritualSpace.s12),
          Expanded(
            child: Text(hint, style: SpiritualType.caption.copyWith(color: t.inkPrimary)),
          ),
          if (label != null && event != null) ...[
            const SizedBox(width: SpiritualSpace.s8),
            PressScale(
              onTap: () => bloc.add(event),
              borderRadius: BorderRadius.circular(SpiritualRadius.control),
              child: Container(
                constraints: const BoxConstraints(minHeight: SpiritualSpace.minTap),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.accent,
                  borderRadius: BorderRadius.circular(SpiritualRadius.control),
                ),
                child: Text(
                  label,
                  style: SpiritualType.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
