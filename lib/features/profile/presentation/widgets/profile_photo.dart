// The signed-in user's photo where the app shows one (Account card, Home header): the photo when
// there is one, otherwise the [fallback] the screen always had. Optionally tappable with a
// camera badge (PROF-01), and a progress ring while a new photo is being sent (PROF-03).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../bloc/avatar_cubit.dart';

class ProfilePhoto extends StatefulWidget {
  const ProfilePhoto({super.key, required this.size, required this.fallback, this.onTap, this.cubit});

  final double size;

  /// What shows when there is no photo (the screen's own avatar).
  final Widget fallback;

  /// Makes the photo tappable and adds the camera badge; null = a plain, read-only photo.
  final VoidCallback? onTap;

  /// Test seam; defaults to the app's shared [AvatarCubit].
  final AvatarCubit? cubit;

  @override
  State<ProfilePhoto> createState() => _ProfilePhotoState();
}

class _ProfilePhotoState extends State<ProfilePhoto> {
  AvatarCubit? _cubit;

  @override
  void initState() {
    super.initState();
    try {
      _cubit = widget.cubit ?? InjectionContainer.instance.avatarCubit;
    } on Object {
      // No container in scope (a bare widget test): the fallback is all there is.
      _cubit = null;
    }
    _cubit?.load();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = _cubit;
    if (cubit == null) {
      return _frame(context, null, null);
    }
    return BlocBuilder<AvatarCubit, AvatarState>(
      bloc: cubit,
      buildWhen: (a, b) => a.url != b.url || a.progress != b.progress,
      builder: (context, state) => _frame(context, state.url, state.progress),
    );
  }

  Widget _frame(BuildContext context, String? url, double? progress) {
    final c = SeenColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final size = widget.size;
    final photo = SizedBox(
      width: size,
      height: size,
      child: url == null
          ? widget.fallback
          : ClipOval(
              child: Image.network(
                url,
                width: size,
                height: size,
                fit: BoxFit.cover,
                // A link that no longer works shows the usual avatar, never a broken image.
                errorBuilder: (_, __, ___) => widget.fallback,
              ),
            ),
    );
    final badge = size * .44;
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        photo,
        if (progress != null)
          Positioned.fill(
            child: CustomPaint(painter: _ProgressRing(progress, c.accent, c.card.withOpacity(.7))),
          ),
        if (widget.onTap != null)
          PositionedDirectional(
            end: -2,
            bottom: -2,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: c.card,
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
                boxShadow: SeenShadows.card,
              ),
              child: Icon(SeenIcons.camera, size: badge * .55, color: c.accent),
            ),
          ),
      ],
    );
    if (widget.onTap == null) {
      return content;
    }
    return Semantics(
      button: true,
      label: l10n.profChangePhoto,
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: widget.onTap, child: content),
    );
  }
}

class _ProgressRing extends CustomPainter {
  _ProgressRing(this.fraction, this.color, this.track);

  final double fraction;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final box = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawOval(box.deflate(3), paint..color = track);
    canvas.drawArc(box.deflate(3), -math.pi / 2, 2 * math.pi * fraction.clamp(0.0, 1.0), false, paint..color = color);
  }

  @override
  bool shouldRepaint(_ProgressRing old) => old.fraction != fraction || old.color != color || old.track != track;
}
