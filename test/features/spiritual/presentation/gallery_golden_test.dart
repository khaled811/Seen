// Golden coverage for every M1 component, rendered through the debug gallery
// (which shows each component in its states) at text scale 1.0 and 2.0.
//
// Generate/refresh baselines with:
//   flutter test test/features/spiritual/presentation/gallery_golden_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/spiritual/presentation/gallery/spiritual_gallery_screen.dart';

void main() {
  for (final (scale, height) in [(1.0, 2800.0), (2.0, 5600.0)]) {
    testWidgets('hub component gallery @ text scale $scale', (tester) async {
      await loadAppFonts();
      tester.view.physicalSize = Size(390, height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
            ),
            child: child!,
          ),
          home: const SpiritualGalleryScreen(),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/spiritual_gallery_x${scale.toInt()}.png'),
      );
    });
  }
}
