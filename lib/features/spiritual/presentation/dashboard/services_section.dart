import 'package:flutter/material.dart';

import '../navigation/spiritual_destination.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/service_tile.dart';

/// "الخدمات": 3 × 2 grid of [ServiceTile]s. Rows are equal height so a
/// two-line label never makes its neighbours uneven.
class ServicesSection extends StatelessWidget {
  const ServicesSection({super.key, required this.onNavigate});

  final ValueChanged<SpiritualDestination> onNavigate;

  static const _items = [
    (Icons.menu_book_outlined, SpiritualStrings.svcQuran, SpiritualDestination.quranIndex),
    (Icons.autorenew, SpiritualStrings.svcTawaf, SpiritualDestination.tawaf),
    (Icons.description_outlined, SpiritualStrings.svcDuas, SpiritualDestination.duas),
    (Icons.explore_outlined, SpiritualStrings.svcQibla, SpiritualDestination.qibla),
    (Icons.schedule, SpiritualStrings.svcPrayer, SpiritualDestination.prayer),
    (Icons.blur_circular, SpiritualStrings.svcTasbeeh, SpiritualDestination.tasbeeh),
  ];

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: SpiritualSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              SpiritualStrings.services,
              style: SpiritualType.section.copyWith(color: t.inkPrimary),
            ),
          ),
          const SizedBox(height: SpiritualSpace.s12),
          for (var row = 0; row < 2; row++) ...[
            if (row > 0) const SizedBox(height: SpiritualSpace.s12),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < 3; col++) ...[
                    if (col > 0) const SizedBox(width: SpiritualSpace.s12),
                    Expanded(child: _tile(_items[row * 3 + col])),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tile((IconData, String, SpiritualDestination) item) => ServiceTile(
        icon: item.$1,
        label: item.$2,
        onTap: () => onNavigate(item.$3),
      );
}
