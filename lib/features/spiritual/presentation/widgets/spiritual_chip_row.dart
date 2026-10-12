import 'package:flutter/material.dart';

import '../theme/spiritual_tokens.dart';
import 'spiritual_chip.dart';

/// Horizontally scrolling row of [SpiritualChip]s with 16 dp edge padding.
///
/// The selected chip is scrolled into view when the row first appears and
/// whenever the selection changes, so a restored choice is never hidden off
/// screen. Rows are a handful of chips, so all are built up front (which is
/// what lets an off-screen chip be scrolled to).
class SpiritualChipRow<T> extends StatefulWidget {
  const SpiritualChipRow({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelected,
  });

  /// Value → label, in display order.
  final Map<T, String> labels;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  State<SpiritualChipRow<T>> createState() => _SpiritualChipRowState<T>();
}

class _SpiritualChipRowState<T> extends State<SpiritualChipRow<T>> {
  final _selectedKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _revealSelected(animate: false);
  }

  @override
  void didUpdateWidget(SpiritualChipRow<T> old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _revealSelected(animate: true);
  }

  void _revealSelected({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _selectedKey.currentContext;
      if (!mounted || target == null) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.5,
        duration: animate
            ? SpiritualMotion.of(context, SpiritualMotion.base)
            : Duration.zero,
        curve: SpiritualMotion.baseCurve,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.labels.entries.toList(growable: false);
    return SizedBox(
      height: SpiritualSpace.minTap,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SpiritualSpace.gutter),
        child: Row(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(width: SpiritualSpace.s8),
              SpiritualChip(
                key: entries[i].key == widget.selected ? _selectedKey : null,
                label: entries[i].value,
                selected: entries[i].key == widget.selected,
                onTap: () => widget.onSelected(entries[i].key),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
