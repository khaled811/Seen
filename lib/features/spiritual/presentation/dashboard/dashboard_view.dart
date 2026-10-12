import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../bloc/dashboard_cubit.dart';
import '../bloc/dashboard_state.dart';
import '../navigation/spiritual_destination.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_primary_button.dart';
import 'dashboard_header.dart';
import 'next_prayer_card.dart';
import 'reading_card.dart';
import 'rites_card.dart';
import 'services_section.dart';

/// The Spiritual Dashboard (Screen 1). Needs a [DashboardCubit] above it.
///
/// Lifecycle: tells the cubit when the hub is hidden (the offstage face of the
/// mode flip disables tickers) so the countdown timer does not run in the
/// background.
class DashboardView extends StatefulWidget {
  const DashboardView({super.key, required this.onNavigate});

  final ValueChanged<SpiritualDestination> onNavigate;

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with SingleTickerProviderStateMixin {
  /// The staggered entrance plays on cold start only (docs/04 §Global).
  static bool _entrancePlayed = false;
  static const _stagger = Duration(milliseconds: 40);
  static const _sections = 5;

  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: SpiritualMotion.slow + _stagger * _sections,
  );
  bool? _visible;
  late DashboardCubit _cubit;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cubit = context.read<DashboardCubit>();
    final visible = TickerMode.of(context);
    if (_visible != visible) {
      _visible = visible;
      _cubit.setActive(visible);
    }
    if (_entrancePlayed || SpiritualMotion.reduced(context)) {
      _entrance.value = 1;
    } else if (!_entrance.isAnimating && _entrance.value == 0) {
      _entrancePlayed = true;
      _entrance.forward();
    }
  }

  @override
  void dispose() {
    // Leaving the dashboard tab (the cubit outlives the view) must stop the
    // countdown timer too, not only hiding the whole hub.
    _cubit.setActive(false);
    _entrance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) => switch (state) {
        DashboardInitial() || DashboardLoading() => Center(
            child: CircularProgressIndicator(
              color: SpiritualTokens.of(context).accent,
            ),
          ),
        DashboardFailure() => _Failure(
            onRetry: () => context.read<DashboardCubit>().load(),
          ),
        DashboardLoaded() => _content(state),
      },
    );
  }

  Widget _content(DashboardLoaded state) {
    final snapshot = state.snapshot;
    final sections = <Widget>[
      DashboardHeader(
        city: snapshot.city,
        hijri: snapshot.hijri,
        onCityTap: () => widget.onNavigate(SpiritualDestination.cityPicker),
        onProfileTap: () => widget.onNavigate(SpiritualDestination.profile),
      ),
      _padded(NextPrayerCard(
        prayers: snapshot.prayers,
        next: state.next,
        onTap: () => widget.onNavigate(SpiritualDestination.prayer),
      )),
      _padded(RitesCard(
        session: snapshot.activeRite,
        onOpenRite: () => widget.onNavigate(SpiritualDestination.tawaf),
      )),
      _padded(ReadingCard(
        progress: snapshot.reading,
        onResume: () => widget.onNavigate(SpiritualDestination.quranReader),
      )),
      _padded(ServicesSection(onNavigate: widget.onNavigate)),
    ];
    return ListView.separated(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: sections.length,
      separatorBuilder: (_, __) => const SizedBox(height: SpiritualSpace.gutter),
      itemBuilder: (_, i) => _Entrance(
        animation: _entrance,
        index: i,
        count: _sections,
        child: sections[i],
      ),
    );
  }

  Widget _padded(Widget child) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.gutter),
        child: child,
      );
}

/// Fade + 8 px rise, staggered by [index].
class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.animation,
    required this.index,
    required this.count,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = SpiritualMotion.slow.inMilliseconds +
        _DashboardViewState._stagger.inMilliseconds * count;
    final begin = _DashboardViewState._stagger.inMilliseconds * index / total;
    final end = begin + SpiritualMotion.slow.inMilliseconds / total;
    final curve = Interval(
      begin,
      end.clamp(0.0, 1.0),
      curve: SpiritualMotion.baseCurve,
    );
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, child) {
        final v = curve.transform(animation.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 8 * (1 - v)), child: child),
        );
      },
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
              SpiritualStrings.loadFailed,
              textAlign: TextAlign.center,
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
