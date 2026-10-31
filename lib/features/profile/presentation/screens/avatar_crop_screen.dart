// Crop the profile photo (design/gaps PROF-02): pan and zoom inside a circle, then "Use". The
// result is a square 512 x 512 PNG made from what is inside the circle. Light surfaces only.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../../../core/presentation/foundation/seen_icons.dart';
import '../../../../core/presentation/widgets/actions.dart';
import '../../../../core/presentation/widgets/chrome.dart';
import '../../../../core/presentation/widgets/screen_background.dart';
import '../../../../core/presentation/widgets/screen_header.dart';
import '../../../../core/theme/seen_colors.dart';
import '../../../../core/theme/seen_dimensions.dart';
import '../../../../core/theme/seen_typography.dart';
import '../../domain/entities/avatar.dart';

/// What the crop screen returns: the cropped photo, or "pick another".
class AvatarCropResult {
  const AvatarCropResult.cropped(Uint8List this.bytes) : redo = false;
  const AvatarCropResult.redo()
      : bytes = null,
        redo = true;

  final Uint8List? bytes;
  final bool redo;
}

class AvatarCropScreen extends StatefulWidget {
  const AvatarCropScreen({super.key, required this.picked, this.loadBytes});

  final PickedAvatar picked;

  /// Test seam; defaults to reading the picked file.
  final Future<Uint8List> Function(String path)? loadBytes;

  /// The side of the cropped photo, in pixels.
  static const outputSize = 512;

  static Future<AvatarCropResult?> open(BuildContext context, PickedAvatar picked) =>
      Navigator.of(context).push<AvatarCropResult>(MaterialPageRoute(builder: (_) => AvatarCropScreen(picked: picked)));

  @override
  State<AvatarCropScreen> createState() => _AvatarCropScreenState();
}

class _AvatarCropScreenState extends State<AvatarCropScreen> {
  static const _viewport = 350.0;
  static const _circle = 280.0;
  static const _maxZoom = 4.0;

  // Owned here, disposed in dispose().
  final _transform = TransformationController();
  final _boundary = GlobalKey();
  Uint8List? _bytes;
  bool _failed = false;
  bool _busy = false;
  double _zoom = 1;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_onTransform);
    _read();
  }

  Future<void> _read() async {
    try {
      final bytes = await (widget.loadBytes ?? (p) => File(p).readAsBytes())(widget.picked.path);
      if (mounted) {
        setState(() => _bytes = bytes);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_onTransform)
      ..dispose();
    super.dispose();
  }

  void _onTransform() {
    final z = _transform.value.getMaxScaleOnAxis().clamp(1.0, _maxZoom);
    if ((z - _zoom).abs() > .01) {
      setState(() => _zoom = z);
    }
  }

  /// Zooms about the centre of the frame and keeps the photo covering it.
  void _setZoom(double zoom) {
    final m = _transform.value;
    final s0 = m.getMaxScaleOnAxis();
    const centre = _viewport / 2;
    final px = (centre - m.storage[12]) / s0;
    final py = (centre - m.storage[13]) / s0;
    final low = _viewport - _viewport * zoom;
    final tx = (centre - px * zoom).clamp(low, 0.0);
    final ty = (centre - py * zoom).clamp(low, 0.0);
    _transform.value = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(zoom);
  }

  Future<void> _use() async {
    if (_busy || _bytes == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      const ratio = 2.0;
      final shot = await boundary.toImage(pixelRatio: ratio);
      const side = _circle * ratio;
      final from = Rect.fromLTWH((shot.width - side) / 2, (shot.height - side) / 2, side, side);
      final recorder = ui.PictureRecorder();
      const out = AvatarCropScreen.outputSize;
      final canvas = Canvas(recorder);
      canvas.drawImageRect(shot, from, Rect.fromLTWH(0, 0, out.toDouble(), out.toDouble()), Paint()..filterQuality = FilterQuality.high);
      final image = await recorder.endRecording().toImage(out, out);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      shot.dispose();
      image.dispose();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(AvatarCropResult.cropped(data!.buffer.asUint8List()));
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final c = SeenColors.of(context);
    final type = SeenType.of(context);
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SeenScreenHeader(
                title: l10n.profCropTitle,
                showBack: false,
                trailing: SeenRoundIconButton(
                  icon: SeenIcons.x,
                  semanticLabel: l10n.commonClose,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Center(
                      child: SizedBox(
                        width: _viewport,
                        height: _viewport,
                        child: ClipRRect(
                          borderRadius: const BorderRadius.all(SeenRadius.r22),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              RepaintBoundary(
                                key: _boundary,
                                child: ColoredBox(
                                  color: c.surfaceSunken,
                                  child: _bytes == null
                                      ? const SizedBox.expand()
                                      : InteractiveViewer(
                                          transformationController: _transform,
                                          minScale: 1,
                                          maxScale: _maxZoom,
                                          child: SizedBox(
                                            width: _viewport,
                                            height: _viewport,
                                            child: Image.memory(_bytes!, fit: BoxFit.cover, gaplessPlayback: true),
                                          ),
                                        ),
                                ),
                              ),
                              // A light veil outside the circle (never a dark scrim) and the circle's outline.
                              IgnorePointer(child: CustomPaint(painter: _CircleVeil(c.card, c.accent))),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(SeenIcons.image, size: 14, color: c.inkSecondary),
                        Expanded(
                          child: Slider(
                            value: _zoom,
                            min: 1,
                            max: _maxZoom,
                            activeColor: c.accent,
                            inactiveColor: c.border,
                            onChanged: _bytes == null ? null : _setZoom,
                          ),
                        ),
                        Icon(SeenIcons.image, size: 22, color: c.inkSecondary),
                      ],
                    ),
                    Text(
                      _failed ? l10n.commonCheckConnection : l10n.profCropHint,
                      style: type.caption.copyWith(color: c.inkSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SeenActionBar(actions: [
                SeenButton.secondary(
                  label: l10n.profRedo,
                  expand: true,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(const AvatarCropResult.redo()),
                ),
                SeenButton(label: l10n.profUse, expand: true, loading: _busy, onPressed: _bytes == null || _busy ? null : _use),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleVeil extends CustomPainter {
  _CircleVeil(this.veil, this.outline);

  final Color veil;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * (280 / 350) / 2;
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: centre, radius: radius))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = veil.withOpacity(.6));
    canvas.drawCircle(centre, radius, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = outline);
  }

  @override
  bool shouldRepaint(_CircleVeil old) => old.veil != veil || old.outline != outline;
}
