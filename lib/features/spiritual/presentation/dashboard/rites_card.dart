import 'package:flutter/material.dart';

import '../../core/arabic_digits.dart';
import '../../domain/entities/rite_mode.dart';
import '../../domain/entities/tawaf_session.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/lap_progress_bar.dart';
import '../widgets/spiritual_card.dart';
import '../widgets/spiritual_outlined_button.dart';
import '../widgets/spiritual_primary_button.dart';

/// "مناسك اليوم": the contextual Manasik banner. Shows the active Tawaf/Sa'i
/// session with a continue action, or a quieter "start Umrah" card when no
/// rite is in progress. [onOpenRite] is the hook M3 points at the Tawaf
/// tracker.
class RitesCard extends StatelessWidget {
  const RitesCard({super.key, required this.session, required this.onOpenRite});

  final TawafSession? session;
  final VoidCallback onOpenRite;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final s = session;
    return SpiritualCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  SpiritualStrings.todaysRites,
                  style: SpiritualType.caption.copyWith(color: t.inkMuted),
                ),
              ),
              if (s != null)
                Text(
                  SpiritualStrings.hajjMode,
                  style: SpiritualType.caption.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: t.accent,
                  ),
                ),
            ],
          ),
          const SizedBox(height: SpiritualSpace.s16),
          if (s == null) ..._idle(t) else ..._active(t, s),
        ],
      ),
    );
  }

  List<Widget> _idle(SpiritualTokens t) => [
        Text(
          SpiritualStrings.startUmrah,
          style: SpiritualType.h2.copyWith(color: t.inkPrimary),
        ),
        const SizedBox(height: SpiritualSpace.s16),
        SpiritualOutlinedButton(
          label: SpiritualStrings.startTawaf,
          expand: true,
          onPressed: onOpenRite,
        ),
      ];

  List<Widget> _active(SpiritualTokens t, TawafSession s) {
    final isTawaf = s.mode == RiteMode.tawaf;
    final title =
        isTawaf ? SpiritualStrings.tawafOfUmrah : SpiritualStrings.saiOfUmrah;
    final step = s.done
        ? (isTawaf ? SpiritualStrings.tawafDone : SpiritualStrings.saiDone)
        : toArabicDigits(
            'الشوط ${s.currentLap} من ${TawafSession.totalLaps}',
          );
    return [
      Text(title, style: SpiritualType.h2.copyWith(color: t.inkPrimary)),
      const SizedBox(height: SpiritualSpace.s4),
      Text(step, style: SpiritualType.body.copyWith(color: t.inkBody)),
      const SizedBox(height: SpiritualSpace.s16),
      LapProgressBar(
        completed: s.completedLaps,
        showCurrent: !s.done,
        semanticLabel: step,
      ),
      const SizedBox(height: SpiritualSpace.s16),
      _StepRow(currentStep: _currentStep(s)),
      const SizedBox(height: SpiritualSpace.s16),
      SpiritualPrimaryButton(
        label: SpiritualStrings.continueRite,
        trailingIcon: Icons.arrow_forward,
        onPressed: onOpenRite,
      ),
    ];
  }

  /// Index into ihram · tawaf · sa'i · taqsir.
  static int _currentStep(TawafSession s) {
    final base = s.mode == RiteMode.tawaf ? 1 : 2;
    return s.done ? base + 1 : base;
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.currentStep});

  final int currentStep;

  static const _labels = [
    SpiritualStrings.stepIhram,
    SpiritualStrings.stepTawaf,
    SpiritualStrings.stepSai,
    SpiritualStrings.stepTaqsir,
  ];

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    const base = SpiritualType.caption;
    final children = <Widget>[];
    for (var i = 0; i < _labels.length; i++) {
      if (i > 0) {
        children.add(Text('·', style: base.copyWith(color: t.inkMuted)));
      }
      final done = i < currentStep;
      final current = i == currentStep;
      children.add(
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (done) ...[
              Icon(Icons.check, size: 16, color: t.accent),
              const SizedBox(width: SpiritualSpace.s4),
            ],
            Text(
              _labels[i],
              style: base.copyWith(
                fontWeight: current ? FontWeight.w700 : FontWeight.w500,
                color: current
                    ? t.inkPrimary
                    : (done ? t.inkBody : t.inkMuted),
              ),
            ),
          ],
        ),
      );
    }
    return Wrap(
      spacing: SpiritualSpace.s8,
      runSpacing: SpiritualSpace.s4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
    );
  }
}
