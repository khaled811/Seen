import 'package:flutter/material.dart';

import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import 'press_scale.dart';

/// 52 dp search field with a clear button that appears when there is text.
///
/// Owns its [TextEditingController] (created in initState, disposed in
/// dispose). [onChanged] fires on every edit; [onCleared] when the clear
/// button is pressed.
class SpiritualSearchField extends StatefulWidget {
  const SpiritualSearchField({
    super.key,
    required this.hint,
    required this.onChanged,
    required this.onCleared,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onCleared;

  @override
  State<SpiritualSearchField> createState() => _SpiritualSearchFieldState();
}

class _SpiritualSearchFieldState extends State<SpiritualSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onCleared();
  }

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.s16),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: BorderRadius.circular(SpiritualRadius.button),
        border: Border.all(color: t.borderControl),
      ),
      child: Row(
        children: [
          Icon(Icons.search, size: 22, color: t.inkBody),
          const SizedBox(width: SpiritualSpace.s10),
          Expanded(
            child: Semantics(
              textField: true,
              label: widget.hint,
              child: TextField(
                controller: _controller,
                onChanged: widget.onChanged,
                textInputAction: TextInputAction.search,
                style: SpiritualType.body.copyWith(color: t.inkPrimary),
                cursorColor: t.accent,
                decoration: InputDecoration(
                  isCollapsed: true,
                  filled: false,
                  // The field is drawn by the surrounding container; switch
                  // off every border the app theme defines.
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: widget.hint,
                  hintMaxLines: 1,
                  hintStyle: SpiritualType.body.copyWith(color: t.inkMuted),
                ),
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) {
                return const SizedBox(width: SpiritualSpace.minTap);
              }
              return PressScale(
                onTap: _clear,
                semanticLabel: SpiritualStrings.clearSearch,
                scale: 0.94,
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  width: SpiritualSpace.minTap,
                  height: SpiritualSpace.minTap,
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: t.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, size: 16, color: t.inkBody),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
