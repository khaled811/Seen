// OtpInput · NotificationTile
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';
import '../foundation/seen_strings.dart';

/// Six-cell one-time-code entry. One hidden TextField (SMS autofill via
/// AutofillHints.oneTimeCode) drives the painted cells. Cells are always LTR.
class SeenOtpInput extends StatefulWidget {
  const SeenOtpInput({
    super.key,
    this.length = 6,
    this.controller,
    this.onCompleted,
    this.onChanged,
    this.error = false,
    this.autofocus = true,
  });

  final int length;
  final TextEditingController? controller;

  /// Fires when all digits are entered — auto-submit here.
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;

  /// Outlines every cell in dangerFg; show the reason as text below.
  final bool error;
  final bool autofocus;

  @override
  State<SeenOtpInput> createState() => _SeenOtpInputState();
}

class _SeenOtpInputState extends State<SeenOtpInput> {
  late final TextEditingController _controller = widget.controller ?? TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onText);
    _focus.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  String _last = '';

  void _onText() {
    final v = _controller.text;
    if (v == _last) return; // ignore selection / IME composing notifications
    _last = v;
    widget.onChanged?.call(v);
    if (v.length == widget.length) widget.onCompleted?.call(v);
    setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onText);
    if (widget.controller == null) _controller.dispose();
    _focus
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final value = _controller.text;
    final digit = seenStyle(22, 28, FontWeight.w500, c.ink, family: SeenFonts.mono);

    return Semantics(
      label: SeenStrings.of(context).otpLabel,
      textField: true,
      value: value,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _focus.requestFocus(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < widget.length; i++) ...[
                    if (i > 0) const SizedBox(width: SeenSpace.s2),
                    _cell(c, digit, i < value.length ? value[i] : '',
                        active: _focus.hasFocus && !widget.error && i == value.length),
                  ],
                ],
              ),
              // The real input: invisible, covers the cells, owns the keyboard & autofill.
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: widget.length,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cell(SeenColors c, TextStyle digit, String ch, {required bool active}) {
    final Color border = widget.error ? c.dangerFg : (active ? c.focus : c.borderStrong);
    return Container(
      width: 48,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: const BorderRadius.all(SeenRadius.sm),
        border: Border.all(color: border, width: active || widget.error ? 2 : 1),
      ),
      child: ch.isNotEmpty
          ? Text(ch, style: digit)
          : (active ? Container(width: 2, height: 24, color: c.focus) : null),
    );
  }
}

enum SeenNotificationKind { review, action, approved, sla, wallet, agent, system }

extension on SeenNotificationKind {
  SeenTone get tone => switch (this) {
        SeenNotificationKind.review => SeenTone.pending,
        SeenNotificationKind.action => SeenTone.danger,
        SeenNotificationKind.approved || SeenNotificationKind.wallet => SeenTone.success,
        SeenNotificationKind.sla => SeenTone.sla,
        SeenNotificationKind.agent || SeenNotificationKind.system => SeenTone.neutral,
      };

  IconData get icon => switch (this) {
        SeenNotificationKind.review || SeenNotificationKind.sla => SeenIcons.clock,
        SeenNotificationKind.action => SeenIcons.alert,
        SeenNotificationKind.approved => SeenIcons.check,
        SeenNotificationKind.wallet => SeenIcons.credit,
        SeenNotificationKind.agent => SeenIcons.users,
        SeenNotificationKind.system => SeenIcons.info,
      };
}

/// Notification row: 36px round tone icon, title, one-line body, reference, time.
/// Unread = primarySoft fill + accentInk dot. Place inside a [SeenListGroup].
class SeenNotificationTile extends StatelessWidget {
  const SeenNotificationTile({
    super.key,
    required this.kind,
    required this.title,
    required this.body,
    required this.time,
    this.reference,
    this.unread = false,
    this.onTap,
  });

  final SeenNotificationKind kind;
  final String title;
  final String body;
  final String time;
  final String? reference;
  final bool unread;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final text = Theme.of(context).textTheme;
    final t = c.tone(kind.tone);
    final ink = kind.tone == SeenTone.neutral ? c.slate : t.fg;

    return Semantics(
      label: unread ? SeenStrings.of(context).unread : null,
      child: Material(
        color: unread ? c.primarySoft : c.card,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: SeenSpace.s4, vertical: SeenSpace.s3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(color: t.bg, shape: BoxShape.circle, border: Border.all(color: t.line)),
                  child: Icon(kind.icon, size: 18, color: ink),
                ),
                const SizedBox(width: SeenSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Expanded(child: Text(title, style: text.bodyMedium!.copyWith(fontWeight: FontWeight.w600))),
                          const SizedBox(width: SeenSpace.s2),
                          Text(time, style: text.labelSmall!.copyWith(fontFeatures: SeenFonts.tabular)),
                        ],
                      ),
                      Text(body, style: text.bodySmall!.copyWith(color: c.inkSecondary)),
                      if (reference != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(reference!,
                              textDirection: TextDirection.ltr,
                              style: SeenType.of(context).refMono.copyWith(fontSize: 11, color: c.inkMuted)),
                        ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: SeenSpace.s2),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(color: c.accentInk, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
