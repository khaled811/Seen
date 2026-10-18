// Shared components in all their states (Figma SYS-08). A development aid: opened from
// Settings in debug builds only, never from release.
import 'package:flutter/material.dart';

import '../../theme/seen_colors.dart';
import '../../theme/seen_dimensions.dart';
import '../../theme/seen_typography.dart';
import '../foundation/seen_icons.dart';
import '../widgets/avatar.dart';
import '../widgets/components.dart';
import '../widgets/inline_banner.dart';
import '../widgets/screen_background.dart';
import '../widgets/screen_header.dart';
import '../widgets/selection.dart';

class ComponentsGalleryScreen extends StatefulWidget {
  const ComponentsGalleryScreen({super.key});

  static Route<void> route() => MaterialPageRoute<void>(builder: (_) => const ComponentsGalleryScreen());

  @override
  State<ComponentsGalleryScreen> createState() => _ComponentsGalleryScreenState();
}

class _ComponentsGalleryScreenState extends State<ComponentsGalleryScreen> {
  bool _check = true;
  bool _switch = true;
  int _radio = 1;

  @override
  Widget build(BuildContext context) {
    final c = SeenColors.of(context);
    final t = SeenType.of(context);
    Widget label(String text) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 8),
          child: Text(text, style: t.caption.copyWith(color: c.inkMuted)),
        );
    return Scaffold(
      backgroundColor: c.card,
      body: SeenScreenBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SeenScreenHeader(title: 'مكوّنات'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, SeenSpace.s6),
                  children: [
                    label('Toast'),
                    const SeenToast(message: 'تم الحفظ', actionLabel: 'تراجع'),
                    TextButton(
                      onPressed: () => showSeenToast(context, message: 'تم الحفظ', actionLabel: 'تراجع', onAction: () {}),
                      child: const Text('show'),
                    ),
                    label('Banners'),
                    const SeenInlineBanner(tone: SeenBannerTone.info, message: 'معلومة'),
                    const SizedBox(height: 8),
                    const SeenInlineBanner(tone: SeenBannerTone.warn, message: 'تنبيه'),
                    const SizedBox(height: 8),
                    const SeenInlineBanner(tone: SeenBannerTone.error, message: 'خطأ'),
                    const SizedBox(height: 8),
                    const SeenInlineBanner(tone: SeenBannerTone.ok, message: 'تم'),
                    label('List row'),
                    SeenListRow(icon: SeenIcons.gear, title: 'عنوان الصف', subtitle: 'وصف قصير', onTap: () {}),
                    label('Checkbox · Radio · Switch · States'),
                    Row(
                      children: [
                        SeenCheckbox(value: _check, onChanged: (v) => setState(() => _check = v)),
                        const SeenCheckbox(value: false, onChanged: null),
                        const SeenCheckbox(value: true, onChanged: null),
                        const SizedBox(width: 8),
                        for (var i = 0; i < 2; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _radio = i),
                              child: SeenRadioDot(selected: _radio == i),
                            ),
                          ),
                        const Spacer(),
                        SeenSwitch(value: _switch, onChanged: (v) => setState(() => _switch = v)),
                        const SeenSwitch(value: false, onChanged: null),
                      ],
                    ),
                    label('Avatar · Badge · Progress'),
                    const Row(
                      children: [
                        SeenProgressBar(fraction: .58, width: 120),
                        SizedBox(width: 12),
                        SeenCountBadge(count: 3),
                        SizedBox(width: 12),
                        SeenAvatar(initial: 'MA'),
                        SizedBox(width: 12),
                        SeenAvatar(initial: 'ر', size: 32),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
