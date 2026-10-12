import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/arabic_digits.dart';
import '../../core/seen_haptics.dart';
import '../../di/prayer_module.dart';
import '../../domain/entities/compass_reading.dart';
import '../../domain/entities/location_fix.dart';
import '../bloc/qibla_cubit.dart';
import '../bloc/qibla_state.dart';
import '../prayer/prayer_settings_sheet.dart' show locationHint;
import '../spiritual_strings.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_card.dart';
import '../widgets/spiritual_icon_button.dart';
import '../widgets/spiritual_top_bar.dart';
import 'calibration_sheet.dart';
import 'compass_dial.dart';
import 'qibla_city_sheet.dart';
import 'qibla_fallback_note.dart';
import 'qibla_info_cards.dart';
import 'qibla_status_pill.dart';

/// Qibla compass (Screen 6).
class QiblaScreen extends StatelessWidget {
  const QiblaScreen({super.key, this.module});

  final PrayerModule? module;

  static Route<void> route({PrayerModule? module}) =>
      MaterialPageRoute<void>(builder: (_) => QiblaScreen(module: module));

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => QiblaCubit(module ?? PrayerModule.instance)..start(),
      child: const SpiritualTheme(child: _QiblaView()),
    );
  }
}

class _QiblaView extends StatefulWidget {
  const _QiblaView();

  @override
  State<_QiblaView> createState() => _QiblaViewState();
}

class _QiblaViewState extends State<_QiblaView> with WidgetsBindingObserver {
  late final QiblaCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<QiblaCubit>();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The compass is paused while the app is not in the foreground (battery).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _cubit.setActive(state == AppLifecycleState.resumed);
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return BlocConsumer<QiblaCubit, QiblaState>(
      // One haptic and one announcement per transition into "locked".
      listenWhen: (p, c) =>
          c is QiblaReady && (p is! QiblaReady || c.lockSeq != p.lockSeq),
      listener: (context, state) {
        if (state is! QiblaReady || !state.locked) return;
        SeenHaptics.lock();
        SemanticsService.announce(SpiritualStrings.facingQibla, TextDirection.rtl);
      },
      builder: (context, state) => Scaffold(
        backgroundColor: t.bg,
        body: SafeArea(
          child: switch (state) {
            QiblaLoading() => Center(
                child: CircularProgressIndicator(color: t.accent),
              ),
            QiblaReady() => _body(context, state),
          },
        ),
      ),
    );
  }

  Widget _body(BuildContext context, QiblaReady s) {
    final fallback = s.sensor == SensorStatus.unavailable;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: SpiritualTopBar(
            title: SpiritualStrings.qiblaTitle,
            subtitle: s.resolved.location.name,
            trailing: SpiritualIconButton(
              icon: Icons.edit_location_alt_outlined,
              semanticLabel: SpiritualStrings.chooseCity,
              onPressed: () => showQiblaCitySheet(
                context,
                _cubit,
                selectedCityId: s.resolved.location.cityId,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (s.resolved.isFallback ||
                  s.resolved.status == LocationStatus.lastKnown) ...[
                _LocationBanner(state: s, cubit: _cubit),
                const SizedBox(height: 14),
              ],
              if (s.nearKaaba)
                const _Notice(text: SpiritualStrings.nearKaaba)
              else if (fallback) ...[
                _dial(s, fallback: true),
                const SizedBox(height: 14),
                QiblaFallbackNote(bearing: s.bearing, sun: s.sun),
              ] else ...[
                Center(
                  child: QiblaStatusPill(
                    locked: s.locked,
                    turn: s.turn,
                    waiting: s.sensor == SensorStatus.starting,
                  ),
                ),
                const SizedBox(height: 14),
                _Pointer(locked: s.locked),
                const SizedBox(height: 6),
                _dial(s, fallback: false),
                if (s.accuracy == CompassAccuracy.poor) ...[
                  const SizedBox(height: 14),
                  _AccuracyBanner(
                    onCalibrate: () => showCalibrationSheet(context),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              QiblaInfoCards(
                distanceKm: s.distanceKm,
                accuracy: s.accuracy,
                showAccuracy: !fallback,
              ),
              const SizedBox(height: 14),
              KaabaCard(onCalibrate: () => showCalibrationSheet(context)),
              const SizedBox(height: 14),
              Text(
                SpiritualStrings.qiblaTip,
                textAlign: TextAlign.center,
                style: SpiritualType.micro.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: SpiritualTokens.of(context).inkMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dial(QiblaReady s, {required bool fallback}) {
    final heading = fallback ? null : s.heading;
    final label = heading == null
        ? toArabicDigits(
            'بوصلة: القبلة على زاوية ${s.bearing.round()} درجة من الشمال',
          )
        : toArabicDigits(
            'بوصلة: القبلة على زاوية ${s.bearing.round()} درجة، '
            'واتجاهك الحالي ${heading.round()} درجة',
          );
    return Center(
      child: Semantics(
        image: true,
        label: label,
        child: ExcludeSemantics(
          child: CompassDial(
            bearing: s.bearing,
            heading: heading,
            locked: s.locked,
            sunAzimuth: fallback && (s.sun?.isUp ?? false) ? s.sun!.azimuth : null,
          ),
        ),
      ),
    );
  }
}

/// The fixed pointer above the dial (ink; sage when locked).
class _Pointer extends StatelessWidget {
  const _Pointer({required this.locked});

  final bool locked;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return ExcludeSemantics(
      child: Center(
        child: CustomPaint(
          size: const Size(24, 16),
          painter: _TrianglePainter(locked ? t.sage : t.inkPrimary),
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width / 2, size.height)
        ..close(),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => old.color != color;
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return SpiritualCard(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: SpiritualType.bodyStrong.copyWith(color: t.inkPrimary),
      ),
    );
  }
}

class _AccuracyBanner extends StatelessWidget {
  const _AccuracyBanner({required this.onCalibrate});

  final VoidCallback onCalibrate;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(SpiritualSpace.s14),
        decoration: BoxDecoration(
          color: t.accentTint,
          borderRadius: BorderRadius.circular(SpiritualRadius.button),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded, size: 22, color: t.accent),
                const SizedBox(width: SpiritualSpace.s12),
                Expanded(
                  child: Text(
                    SpiritualStrings.lowAccuracyBanner,
                    style: SpiritualType.caption.copyWith(color: t.inkPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SpiritualSpace.s10),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: CalibrateButton(onPressed: onCalibrate),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationBanner extends StatelessWidget {
  const _LocationBanner({required this.state, required this.cubit});

  final QiblaReady state;
  final QiblaCubit cubit;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final hint = locationHint(state.resolved.status);
    if (hint == null) return const SizedBox.shrink();
    final (String? label, VoidCallback? action) = switch (state.resolved.status) {
      LocationStatus.fallbackDeniedForever ||
      LocationStatus.fallbackServiceOff =>
        (SpiritualStrings.openSettings, cubit.openSettings),
      LocationStatus.fallbackDenied || LocationStatus.fallbackUnavailable =>
        (SpiritualStrings.allow, () => cubit.relocate(useGps: true)),
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
            child: Text(
              hint,
              style: SpiritualType.caption.copyWith(color: t.inkPrimary),
            ),
          ),
          if (label != null && action != null) ...[
            const SizedBox(width: SpiritualSpace.s8),
            PressScale(
              onTap: action,
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
