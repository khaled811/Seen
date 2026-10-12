import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_bottom_sheet.dart';
import '../widgets/spiritual_primary_button.dart';

/// Calibration help: a looping figure-8 (2 s) and three short steps.
Future<void> showCalibrationSheet(BuildContext context) =>
    showSpiritualBottomSheet<void>(
      context,
      title: SpiritualStrings.calibrationTitle,
      builder: (sheetContext) {
        final t = SpiritualTokens.of(sheetContext);
        Widget step(int n, String text) => Padding(
              padding: const EdgeInsets.only(bottom: SpiritualSpace.s10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: t.accentTint,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      ['١', '٢', '٣'][n - 1],
                      style: SpiritualType.micro.copyWith(color: t.accent),
                    ),
                  ),
                  const SizedBox(width: SpiritualSpace.s12),
                  Expanded(
                    child: Text(
                      text,
                      style: SpiritualType.body.copyWith(color: t.inkBody),
                    ),
                  ),
                ],
              ),
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Center(child: FigureEight()),
            const SizedBox(height: SpiritualSpace.s16),
            step(1, SpiritualStrings.calibrationStep1),
            step(2, SpiritualStrings.calibrationStep2),
            step(3, SpiritualStrings.calibrationStep3),
            const SizedBox(height: SpiritualSpace.s8),
            SpiritualPrimaryButton(
              label: SpiritualStrings.calibrationDone,
              onPressed: () => Navigator.of(sheetContext).pop(),
            ),
          ],
        );
      },
    );

/// A dot tracing a figure-8 (lemniscate) every 2 s. With reduced motion only
/// the static path is drawn.
class FigureEight extends StatefulWidget {
  const FigureEight({super.key});

  @override
  State<FigureEight> createState() => _FigureEightState();
}

class _FigureEightState extends State<FigureEight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SpiritualMotion.reduced(context)) {
      _controller.stop();
      _started = false;
    } else if (!_started) {
      _started = true;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          size: const Size(200, 110),
          painter: _EightPainter(
            progress: SpiritualMotion.reduced(context) ? null : _controller.value,
            path: t.accentMid,
            dot: t.accent,
          ),
        ),
      ),
    );
  }
}

class _EightPainter extends CustomPainter {
  _EightPainter({required this.progress, required this.path, required this.dot});

  /// 0..1 along the loop, or null for a static drawing.
  final double? progress;
  final Color path;
  final Color dot;

  /// Lemniscate of Gerono: x = sin t, y = sin t · cos t.
  Offset _at(double t, Size size) => Offset(
        size.width / 2 + math.sin(t) * (size.width / 2 - 14),
        size.height / 2 + math.sin(t) * math.cos(t) * (size.height - 24),
      );

  @override
  void paint(Canvas canvas, Size size) {
    final line = Path()..moveTo(_at(0, size).dx, _at(0, size).dy);
    for (var i = 1; i <= 120; i++) {
      final o = _at(i / 120 * 2 * math.pi, size);
      line.lineTo(o.dx, o.dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = path,
    );
    final p = progress ?? 0.25;
    canvas.drawCircle(_at(p * 2 * math.pi, size), 9, Paint()..color = dot);
  }

  @override
  bool shouldRepaint(_EightPainter old) =>
      old.progress != progress || old.path != path || old.dot != dot;
}
