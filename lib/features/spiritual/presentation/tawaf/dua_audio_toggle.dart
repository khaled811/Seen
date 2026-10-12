import 'package:flutter/material.dart';

import '../bloc/dua_audio_cubit.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';

/// "استماع / إيقاف" pill: tint when idle, solid accent while playing.
class DuaAudioToggle extends StatelessWidget {
  const DuaAudioToggle({super.key, required this.status, required this.onTap});

  final DuaAudioStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final active = status == DuaAudioStatus.playing ||
        status == DuaAudioStatus.loading;
    final fg = active ? Colors.white : t.accent;
    final radius = BorderRadius.circular(24);
    return Semantics(
      toggled: active,
      child: PressScale(
        onTap: onTap,
        borderRadius: radius,
        child: AnimatedContainer(
          duration: SpiritualMotion.of(context, SpiritualMotion.base),
          constraints: const BoxConstraints(minHeight: SpiritualSpace.minTap),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? t.accent : t.accentTint,
            borderRadius: radius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.volume_up_outlined, size: 20, color: fg),
              const SizedBox(width: SpiritualSpace.s6),
              Text(
                active ? SpiritualStrings.stopAudio : SpiritualStrings.listen,
                style: SpiritualType.caption.copyWith(
                  fontWeight: FontWeight.w700,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
