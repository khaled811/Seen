import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/arabic_digits.dart';
import '../../core/seen_haptics.dart';
import '../../domain/entities/quran.dart';
import '../spiritual_strings.dart';
import '../theme/spiritual_tokens.dart';
import '../widgets/spiritual_bottom_sheet.dart';
import '../widgets/spiritual_primary_button.dart';
import 'quran_display_text.dart';

String _sheetTitle(Surah surah, Ayah ayah) =>
    '${SpiritualStrings.ayahWord} ${toArabicDigits(ayah.number)} · '
    '${SpiritualStrings.surahWord} ${surah.nameAr}';

/// The ayah on its paper-coloured box, shared by both sheets.
class _AyahBox extends StatelessWidget {
  const _AyahBox({required this.ayah});

  final Ayah ayah;

  @override
  Widget build(BuildContext context) {
    final t = SpiritualTokens.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: t.bgReader,
        borderRadius: BorderRadius.circular(SpiritualRadius.button),
      ),
      child: Text(
        quranDisplayText(ayah.text),
        style: SpiritualType.quran.copyWith(
          fontSize: 24,
          height: 2,
          color: t.inkPrimary,
        ),
      ),
    );
  }
}

/// "التفسير والترجمة" sheet. The ayah is real; tafsir and translation are
/// placeholders until their datasets are bundled (docs/05-content.md).
Future<void> showAyahTafsirSheet(
  BuildContext context, {
  required Surah surah,
  required Ayah ayah,
}) =>
    showSpiritualBottomSheet<void>(
      context,
      title: _sheetTitle(surah, ayah),
      builder: (context) {
        final t = SpiritualTokens.of(context);
        TextStyle label() => SpiritualType.caption.copyWith(
              fontWeight: FontWeight.w700,
              color: t.accent,
            );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AyahBox(ayah: ayah),
            const SizedBox(height: SpiritualSpace.s14),
            Text(SpiritualStrings.meaningOfAyah, style: label()),
            const SizedBox(height: SpiritualSpace.s6),
            Text(
              SpiritualStrings.tafsirPlaceholder,
              style: SpiritualType.bodyStrong.copyWith(
                fontWeight: FontWeight.w400,
                height: 1.75,
                color: t.inkBody,
              ),
            ),
            const SizedBox(height: SpiritualSpace.s12),
            Divider(height: 1, color: t.readerDivider),
            const SizedBox(height: SpiritualSpace.s12),
            Text(SpiritualStrings.translationTitle, style: label()),
            const SizedBox(height: SpiritualSpace.s6),
            Text(
              SpiritualStrings.translationPlaceholder,
              style: SpiritualType.caption.copyWith(color: t.inkMuted),
            ),
          ],
        );
      },
    );

/// Long-press menu: copy the ayah (text plus its reference).
Future<void> showAyahCopySheet(
  BuildContext context, {
  required Surah surah,
  required Ayah ayah,
}) =>
    showSpiritualBottomSheet<void>(
      context,
      title: _sheetTitle(surah, ayah),
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AyahBox(ayah: ayah),
          const SizedBox(height: SpiritualSpace.s16),
          SpiritualPrimaryButton(
            label: SpiritualStrings.copyAyah,
            leadingIcon: Icons.copy_outlined,
            onPressed: () async {
              final messenger = ScaffoldMessenger.maybeOf(context);
              await Clipboard.setData(ClipboardData(
                text: '${ayah.text} ﴿${toArabicDigits(ayah.number)}﴾ '
                    '[${SpiritualStrings.surahWord} ${surah.nameAr}]',
              ));
              SeenHaptics.light();
              if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              messenger
                ?..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(content: Text(SpiritualStrings.copied)),
                );
            },
          ),
        ],
      ),
    );
