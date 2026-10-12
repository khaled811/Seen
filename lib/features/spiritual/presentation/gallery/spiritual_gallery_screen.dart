import 'package:flutter/material.dart';

import '../theme/spiritual_theme.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/arabic_number.dart';
import '../widgets/kaaba_glyph.dart';
import '../widgets/octagon_badge.dart';
import '../widgets/progress_ring.dart';
import '../widgets/segmented_ring.dart';
import '../widgets/service_tile.dart';
import '../widgets/spiritual_bottom_nav.dart';
import '../widgets/spiritual_bottom_sheet.dart';
import '../widgets/spiritual_card.dart';
import '../widgets/spiritual_chip_row.dart';
import '../widgets/spiritual_icon_button.dart';
import '../widgets/spiritual_outlined_button.dart';
import '../widgets/spiritual_pill.dart';
import '../widgets/spiritual_primary_button.dart';
import '../widgets/spiritual_progress_bar.dart';
import '../widgets/spiritual_scaffold.dart';
import '../widgets/spiritual_segmented.dart';
import '../widgets/spiritual_top_bar.dart';

/// Debug-only catalogue of every hub component in its states (reached from
/// the Manasik placeholder in debug builds; also the golden-test subject).
class SpiritualGalleryScreen extends StatelessWidget {
  const SpiritualGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const SpiritualTheme(child: SpiritualGalleryBody());
}

class SpiritualGalleryBody extends StatefulWidget {
  const SpiritualGalleryBody({super.key});

  @override
  State<SpiritualGalleryBody> createState() => _SpiritualGalleryBodyState();
}

class _SpiritualGalleryBodyState extends State<SpiritualGalleryBody> {
  String _segment = 'tawaf';
  String _chip = 'all';
  int _lap = 3;
  int _nav = 0;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return SpiritualScaffold(
      topBar: const SpiritualTopBar(
        title: 'معرض المكوّنات',
        subtitle: 'Spiritual hub',
      ),
      bottomNav: SpiritualBottomNav(
        destinations: const [
          SpiritualNavDestination(icon: Icons.home_outlined, label: 'الرئيسية'),
          SpiritualNavDestination(icon: Icons.mosque_outlined, label: 'المناسك'),
          SpiritualNavDestination(icon: Icons.menu_book_outlined, label: 'المصحف'),
          SpiritualNavDestination(icon: Icons.person_outline, label: 'حسابي'),
        ],
        selectedIndex: _nav,
        onSelected: (i) => setState(() => _nav = i),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: SpiritualSpace.s16),
        children: [
          _section('Buttons', [
            SpiritualPrimaryButton(
              label: 'متابعة النسك',
              trailingIcon: Icons.arrow_back,
              onPressed: () {},
            ),
            const SizedBox(height: SpiritualSpace.s12),
            SpiritualPrimaryButton(
              large: true,
              label: '+ تسجيل الشوط التالي',
              subtitle: 'اضغط عند محاذاة الحجر الأسود',
              onPressed: () {},
            ),
            const SizedBox(height: SpiritualSpace.s12),
            const SpiritualPrimaryButton(label: 'معطّل', onPressed: null),
            const SizedBox(height: SpiritualSpace.s12),
            Wrap(
              spacing: SpiritualSpace.s12,
              runSpacing: SpiritualSpace.s12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SpiritualOutlinedButton(label: 'إنهاء النسك', onPressed: () {}),
                const SpiritualOutlinedButton(label: 'إلغاء شوط', onPressed: null),
                SpiritualIconButton(
                  icon: Icons.person_outline,
                  semanticLabel: 'الحساب',
                  onPressed: () {},
                ),
              ],
            ),
          ]),
          _section('Segmented & chips', [
            SpiritualSegmented<String>(
              options: const [
                SegmentOption(value: 'tawaf', label: 'الطواف'),
                SegmentOption(value: 'sai', label: 'السعي'),
              ],
              value: _segment,
              onChanged: (v) => setState(() => _segment = v),
            ),
            const SizedBox(height: SpiritualSpace.s12),
            SpiritualChipRow<String>(
              labels: const {
                'all': 'الكل',
                'hajj': 'العمرة والحج',
                'safar': 'أدعية السفر',
              },
              selected: _chip,
              onSelected: (v) => setState(() => _chip = v),
            ),
          ]),
          _section('Pills', [
            const Wrap(
              spacing: SpiritualSpace.s8,
              runSpacing: SpiritualSpace.s8,
              children: [
                SpiritualPill(label: 'تم تسجيل الشوط ٢'),
                SpiritualPill(label: 'متبقي ٠٠:٣٥', variant: PillVariant.accent, dot: true),
                SpiritualPill(
                  label: 'أنت تواجه القبلة',
                  variant: PillVariant.success,
                  icon: Icons.check,
                ),
                SpiritualPill(label: 'بعد ٣٥ د', variant: PillVariant.solid),
              ],
            ),
          ]),
          _section('Progress bars', [
            const SpiritualProgressBar(value: 0.6, fillColor: null),
            const SizedBox(height: SpiritualSpace.s12),
            SpiritualProgressBar(value: 0.35, height: 6, fillColor: t.sage),
          ]),
          _section('Segmented ring (lap $_lap / 7)', [
            Center(
              child: SegmentedRing(
                completed: _lap,
                showCurrent: _lap < 7,
                size: 200,
                strokeWidth: 14,
                child: ArabicNumber(
                  '${_lap + 1 > 7 ? 7 : _lap + 1}',
                  style: SpiritualType.counterXL.copyWith(fontSize: 72),
                ),
              ),
            ),
            Slider(
              value: _lap.toDouble(),
              max: 7,
              divisions: 7,
              onChanged: (v) => setState(() => _lap = v.round()),
            ),
          ]),
          _section('Progress ring', [
            const Center(
              child: ProgressRing(
                value: 0.64,
                size: 180,
                child: ArabicNumber(
                  '64',
                  style: SpiritualType.counterL,
                ),
              ),
            ),
          ]),
          _section('Badges & glyph', [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                OctagonBadge(number: 1),
                OctagonBadge(number: 18, highlighted: true),
                OctagonBadge(number: 114),
                KaabaGlyph(),
              ],
            ),
          ]),
          _section('Service tiles', [
            Row(
              children: [
                Expanded(
                  child: ServiceTile(
                    icon: Icons.menu_book_outlined,
                    label: 'المصحف الشريف',
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: SpiritualSpace.s12),
                Expanded(
                  child: ServiceTile(
                    icon: Icons.explore_outlined,
                    label: 'اتجاه القبلة',
                    onTap: () {},
                  ),
                ),
                const SizedBox(width: SpiritualSpace.s12),
                Expanded(
                  child: ServiceTile(
                    icon: Icons.schedule,
                    label: 'مواقيت الصلاة',
                    onTap: () {},
                  ),
                ),
              ],
            ),
          ]),
          _section('Bottom sheet', [
            SpiritualOutlinedButton(
              label: 'فتح النافذة',
              expand: true,
              onPressed: () => showSpiritualBottomSheet<void>(
                context,
                title: 'اختر الذكر',
                builder: (_) => const Text('محتوى النافذة'),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
        padding: const EdgeInsets.only(bottom: SpiritualSpace.s20),
        child: SpiritualCard(
          compact: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textDirection: TextDirection.ltr,
                style: SpiritualType.micro.copyWith(
                  color: SpiritualTokens.of(context).inkMuted,
                ),
              ),
              const SizedBox(height: SpiritualSpace.s12),
              ...children,
            ],
          ),
        ),
      );
}
