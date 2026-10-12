import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/arabic_digits.dart';
import '../../domain/entities/calc_settings.dart';
import '../../domain/entities/location_fix.dart';
import '../../domain/entities/prayer_location.dart';
import '../../domain/entities/prayer_preferences.dart';
import '../../domain/services/notification_scheduler.dart';
import '../bloc/prayer_bloc.dart';
import '../bloc/prayer_event.dart';
import '../bloc/prayer_state.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_bottom_sheet.dart';
import '../widgets/spiritual_chip.dart';
import '../widgets/spiritual_primary_button.dart';
import '../widgets/spiritual_segmented.dart';

/// Settings: location, calculation method, Asr school, pre-alert and
/// notification status. Changes apply immediately through [bloc].
Future<void> showPrayerSettingsSheet(BuildContext context, PrayerBloc bloc) =>
    showSpiritualBottomSheet<void>(
      context,
      title: SpiritualStrings.prayerSettings,
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: const _SettingsContent(),
      ),
    );

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PrayerBloc, PrayerState>(
      builder: (context, state) {
        if (state is! PrayerLoaded) return const SizedBox.shrink();
        final bloc = context.read<PrayerBloc>();
        final prefs = state.prefs;
        void change(PrayerPreferences p) => bloc.add(PrayerSettingsChanged(p));
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Section(
              title: SpiritualStrings.settingsLocation,
              child: _LocationSection(state: state),
            ),
            _Section(
              title: SpiritualStrings.settingsMethod,
              child: Column(
                children: [
                  for (final m in CalcMethod.values)
                    _RadioRow(
                      label: m.nameAr,
                      selected: prefs.method == m,
                      onTap: () => change(prefs.copyWith(method: m)),
                    ),
                ],
              ),
            ),
            _Section(
              title: SpiritualStrings.settingsMadhab,
              child: SpiritualSegmented<AsrMadhab>(
                options: const [
                  SegmentOption(value: AsrMadhab.shafi, label: 'الجمهور'),
                  SegmentOption(value: AsrMadhab.hanafi, label: 'الحنفي'),
                ],
                value: prefs.madhab,
                onChanged: (m) => change(prefs.copyWith(madhab: m)),
              ),
            ),
            _Section(
              title: SpiritualStrings.settingsPreAlert,
              child: Wrap(
                spacing: SpiritualSpace.s8,
                runSpacing: SpiritualSpace.s8,
                children: [
                  for (final m in PrayerPreferences.preAlertChoices)
                    SpiritualChip(
                      label: m == 0
                          ? SpiritualStrings.preAlertNone
                          : toArabicDigits('$m د'),
                      selected: prefs.preAlertMinutes == m,
                      onTap: () => change(prefs.copyWith(preAlertMinutes: m)),
                    ),
                ],
              ),
            ),
            _Section(
              title: SpiritualStrings.settingsNotifications,
              child: _NotificationSection(state: state),
            ),
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SpiritualSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: SpiritualType.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: t.accent,
            ),
          ),
          const SizedBox(height: SpiritualSpace.s8),
          child,
        ],
      ),
    );
  }
}

class _RadioRow extends StatelessWidget {
  const _RadioRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: PressScale(
        onTap: onTap,
        scale: 0.99,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: SpiritualSpace.minTap),
          child: Row(
            children: [
              Icon(
                selected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 22,
                color: selected ? t.accent : t.inkMuted,
              ),
              const SizedBox(width: SpiritualSpace.s12),
              Expanded(
                child: Text(
                  label,
                  style: SpiritualType.body.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: t.inkPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LocationSection extends StatelessWidget {
  const _LocationSection({required this.state});

  final PrayerLoaded state;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final bloc = context.read<PrayerBloc>();
    final cityId = state.prefs.cityId;
    final status = state.resolved.status;
    final hint = locationHint(status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          state.resolved.location.name,
          style: SpiritualType.bodyStrong.copyWith(color: t.inkPrimary),
        ),
        if (hint != null) ...[
          const SizedBox(height: SpiritualSpace.s4),
          Text(hint, style: SpiritualType.caption.copyWith(color: t.inkBody)),
        ],
        const SizedBox(height: SpiritualSpace.s12),
        Wrap(
          spacing: SpiritualSpace.s8,
          runSpacing: SpiritualSpace.s8,
          children: [
            SpiritualChip(
              label: SpiritualStrings.automaticLocation,
              selected: cityId == null,
              onTap: () => bloc.add(const PrayerCitySelected(null)),
            ),
            for (final c in SaudiCities.all)
              SpiritualChip(
                label: c.nameAr,
                selected: cityId == c.id,
                onTap: () => bloc.add(PrayerCitySelected(c.id)),
              ),
          ],
        ),
      ],
    );
  }
}

/// User-facing explanation of a degraded location, or null when fine.
String? locationHint(LocationStatus status) => switch (status) {
      LocationStatus.fallbackDenied => SpiritualStrings.locFallbackDenied,
      LocationStatus.fallbackDeniedForever => SpiritualStrings.locFallbackForever,
      LocationStatus.fallbackServiceOff => SpiritualStrings.locFallbackServiceOff,
      LocationStatus.fallbackUnavailable => SpiritualStrings.locFallbackUnavailable,
      LocationStatus.lastKnown => SpiritualStrings.locLastKnown,
      _ => null,
    };

class _NotificationSection extends StatelessWidget {
  const _NotificationSection({required this.state});

  final PrayerLoaded state;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final bloc = context.read<PrayerBloc>();
    final p = state.notifications;
    final (icon, text) = switch (p) {
      NotificationPermission.granted => (
          Icons.notifications_active_outlined,
          SpiritualStrings.notifGranted,
        ),
      NotificationPermission.denied => (
          Icons.notifications_off_outlined,
          SpiritualStrings.notifDenied,
        ),
      NotificationPermission.notDetermined => (
          Icons.notifications_none,
          SpiritualStrings.notifUnknown,
        ),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: t.inkBody),
            const SizedBox(width: SpiritualSpace.s12),
            Expanded(
              child: Text(
                text,
                style: SpiritualType.body.copyWith(color: t.inkBody),
              ),
            ),
          ],
        ),
        if (p == NotificationPermission.notDetermined) ...[
          const SizedBox(height: SpiritualSpace.s12),
          SpiritualPrimaryButton(
            label: SpiritualStrings.enableNotifications,
            onPressed: () => bloc.add(const PrayerNotificationsRequested()),
          ),
        ],
        const SizedBox(height: SpiritualSpace.s8),
        Text(
          SpiritualStrings.adhanAudioNote,
          style: SpiritualType.micro.copyWith(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: t.inkMuted,
          ),
        ),
      ],
    );
  }
}
