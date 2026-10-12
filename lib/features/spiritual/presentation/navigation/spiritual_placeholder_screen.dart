import 'package:flutter/material.dart';

import '../spiritual_strings.dart';
import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_card.dart';
import '../widgets/spiritual_scaffold.dart';
import '../widgets/spiritual_top_bar.dart';
import 'spiritual_destination.dart';

/// Stand-in for screens delivered in later milestones.
class SpiritualPlaceholderScreen extends StatelessWidget {
  const SpiritualPlaceholderScreen({super.key, required this.destination});

  final SpiritualDestination destination;

  static const titles = {
    SpiritualDestination.tawaf: SpiritualStrings.svcTawaf,
    SpiritualDestination.quranIndex: SpiritualStrings.svcQuran,
    SpiritualDestination.quranReader: SpiritualStrings.continueReading,
    SpiritualDestination.duas: SpiritualStrings.svcDuas,
    SpiritualDestination.qibla: SpiritualStrings.svcQibla,
    SpiritualDestination.prayer: SpiritualStrings.svcPrayer,
    SpiritualDestination.tasbeeh: SpiritualStrings.svcTasbeeh,
    SpiritualDestination.cityPicker: SpiritualStrings.changeCity,
    SpiritualDestination.profile: SpiritualStrings.profileSettings,
  };

  @override
  Widget build(BuildContext context) {
    return SpiritualTheme(
      child: Builder(
        builder: (context) {
          final t = SpiritualTokens.of(context);
          return SpiritualScaffold(
            topBar: SpiritualTopBar(title: titles[destination]!),
            body: Padding(
              padding: const EdgeInsets.only(top: SpiritualSpace.s8),
              child: SpiritualCard(
                child: Center(
                  child: Text(
                    SpiritualStrings.hubComingSoon,
                    style: SpiritualType.h2.copyWith(color: t.inkMuted),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
