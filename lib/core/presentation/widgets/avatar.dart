// Avatar — generic initial/icon tile, reusable across sub-agent rows,
// notifications, approval cards, etc.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';

/// 40px avatar: initial (circle) or icon (square tile), on primarySoft.
class SeenAvatar extends StatelessWidget {
  const SeenAvatar({super.key, this.initial, this.icon, this.square = false});

  final String? initial;
  final IconData? icon;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.primarySoft,
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? const BorderRadius.all(SeenRadius.sm) : null,
      ),
      child: icon != null
          ? Icon(icon, size: 20, color: c.primaryInk)
          : Text(initial ?? '', style: seenStyle(15, 15, FontWeight.w700, c.primaryInk)),
    );
  }
}
