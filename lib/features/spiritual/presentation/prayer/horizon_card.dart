import 'package:flutter/material.dart';

import '../../core/time_format.dart';
import '../../domain/entities/prayer_day.dart';
import '../../domain/entities/prayer_id.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_card.dart';
import 'horizon_layout.dart';
import 'prayer_texts.dart';

/// The daily horizon (docs/03 §5): daylight arc with the sun at "now", seven
/// tappable markers, and a caption pill describing the selected one.
class HorizonCard extends StatelessWidget {
  const HorizonCard({
    super.key,
    required this.day,
    required this.reference,
    required this.now,
    required this.isToday,
    required this.selected,
    required this.onSelected,
  });

  final PrayerDay day;

  /// Splits past from future (see `PrayerLoaded.reference`).
  final DateTime reference;
  final DateTime now;
  final bool isToday;
  final PrayerId selected;
  final ValueChanged<PrayerId> onSelected;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final layout = HorizonLayout.compute(day, reference);
    final time = day.timeOf(selected);
    final selectedPast = !time.isAfter(reference);
    final relative = PrayerTexts.relative(selected, time, now, isToday);
    return SpiritualCard(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 14),
      child: Column(
        children: [
          // The artwork keeps its 342 × 120 geometry and scales down on narrow
          // screens (marker hit areas scale with it).
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              width: HorizonLayout.width,
              height: HorizonLayout.height,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      // The sun glides to its new place once a minute.
                      tween: Tween(end: layout.elapsedFraction),
                      duration: SpiritualMotion.of(context, SpiritualMotion.slow),
                      builder: (_, fraction, __) => CustomPaint(
                        painter: _HorizonPainter(
                          layout: layout,
                          fraction: fraction,
                          baseline: t.borderStrong,
                          arc: t.borderControl,
                          accent: t.accent,
                          halo: t.accentTint,
                        ),
                      ),
                    ),
                  ),
                  // One tap layer for the whole canvas. Fajr and sunrise sit only
                  // ~20 dp apart, so separate 40 dp targets would overlap and
                  // the later one would win; picking the nearest marker keeps
                  // every tap unambiguous.
                  Positioned.fill(
                    // Pointer-only layer: screen readers use the labelled marker
                    // buttons below, which carry the same action.
                    child: ExcludeSemantics(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (d) {
                          final id = nearestMarker(layout.markers, d.localPosition);
                          if (id != null) onSelected(id);
                        },
                      ),
                    ),
                  ),
                  for (final m in layout.markers)
                    Positioned(
                      left: m.x - 20,
                      top: m.y - 20,
                      width: 40,
                      height: 40,
                      child: IgnorePointer(
                        child: _MarkerButton(
                          marker: m,
                          selected: m.id == selected,
                          label:
                              '${m.id.nameAr} ${formatClock12(day.timeOf(m.id))}',
                          onTap: () => onSelected(m.id),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: SpiritualSpace.s6),
          AnimatedSwitcher(
            duration: SpiritualMotion.of(context, SpiritualMotion.fast),
            child: Container(
              key: ValueKey('$selected$relative${time.millisecondsSinceEpoch}'),
              constraints: const BoxConstraints(minHeight: 40),
              margin: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s16),
              padding: const EdgeInsets.symmetric(
                horizontal: SpiritualSpace.s16,
                vertical: SpiritualSpace.s6,
              ),
              decoration: BoxDecoration(
                color: t.surfaceMuted,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Semantics(
                liveRegion: true,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: SpiritualSpace.s10,
                  children: [
                    Text(
                      '${selected.nameAr} · ${formatClock12(time)}',
                      style: SpiritualType.label.copyWith(
                        fontWeight: FontWeight.w800,
                        color: t.inkPrimary,
                      ),
                    ),
                    if (relative.isNotEmpty)
                      Text(
                        relative,
                        style: SpiritualType.caption.copyWith(
                          color: selectedPast ? t.inkMuted : t.accent,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The marker closest to [point] (canvas coordinates), or null when none is
/// within a thumb's reach (40 dp).
PrayerId? nearestMarker(List<HorizonMarker> markers, Offset point) {
  PrayerId? best;
  var bestDistance = 40.0;
  for (final m in markers) {
    final d = (Offset(m.x, m.y) - point).distance;
    if (d < bestDistance) {
      bestDistance = d;
      best = m.id;
    }
  }
  return best;
}

class _MarkerButton extends StatelessWidget {
  const _MarkerButton({
    required this.marker,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final HorizonMarker marker;
  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    // Dhuhr sits at the apex, where the sun marker is drawn; its dot is
    // invisible but the 40 dp target stays.
    final hidden = marker.id == PrayerId.dhuhr;
    final size = hidden ? 0.0 : (selected ? 16.0 : 12.0);
    final fill = marker.past ? t.accentMid : (selected ? t.accent : t.surface);
    final ring = marker.past
        ? t.accentMid
        : (selected ? t.accent : t.inkMuted);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Center(
          child: AnimatedContainer(
            duration: SpiritualMotion.of(context, SpiritualMotion.fast),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: fill,
              border: Border.all(color: ring, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}

class _HorizonPainter extends CustomPainter {
  _HorizonPainter({
    required this.layout,
    required this.fraction,
    required this.baseline,
    required this.arc,
    required this.accent,
    required this.halo,
  });

  final HorizonLayout layout;
  final double fraction;
  final Color baseline;
  final Color arc;
  final Color accent;
  final Color halo;

  @override
  void paint(Canvas canvas, Size size) {
    // Dotted night baseline.
    final dot = Paint()
      ..color = baseline
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var x = HorizonLayout.left; x <= HorizonLayout.right; x += 7) {
      canvas.drawLine(
        Offset(x, HorizonLayout.baselineY),
        Offset(x + 0.01, HorizonLayout.baselineY),
        dot,
      );
    }

    final p0 = Offset(layout.sunriseX, HorizonLayout.baselineY);
    final p1 = Offset(layout.controlX, HorizonLayout.controlY);
    final p2 = Offset(layout.maghribX, HorizonLayout.baselineY);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(
      Path()
        ..moveTo(p0.dx, p0.dy)
        ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy),
      stroke..color = arc,
    );

    if (fraction > 0) {
      final a = Offset.lerp(p0, p1, fraction)!;
      final b = Offset.lerp(p1, p2, fraction)!;
      final end = Offset.lerp(a, b, fraction)!;
      canvas.drawPath(
        Path()
          ..moveTo(p0.dx, p0.dy)
          ..quadraticBezierTo(a.dx, a.dy, end.dx, end.dy),
        stroke..color = accent,
      );
      if (fraction < 1) {
        canvas.drawCircle(end, 14, Paint()..color = halo);
        canvas.drawCircle(end, 7, Paint()..color = accent);
      }
    }
  }

  @override
  bool shouldRepaint(_HorizonPainter old) =>
      old.layout != layout ||
      old.fraction != fraction ||
      old.baseline != baseline ||
      old.arc != arc ||
      old.accent != accent ||
      old.halo != halo;
}
