import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/spiritual/data/repositories/json_quran_repository.dart';
import 'package:seen_booking/features/spiritual/di/quran_module.dart';
import 'package:seen_booking/features/spiritual/domain/entities/quran_data.dart';
import 'package:seen_booking/features/spiritual/domain/entities/reader_state.dart';

import 'fakes.dart';

/// The real bundled Quran (parsed once per test run) plus an in-memory reader
/// state, wired into a [QuranModule].
class QuranHarness {
  QuranHarness({ReaderState? initial}) : reader = InMemoryReaderState(initial) {
    module = QuranModule(
      quran: sharedQuran,
      readerState: reader,
      viewPrefs: viewPrefs,
    );
  }

  /// Shared across tests: parsing 1.7 MB per test would be slow.
  static final sharedQuran = JsonQuranRepository(useIsolate: false);

  static QuranData? _data;

  /// Call from `setUpAll` (outside the fake-async zone) so the asset is
  /// already cached when widget tests run.
  static Future<QuranData> preload() async => _data ??=
      (await sharedQuran.load()).getOrElse((f) => throw StateError(f.message));

  /// The loaded dataset, for building expectations from real data.
  static QuranData get data => _data!;

  final InMemoryReaderState reader;
  final viewPrefs = InMemoryViewPrefs();
  late final QuranModule module;
}

/// Loads the bundled fonts and sizes the test view like a phone.
Future<void> loadHub(WidgetTester tester, {Size size = const Size(390, 844)}) async {
  await loadAppFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> pumpHub(
  WidgetTester tester,
  Widget home, {
  double textScale = 1,
  Size size = const Size(390, 844),
}) async {
  await loadAppFonts();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

/// Disposes the tree so timers and subscriptions are released.
Future<void> disposeTree(WidgetTester tester) =>
    tester.pumpWidget(const SizedBox.shrink());
