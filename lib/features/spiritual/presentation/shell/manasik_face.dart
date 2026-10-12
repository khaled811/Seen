import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/live_dashboard_repository.dart';
import '../../data/repositories/tawaf_session_repository_impl.dart';
import '../../di/prayer_module.dart';
import '../../di/quran_module.dart';
import '../../domain/entities/last_read.dart';
import '../../domain/entities/reader_state.dart';
import '../../domain/usecases/get_dashboard_usecase.dart';
import '../bloc/dashboard_cubit.dart';
import '../dashboard/dashboard_view.dart';
import '../gallery/spiritual_gallery_screen.dart';
import '../navigation/spiritual_destination.dart';
import '../navigation/spiritual_placeholder_screen.dart';
import '../spiritual_strings.dart';
import 'manasik_tab.dart';
import '../duas/duas_screen.dart';
import '../prayer/prayer_screen.dart';
import '../qibla/qibla_screen.dart';
import '../quran/quran_index_screen.dart';
import '../quran/quran_reader_screen.dart';
import '../tasbeeh/tasbeeh_screen.dart';
import '../tawaf/tawaf_screen.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_card.dart';
import '../widgets/spiritual_outlined_button.dart';
import '../widgets/spiritual_scaffold.dart';
import '../widgets/spiritual_top_bar.dart';

/// The Manasik side of the flip: hub theme + native RTL around the content
/// of the selected tab.
///
/// Owns the [DashboardCubit] so it survives tab switches and mode flips.
/// Only the dashboard (tab 0) is built so far; the other tabs are
/// placeholders until their milestones.
class ManasikFace extends StatelessWidget {
  const ManasikFace({super.key, required this.tab, this.createDashboardCubit});

  final int tab;

  /// Override for tests.
  final DashboardCubit Function()? createDashboardCubit;

  static const _titles = [
    SpiritualStrings.hubTitle,
    SpiritualStrings.navManasik,
    SpiritualStrings.navQuran,
    SpiritualStrings.navAccount,
  ];

  /// Opens [destination]. Real screens replace the placeholder per milestone.
  static Future<void> open(
    BuildContext context,
    SpiritualDestination destination,
  ) async {
    final dashboard = context.read<DashboardCubit>();
    switch (destination) {
      case SpiritualDestination.tawaf:
        await Navigator.of(context).push(TawafScreen.route());
        // The rite's progress may have changed while away.
        unawaited(dashboard.refresh());
        return;
      case SpiritualDestination.prayer:
      case SpiritualDestination.cityPicker:
        await Navigator.of(context).push(PrayerScreen.route());
        // City, method or alert modes may have changed.
        unawaited(dashboard.refresh());
        return;
      case SpiritualDestination.qibla:
        await Navigator.of(context).push(QiblaScreen.route());
        // The city may have been changed there.
        unawaited(dashboard.refresh());
        return;
      case SpiritualDestination.duas:
        await Navigator.of(context).push(DuasScreen.route());
        return;
      case SpiritualDestination.tasbeeh:
        await Navigator.of(context).push(TasbeehScreen.route());
        return;
      case SpiritualDestination.quranIndex:
        await Navigator.of(context).push(
          QuranIndexScreen.route(onReturned: () => unawaited(dashboard.refresh())),
        );
        unawaited(dashboard.refresh());
        return;
      case SpiritualDestination.quranReader:
        final saved = (await QuranModule.instance.getReaderState())
            .getOrElse((_) => const ReaderState())
            .lastRead;
        final last = saved ?? const LastRead(surah: 1, ayah: 1);
        if (!context.mounted) return;
        await Navigator.of(context).push(
          QuranReaderScreen.route(surah: last.surah, ayah: last.ayah),
        );
        unawaited(dashboard.refresh());
        return;
      default:
        break;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SpiritualPlaceholderScreen(destination: destination),
      ),
    );
  }

  /// Production wiring. Also re-plans the prayer reminders, so the rolling
  /// week of notifications is refreshed every time the hub opens.
  static DashboardCubit _defaultCubit() {
    unawaited(PrayerModule.instance.refreshReminders());
    return DashboardCubit(GetDashboardUseCase(
      LiveDashboardRepository(
        prayer: PrayerModule.instance,
        sessions: TawafSessionRepositoryImpl(),
        readerState: QuranModule.instance.readerState,
        quran: QuranModule.instance.quran,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardCubit>(
      create: (_) => (createDashboardCubit?.call() ?? _defaultCubit())..load(),
      child: SpiritualTheme(
        child: Builder(
          builder: (context) => switch (tab) {
            0 => SpiritualScaffold(
                gutter: false,
                body: DashboardView(onNavigate: (d) => open(context, d)),
              ),
            1 => ManasikTab(onNavigate: (d) => open(context, d)),
            2 => QuranIndexScreen(
                embedded: true,
                onReturned: () =>
                    unawaited(context.read<DashboardCubit>().refresh()),
              ),
            _ => _TabPlaceholder(title: _titles[tab]),
          },
        ),
      ),
    );
  }
}

class _TabPlaceholder extends StatelessWidget {
  const _TabPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return SpiritualScaffold(
      topBar: SpiritualTopBar(title: title, showBack: false),
      body: ListView(
        padding: const EdgeInsets.only(top: SpiritualSpace.s8),
        children: [
          SpiritualCard(
            child: Center(
              child: Text(
                SpiritualStrings.hubComingSoon,
                style: SpiritualType.h2.copyWith(color: t.inkMuted),
              ),
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: SpiritualSpace.gutter),
            SpiritualOutlinedButton(
              label: SpiritualStrings.gallery,
              expand: true,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SpiritualGalleryScreen(),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
