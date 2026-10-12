import 'package:flutter/material.dart';

import '../navigation/spiritual_destination.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/press_scale.dart';
import '../widgets/spiritual_card.dart';
import '../widgets/spiritual_scaffold.dart';
import '../widgets/spiritual_top_bar.dart';

/// The "المناسك" tab: every rite and companion in one list, led by the Tawaf
/// and Sa'i companion.
class ManasikTab extends StatelessWidget {
  const ManasikTab({super.key, required this.onNavigate});

  final ValueChanged<SpiritualDestination> onNavigate;

  static const _items = [
    (Icons.autorenew, SpiritualStrings.svcTawaf, SpiritualDestination.tawaf),
    (Icons.schedule, SpiritualStrings.svcPrayer, SpiritualDestination.prayer),
    (Icons.explore_outlined, SpiritualStrings.svcQibla, SpiritualDestination.qibla),
    (Icons.description_outlined, SpiritualStrings.svcDuas, SpiritualDestination.duas),
    (Icons.blur_circular, SpiritualStrings.svcTasbeeh, SpiritualDestination.tasbeeh),
  ];

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return SpiritualScaffold(
      topBar: const SpiritualTopBar(title: SpiritualStrings.navManasik, showBack: false),
      body: ListView.separated(
        padding: const EdgeInsets.only(top: SpiritualSpace.s8, bottom: SpiritualSpace.s24),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: SpiritualSpace.s12),
        itemBuilder: (context, i) {
          final (icon, label, destination) = _items[i];
          return PressScale(
            onTap: () => onNavigate(destination),
            borderRadius: BorderRadius.circular(SpiritualRadius.card),
            child: SpiritualCard(
              compact: true,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: t.accentTint,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: t.accent, size: 24),
                    ),
                    const SizedBox(width: SpiritualSpace.s14),
                    Expanded(
                      child: Text(
                        label,
                        style: SpiritualType.bodyStrong.copyWith(color: t.inkPrimary),
                      ),
                    ),
                    Icon(Icons.chevron_left, color: t.inkMuted),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
