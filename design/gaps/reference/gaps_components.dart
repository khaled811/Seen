// Section · GAPS — reference code for the NEW components only.
//
// This is a reference, not a package. Copy what you need into the project's
// shared widgets folder and replace `GapsTokens` with the project's theme tokens
// (see design/gaps/tokens.json). Strings are passed in by the caller so they can
// come from l10n (design/gaps/copy/*.arb). Requires Flutter 3.27+ (Color.withValues).
//
// Contents
//   GapsTokens            — values from tokens.json (map to the theme, then delete)
//   RatingStars           — SPEC §3.1
//   SuggestionRow         — SPEC §3.2
//   ReportTable           — SPEC §3.3 (sticky first column, totals, horizontal scroll)
//   CountdownPill         — SPEC §3.4
//   RevealController      — SPEC §5.2 (one value at a time, 30 s auto-hide, hide on background)
//   Masking               — SPEC §5 masking formats
//   normalizeArabic       — SPEC §10.2 search normalisation

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Tokens
// ---------------------------------------------------------------------------

abstract final class GapsTokens {
  static const brand = Color(0xFF7B52F5);
  static const link = Color(0xFF6A3FEF);
  static const violet05 = Color(0xFFF8F6FF);
  static const violet10 = Color(0xFFF2EEFE);
  static const violet40 = Color(0xFFCABAFB);
  static const violet60 = Color(0xFFB097F9);
  static const line = Color(0xFFEEEAF6);
  static const lineStrong = Color(0xFFD5CBF7);
  static const ink = Color(0xFF1B1530);
  static const secondary = Color(0xFF5B5280);
  static const muted = Color(0xFF8A83A8);

  static const completed = StatusPair(Color(0xFFE3F4EC), Color(0xFF17694A));
  static const action = StatusPair(Color(0xFFFFF1D6), Color(0xFF7A4E00));
  static const rejected = StatusPair(Color(0xFFFBE7E9), Color(0xFFA3263A));
  static const processing = StatusPair(Color(0xFFE8E1FE), Color(0xFF4A2FA8));
  static const authority = StatusPair(Color(0xFFE1F3FA), Color(0xFF0A6080));
  static const neutral = StatusPair(Color(0xFFF5F3FA), Color(0xFF3D3650));

  static const caption = TextStyle(fontSize: 11, height: 16 / 11, color: secondary);
  static const label = TextStyle(fontSize: 13, height: 20 / 13, fontWeight: FontWeight.w500, color: secondary);
  static const body = TextStyle(fontSize: 14, height: 22 / 14, color: ink);
  static const bodyStrong = TextStyle(fontSize: 14, height: 22 / 14, fontWeight: FontWeight.w500, color: ink);
}

@immutable
class StatusPair {
  const StatusPair(this.bg, this.fg);
  final Color bg;
  final Color fg;
}

/// Pill chip with a 6 px dot (SPEC §1). Use the project's status chip if it
/// already supports these pairs; this is here only so the file is self-contained.
class GapsChip extends StatelessWidget {
  const GapsChip({super.key, required this.label, required this.tone});
  final String label;
  final StatusPair tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: tone.fg, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500, color: tone.fg)),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// RatingStars — SPEC §3.1
// ---------------------------------------------------------------------------

enum RatingMode { input, locked, readonly }

enum RatingSize { md, sm }

class RatingStars extends StatelessWidget {
  const RatingStars({
    super.key,
    required this.value,
    this.mode = RatingMode.input,
    this.size = RatingSize.md,
    this.onChanged,
    required this.groupLabel, // l10n: sup_rateA11y
    required this.starLabel, // l10n: sup_starA11y(value)
  }) : assert(value >= 0 && value <= 5);

  final int value;
  final RatingMode mode;
  final RatingSize size;
  final ValueChanged<int>? onChanged;
  final String groupLabel;
  final String Function(int value) starLabel;

  @override
  Widget build(BuildContext context) {
    final md = size == RatingSize.md;
    final box = md ? 40.0 : 20.0;
    final star = md ? 32.0 : 16.0;
    final gap = md ? 10.0 : 2.0;
    final locked = mode == RatingMode.locked;
    final onFill = locked ? GapsTokens.violet60 : GapsTokens.brand;
    final offStroke = locked ? GapsTokens.violet40 : GapsTokens.violet60;
    final interactive = mode == RatingMode.input && onChanged != null;

    return Semantics(
      label: groupLabel,
      container: true,
      child: SizedBox(
        height: md ? 44 : 20,
        // Stars always run LTR: 1 on the left, 5 on the right.
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 1; i <= 5; i++) ...[
                if (i > 1) SizedBox(width: gap),
                Semantics(
                  inMutuallyExclusiveGroup: true,
                  checked: i == value,
                  button: interactive,
                  label: starLabel(i),
                  onTap: interactive ? () => onChanged!(i) : null,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: interactive ? () => onChanged!(i) : null,
                    // Keep a 44 px hit area even for the 40 px box.
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: md ? 2 : 0),
                      child: SizedBox.square(
                        dimension: box,
                        child: Center(
                          child: CustomPaint(
                            size: Size.square(star),
                            painter: _StarPainter(
                              fill: i <= value ? onFill : null,
                              stroke: i <= value ? onFill : offStroke,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  _StarPainter({required this.fill, required this.stroke});
  final Color? fill;
  final Color stroke;

  // Points of the 24×24 star used in the designs (assets/icons/star.svg).
  static const _pts = <Offset>[
    Offset(12, 3.6), Offset(14.5, 8.8), Offset(20.1, 9.6), Offset(16, 13.5), Offset(17, 19.1),
    Offset(12, 16.4), Offset(7, 19.1), Offset(8, 13.5), Offset(3.9, 9.6), Offset(9.5, 8.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    final path = Path()..moveTo(_pts.first.dx * s, _pts.first.dy * s);
    for (final p in _pts.skip(1)) {
      path.lineTo(p.dx * s, p.dy * s);
    }
    path.close();
    if (fill != null) canvas.drawPath(path, Paint()..color = fill!);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * s
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.fill != fill || old.stroke != stroke;
}

// ---------------------------------------------------------------------------
// SuggestionRow — SPEC §3.2
// ---------------------------------------------------------------------------

enum Confidence { high, low }

class SuggestionRow extends StatelessWidget {
  const SuggestionRow({
    super.key,
    required this.field,
    required this.value,
    required this.checked,
    required this.onChanged,
    this.confidence = Confidence.high,
    this.applied = false,
    this.ltrValue = true,
    this.showDivider = false,
    required this.lowConfidenceLabel, // l10n: pass_lowConfidence
    required this.appliedLabel, // l10n: pass_appliedChip
  });

  final String field;
  final String value;
  final bool checked;
  final ValueChanged<bool>? onChanged;
  final Confidence confidence;
  final bool applied;
  final bool ltrValue;
  final bool showDivider;
  final String lowConfidenceLabel;
  final String appliedLabel;

  @override
  Widget build(BuildContext context) {
    final low = confidence == Confidence.low && !applied;
    return Semantics(
      checked: checked,
      // Join with the locale's list separator if the project has one.
      label: [field, value, if (low) lowConfidenceLabel].join(', '),
      onTap: onChanged == null ? null : () => onChanged!(!checked),
      excludeSemantics: true,
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged!(!checked),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
          decoration: BoxDecoration(
            color: low ? GapsTokens.violet05 : Colors.white,
            border: showDivider ? const Border(top: BorderSide(color: GapsTokens.line)) : null,
          ),
          child: Row(children: [
            _Check(checked: checked),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(field, style: GapsTokens.caption),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    value,
                    textDirection: ltrValue ? TextDirection.ltr : TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GapsTokens.bodyStrong,
                  ),
                ),
              ]),
            ),
            if (applied) ...[
              const SizedBox(width: 12),
              GapsChip(label: appliedLabel, tone: GapsTokens.completed),
            ] else if (low) ...[
              const SizedBox(width: 12),
              GapsChip(label: lowConfidenceLabel, tone: GapsTokens.action),
            ],
          ]),
        ),
      ),
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.checked});
  final bool checked;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: checked ? GapsTokens.brand : Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: checked ? null : Border.all(color: GapsTokens.lineStrong, width: 1.5),
      ),
      child: checked ? const Icon(Icons.check_rounded, size: 16, color: Colors.white) : null,
    );
  }
}

// ---------------------------------------------------------------------------
// ReportTable — SPEC §3.3
// ---------------------------------------------------------------------------

@immutable
class ReportColumn {
  const ReportColumn(this.title, {required this.width, this.numeric = false, this.ltr = false});
  final String title;
  final double width;
  final bool numeric;
  final bool ltr;
}

enum _CellKind { header, body, total }

/// Card-less table body. Wrap it in the project's card (radius 22, no padding).
/// `columns[0]` is the sticky column. `rows[i]` and `totals` must have one entry per column
/// (use '' for empty total cells).
class ReportTable extends StatefulWidget {
  const ReportTable({super.key, required this.columns, required this.rows, required this.totals});
  final List<ReportColumn> columns;
  final List<List<String>> rows;
  final List<String> totals;

  @override
  State<ReportTable> createState() => _ReportTableState();
}

class _ReportTableState extends State<ReportTable> {
  final _scroll = ScrollController();
  double _thumbStart = 0; // 0..1 of the scrollable track
  double _thumbSize = 1;
  bool _moreHidden = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  void _update() {
    if (!mounted || !_scroll.hasClients || !_scroll.position.hasContentDimensions) return;
    final p = _scroll.position;
    final total = p.maxScrollExtent + p.viewportDimension;
    setState(() {
      _thumbSize = total == 0 ? 1 : p.viewportDimension / total;
      _thumbStart = p.maxScrollExtent == 0 ? 0 : (p.pixels / p.maxScrollExtent) * (1 - _thumbSize);
      _moreHidden = p.pixels < p.maxScrollExtent - 1;
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Widget _cell(String text, ReportColumn col, _CellKind kind, {bool sticky = false}) {
    final style = switch (kind) {
      _CellKind.header => const TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500, color: GapsTokens.secondary),
      _CellKind.body => const TextStyle(fontSize: 13, height: 20 / 13, color: GapsTokens.ink),
      _CellKind.total => const TextStyle(fontSize: 13, height: 20 / 13, fontWeight: FontWeight.w500, color: GapsTokens.ink),
    };
    final ltr = col.numeric || col.ltr;
    return Container(
      width: col.width,
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: col.numeric ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      decoration: BoxDecoration(
        color: kind == _CellKind.body ? Colors.white : GapsTokens.violet05,
        border: BorderDirectional(
          top: switch (kind) {
            _CellKind.header => BorderSide.none,
            _CellKind.body => const BorderSide(color: GapsTokens.line),
            _CellKind.total => const BorderSide(color: GapsTokens.lineStrong),
          },
          // The sticky column sits at the start; its divider is on its end edge (left in RTL).
          end: sticky ? const BorderSide(color: GapsTokens.line) : BorderSide.none,
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: ltr ? TextDirection.ltr : null,
        style: style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }

  Widget _column(int c, {bool sticky = false}) {
    final col = widget.columns[c];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      _cell(col.title, col, _CellKind.header, sticky: sticky),
      for (final r in widget.rows) _cell(r[c], col, _CellKind.body, sticky: sticky),
      _cell(widget.totals[c], col, _CellKind.total, sticky: sticky),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _column(0, sticky: true),
        Expanded(
          child: Stack(children: [
            NotificationListener<ScrollMetricsNotification>(
              // Keeps the fade and thumb right when data, width or text scale change.
              onNotification: (_) {
                WidgetsBinding.instance.addPostFrameCallback((_) => _update());
                return false;
              },
              child: SingleChildScrollView(
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                // In RTL a horizontal scroll view starts at the right edge.
                child: Row(children: [for (var c = 1; c < widget.columns.length; c++) _column(c)]),
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
                        colors: [Colors.white, Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      ]),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
        child: LayoutBuilder(builder: (context, c) {
          final w = c.maxWidth;
          final thumbW = (w * _thumbSize).clamp(math.min(24.0, w), w);
          final offset = (w - thumbW) * (_thumbSize >= 1 ? 0 : _thumbStart / (1 - _thumbSize));
          return SizedBox(
            height: 4,
            child: Stack(children: [
              Container(decoration: BoxDecoration(color: GapsTokens.line, borderRadius: BorderRadius.circular(999))),
              Positioned(
                // Thumb starts at the right in RTL.
                left: rtl ? null : offset,
                right: rtl ? offset : null,
                top: 0,
                bottom: 0,
                width: thumbW,
                child: Container(decoration: BoxDecoration(color: GapsTokens.violet40, borderRadius: BorderRadius.circular(999))),
              ),
            ]),
          );
        }),
      ),
    ]);
  }
}

// ---------------------------------------------------------------------------
// CountdownPill — SPEC §3.4
// ---------------------------------------------------------------------------

class CountdownPill extends StatelessWidget {
  const CountdownPill({
    super.key,
    required this.seconds,
    this.total = 30,
    required this.text, // l10n: priv_countdown(seconds)  → «٣٠ ث»
    required this.semanticLabel, // l10n: priv_countdownA11y(seconds)
    this.announce = false, // true only at 10 s and at hide (SPEC §3.4)
  });

  final int seconds;
  final int total;
  final String text;
  final String semanticLabel;
  final bool announce;

  @override
  Widget build(BuildContext context) {
    final tone = seconds <= 5 ? GapsTokens.action : GapsTokens.processing;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final ring = CustomPaint(size: const Size.square(16), painter: _RingPainter(seconds / total, tone.fg));
    return Semantics(
      liveRegion: announce,
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        height: 28,
        padding: const EdgeInsetsDirectional.only(start: 10, end: 8), // CSS «0 10 0 8» in RTL
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(999)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          reduceMotion
              ? ring
              : TweenAnimationBuilder<double>(
                  tween: Tween(end: seconds / total),
                  duration: const Duration(milliseconds: 900),
                  builder: (_, v, __) => CustomPaint(size: const Size.square(16), painter: _RingPainter(v, tone.fg)),
                ),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(fontSize: 11, height: 16 / 11, fontWeight: FontWeight.w500, color: tone.fg)),
        ]),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.color);
  final double fraction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Rect.fromLTWH(1.6, 1.6, size.width - 3.2, size.height - 3.2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(r, p..color = color.withValues(alpha: .22));
    canvas.drawArc(r, -math.pi / 2, 2 * math.pi * fraction.clamp(0.0, 1.0), false, p..color = color);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}

// ---------------------------------------------------------------------------
// RevealController — SPEC §5.2
// ---------------------------------------------------------------------------

sealed class RevealFailure implements Exception {}

class RevealRateLimited extends RevealFailure {
  RevealRateLimited(this.retryAfter);
  final Duration retryAfter;
}

class RevealForbidden extends RevealFailure {}

/// One controller per screen. Holds at most ONE revealed value, in memory only.
///
/// `fetch` calls the server reveal endpoint and returns the plain value, or throws
/// [RevealRateLimited] / [RevealForbidden]. Hook `onSecureChanged` to toggle Android
/// FLAG_SECURE (e.g. via a platform channel or a plugin the project already uses).
class RevealController extends ChangeNotifier with WidgetsBindingObserver {
  RevealController({required this.fetch, this.duration = const Duration(seconds: 30), this.onSecureChanged}) {
    WidgetsBinding.instance.addObserver(this);
  }

  final Future<String> Function(String field) fetch;
  final Duration duration;
  final ValueChanged<bool>? onSecureChanged;

  String? _field; // field currently revealed or loading
  String? _value;
  int _secondsLeft = 0;
  bool _loading = false;
  Timer? _timer;
  DateTime? _blockedUntil;
  bool _forbidden = false;
  int _request = 0;
  bool _disposed = false;

  String? get field => _field;
  bool isLoading(String field) => _loading && _field == field;
  String? valueOf(String field) => _field == field ? _value : null;
  int get secondsLeft => _secondsLeft;
  bool get forbidden => _forbidden;
  /// Not a listenable: tick it from the UI (e.g. a 30 s Timer) to refresh the minutes text.
  Duration? get blockedFor {
    final until = _blockedUntil;
    if (until == null) return null;
    final d = until.difference(DateTime.now());
    return d.isNegative ? null : d;
  }

  Future<void> reveal(String field) async {
    if (_forbidden || blockedFor != null) return;
    hide(); // only one value at a time
    final id = ++_request;
    _field = field;
    _loading = true;
    notifyListeners();
    try {
      final v = await fetch(field);
      if (_disposed || id != _request) return; // disposed, hidden or another reveal started meanwhile
      _value = v;
      _loading = false;
      _secondsLeft = duration.inSeconds;
      onSecureChanged?.call(true);
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          hide();
        } else {
          notifyListeners();
        }
      });
      notifyListeners();
    } on RevealRateLimited catch (e) {
      if (_disposed || id != _request) return;
      _blockedUntil = DateTime.now().add(e.retryAfter);
      _clear();
    } on RevealForbidden {
      if (_disposed || id != _request) return;
      _forbidden = true;
      _clear();
    } catch (_) {
      if (_disposed || id != _request) return;
      _clear();
      rethrow; // let the screen show its generic error
    }
  }

  void hide() {
    _request++;
    if (_disposed) return;
    _clear();
  }

  void _clear() {
    final wasVisible = _value != null;
    _timer?.cancel();
    _timer = null;
    _field = null;
    _value = null;
    _loading = false;
    _secondsLeft = 0;
    if (wasVisible) onSecureChanged?.call(false);
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Hide when the app goes to the background. Add `inactive` too if you also want to hide
    // behind system overlays (Control Center, biometric prompts).
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) hide();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    if (_value != null) onSecureChanged?.call(false);
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Masking — SPEC §5
// ---------------------------------------------------------------------------

abstract final class Masking {
  static const _dot = '•';

  /// `N08494821` → `••••••4821`
  static String keepLast4(String v) =>
      v.length <= 4 ? _dot * 6 : '${_dot * 6}${v.substring(v.length - 4)}'; // fixed 6 dots: never leaks length

  /// `sara.a@mail.com` → `sa•••••@mail.com`
  static String email(String v) {
    final at = v.indexOf('@');
    if (at <= 0) return keepLast4(v);
    final head = v.substring(0, math.min(2, at));
    return '$head${_dot * 5}${v.substring(at)}';
  }

  /// `+966 512 345 214` → `+966 5•• ••• 214`
  static String phone(String v) {
    var digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1); // local format 05…
    if (digits.length < 9) return keepLast4(v);
    final cc = digits.substring(0, digits.length - 9); // country code (e.g. 966), may be empty
    final local = digits.substring(digits.length - 9); // 9-digit local number
    final prefix = cc.isEmpty ? '' : '+$cc ';
    return '$prefix${local[0]}$_dot$_dot $_dot$_dot$_dot ${local.substring(6)}';
  }
}

// ---------------------------------------------------------------------------
// Arabic search normalisation — SPEC §10.2
// ---------------------------------------------------------------------------

String normalizeArabic(String input) {
  return input
      .replaceAll(RegExp('[\u064B-\u065F\u0670\u0640]'), '') // tashkeel U+064B–065F, superscript alef U+0670, tatweel U+0640 (digits U+0660+ untouched)
      .replaceAll(RegExp('[\u0623\u0625\u0622\u0671]'), '\u0627') // hamza/madda/wasla alef forms → bare alef
      .replaceAll('\u0629', '\u0647') // teh marbuta → heh
      .replaceAll('\u0649', '\u064A') // alef maksura → yeh
      .toLowerCase()
      .trim();
}

bool categoryMatches(String query, String title, String description) {
  final q = normalizeArabic(query);
  if (q.isEmpty) return true;
  return normalizeArabic(title).contains(q) || normalizeArabic(description).contains(q);
}
