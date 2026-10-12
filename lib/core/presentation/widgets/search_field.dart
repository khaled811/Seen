// SearchField — Figma "Search": a 48px white pill with a trailing search icon.
// An editable field: the caller filters on [onChanged].
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';

class SeenSearchField extends StatelessWidget {
  const SeenSearchField({
    super.key,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.semanticLabel,
  });

  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return DecoratedBox(
      decoration: const BoxDecoration(borderRadius: BorderRadius.all(SeenRadius.full), boxShadow: SeenShadows.card),
      child: Material(
        color: c.card,
        shape: StadiumBorder(side: BorderSide(color: c.border)),
        child: SizedBox(
          height: 48,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: SeenSpace.s4),
            child: Row(
              children: [
                Icon(SeenIcons.search, size: 20, color: c.inkMuted),
                const SizedBox(width: SeenSpace.s2),
                Expanded(
                  child: Semantics(
                    label: semanticLabel ?? hint,
                    textField: true,
                    child: TextField(
                      controller: controller,
                      onChanged: onChanged,
                      textInputAction: TextInputAction.search,
                      style: type.body.copyWith(color: c.ink),
                      decoration: InputDecoration(
                        hintText: hint,
                        hintStyle: type.body.copyWith(color: c.inkMuted),
                        // The theme's boxed field style does not apply inside the pill.
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        isDense: true,
                        constraints: const BoxConstraints(),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
