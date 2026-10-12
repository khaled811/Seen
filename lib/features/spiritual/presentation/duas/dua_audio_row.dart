import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/arabic_digits.dart';
import '../../core/seen_haptics.dart';
import '../../domain/entities/dua.dart';
import '../bloc/dua_audio_cubit.dart';
import '../bloc/dua_player_cubit.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_progress_bar.dart';

/// Play/pause with a progress bar and elapsed / total time, for the open dua
/// card. Only this row listens to the player, so a playing clip never
/// rebuilds the list.
class DuaAudioRow extends StatelessWidget {
  const DuaAudioRow({super.key, required this.dua});

  final Dua dua;

  /// m:ss in Arabic-Indic digits.
  static String clock(Duration d) {
    final s = d.inSeconds;
    final sec = (s % 60).toString().padLeft(2, '0');
    return toArabicDigits('${s ~/ 60}:$sec');
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final total = Duration(seconds: dua.durationSec ?? 0);
    return BlocBuilder<DuaPlayerCubit, DuaPlayerState>(
      buildWhen: (p, c) => p.activeId == dua.id || c.activeId == dua.id,
      builder: (context, state) {
        final mine = state.activeId == dua.id;
        final playing = state.isActive(dua.id);
        final failed = mine && state.status == DuaAudioStatus.error;
        final position = mine ? state.position : Duration.zero;
        final progress = total.inMilliseconds == 0
            ? 0.0
            : position.inMilliseconds / total.inMilliseconds;
        return Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            SpiritualSpace.s8,
            SpiritualSpace.s8,
            SpiritualSpace.s14,
            SpiritualSpace.s8,
          ),
          decoration: BoxDecoration(
            color: t.bg,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              PressScale(
                onTap: () {
                  SeenHaptics.light();
                  context.read<DuaPlayerCubit>().toggle(dua.id, dua.audioAsset);
                },
                scale: 0.94,
                borderRadius: BorderRadius.circular(26),
                semanticLabel: playing
                    ? SpiritualStrings.duaStopListening
                    : SpiritualStrings.duaListen,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: t.accent, shape: BoxShape.circle),
                  child: Icon(
                    playing ? Icons.pause : Icons.play_arrow_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: SpiritualSpace.s12),
              Expanded(
                child: failed
                    ? Text(
                        SpiritualStrings.audioUnavailable,
                        style: SpiritualType.caption.copyWith(color: t.inkBody),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SpiritualProgressBar(
                            value: progress,
                            height: 6,
                            duration: Duration.zero,
                            semanticLabel: SpiritualStrings.duaProgress,
                          ),
                          const SizedBox(height: SpiritualSpace.s8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                clock(position),
                                style: SpiritualType.micro.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: t.inkBody,
                                ),
                              ),
                              Text(
                                clock(total),
                                style: SpiritualType.micro.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: t.inkBody,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
