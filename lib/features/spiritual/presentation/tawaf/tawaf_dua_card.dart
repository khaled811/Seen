import 'package:flutter/material.dart';

import '../../domain/entities/dua.dart';
import '../../domain/entities/rite_mode.dart';
import '../bloc/dua_audio_cubit.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_card.dart';
import 'dua_audio_toggle.dart';
import 'tawaf_texts.dart';

/// The prescribed dua for the current rite with its audio toggle. The text is
/// Uthmani-script for Quranic duas and Amiri for hadith dhikr.
class TawafDuaCard extends StatelessWidget {
  const TawafDuaCard({
    super.key,
    required this.mode,
    required this.dua,
    required this.audioStatus,
    required this.onToggleAudio,
  });

  final RiteMode mode;
  final Dua dua;
  final DuaAudioStatus audioStatus;
  final VoidCallback onToggleAudio;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    final base = dua.isQuranic ? SpiritualType.quran : SpiritualType.dua;
    return SpiritualCard(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  TawafTexts.duaLabel(mode),
                  style: SpiritualType.caption.copyWith(
                    height: 1.4,
                    color: t.inkMuted,
                  ),
                ),
              ),
              const SizedBox(width: SpiritualSpace.s12),
              DuaAudioToggle(status: audioStatus, onTap: onToggleAudio),
            ],
          ),
          const SizedBox(height: SpiritualSpace.s10),
          Text(
            dua.text,
            textAlign: TextAlign.center,
            style: base.copyWith(
              fontSize: 25,
              height: 1.9,
              color: t.inkPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
