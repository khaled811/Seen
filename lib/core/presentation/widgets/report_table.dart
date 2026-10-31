import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_typography.dart';

/// One column of a [ReportTable]: its heading, width, and whether it holds numbers.
@immutable
class ReportTableColumn {
  const ReportTableColumn(this.title, {required this.width, this.numeric = false, this.ltr = false});

  final String title;
  final double width;

  /// Aligned to the end, tabular figures, always left to right.
  final bool numeric;

  /// Left to right text that is not a number (codes, references).
  final bool ltr;
}

enum _CellKind { header, body, total }

/// A report as a table (design/gaps SPEC §3.3). The first column stays in place while the others
/// scroll sideways; a fade on the edge and a thin indicator show there is more; the last row is the
/// totals. Rows have a fixed height of 44, so a larger text size makes the table wider, not taller.
///
/// Put it in a card with no padding. [rows] and [totals] hold one string per column; use '' for an
/// empty total.
class ReportTable extends StatefulWidget {
  const ReportTable({super.key, required this.columns, required this.rows, this.totals});

  final List<ReportTableColumn> columns;
  final List<List<String>> rows;

  /// Null = no totals row.
  final List<String>? totals;

  @override
  State<ReportTable> createState() => _ReportTableState();
}

class _ReportTableState extends State<ReportTable> {
  // Owned here, disposed in dispose().
  final _scroll = ScrollController();
  double _thumbStart = 0;
  double _thumbSize = 1;
  bool _moreHidden = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  void _update() {
    if (!mounted || !_scroll.hasClients || !_scroll.position.hasContentDimensions) {
      return;
    }
    final p = _scroll.position;
    final total = p.maxScrollExtent + p.viewportDimension;
    final size = total == 0 ? 1.0 : p.viewportDimension / total;
    final start = p.maxScrollExtent == 0 ? 0.0 : (p.pixels / p.maxScrollExtent) * (1 - size);
    final more = p.pixels < p.maxScrollExtent - 1;
    if (size != _thumbSize || start != _thumbStart || more != _moreHidden) {
      setState(() {
        _thumbSize = size;
        _thumbStart = start;
        _moreHidden = more;
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _cell(BuildContext context, String text, ReportTableColumn col, _CellKind kind, {bool sticky = false}) {
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    final style = switch (kind) {
      _CellKind.header => type.caption.copyWith(fontWeight: FontWeight.w500, color: c.inkSecondary),
      _CellKind.body => type.label.copyWith(fontWeight: FontWeight.w400, color: c.ink),
      _CellKind.total => type.label.copyWith(color: c.ink),
    };
    return Container(
      width: col.width,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: col.numeric ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: kind == _CellKind.body ? c.card : SeenBrand.violet05,
        border: BorderDirectional(
          top: switch (kind) {
            _CellKind.header => BorderSide.none,
            _CellKind.body => BorderSide(color: c.border),
            _CellKind.total => BorderSide(color: c.borderStrong),
          },
          // The sticky column sits at the start; its divider is on its end edge (the left in RTL).
          end: sticky ? BorderSide(color: c.border) : BorderSide.none,
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: col.numeric || col.ltr ? TextDirection.ltr : null,
        style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }

  Widget _column(BuildContext context, int index, {bool sticky = false}) {
    final col = widget.columns[index];
    final totals = widget.totals;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _cell(context, col.title, col, _CellKind.header, sticky: sticky),
        for (final row in widget.rows) _cell(context, index < row.length ? row[index] : '', col, _CellKind.body, sticky: sticky),
        if (totals != null) _cell(context, index < totals.length ? totals[index] : '', col, _CellKind.total, sticky: sticky),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    if (widget.columns.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _column(context, 0, sticky: true),
            Expanded(
              child: Stack(
                children: [
                  NotificationListener<ScrollMetricsNotification>(
                    // Keeps the fade and the indicator right when the data, width or text size change.
                    onNotification: (_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _update());
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      // In RTL a horizontal scroll view starts at the right edge.
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (var i = 1; i < widget.columns.length; i++) _column(context, i)]),
                    ),
                  ),
                  if (_moreHidden)
                    PositionedDirectional(
                      end: 0,
                      top: 0,
                      bottom: 0,
                      width: 28,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: AlignmentDirectional.centerEnd,
                              end: AlignmentDirectional.centerStart,
                              colors: [c.card, c.card.withOpacity(0)],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final thumb = (w * _thumbSize).clamp(math.min(24.0, w), w).toDouble();
              final offset = (w - thumb) * (_thumbSize >= 1 ? 0 : _thumbStart / (1 - _thumbSize));
              return SizedBox(
                height: 4,
                child: Stack(
                  children: [
                    DecoratedBox(decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(999)), child: const SizedBox.expand()),
                    Positioned(
                      // The thumb starts at the right in RTL.
                      left: rtl ? null : offset,
                      right: rtl ? offset : null,
                      top: 0,
                      bottom: 0,
                      width: thumb,
                      child: DecoratedBox(decoration: BoxDecoration(color: SeenBrand.violet40, borderRadius: BorderRadius.circular(999))),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
