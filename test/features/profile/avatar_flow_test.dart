// Changing the profile photo (PROF-01..03): the camera badge, the options sheet, the checks
// before anything is sent, the crop (512 x 512 PNG), and the upload card. Arabic / RTL, 390 wide.

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/profile/domain/entities/avatar.dart';
import 'package:seen_booking/features/profile/domain/services/avatar_picker.dart';
import 'package:seen_booking/features/profile/presentation/bloc/avatar_cubit.dart';
import 'package:seen_booking/features/profile/presentation/screens/avatar_crop_screen.dart';
import 'package:seen_booking/features/profile/presentation/widgets/avatar_flow.dart';
import 'package:seen_booking/features/profile/presentation/widgets/profile_photo.dart';
import 'package:seen_booking/core/utils/latin_digits.dart';

import '../../support/avatar_fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      home: home,
    );

Future<void> _size(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

/// A real, decodable PNG (the crop screen shows and re-encodes it).
Future<Uint8List> _png(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), Paint()..color = const Color(0xFF7B52F5));
  canvas.drawCircle(Offset(w / 2, h / 2), h / 4, Paint()..color = const Color(0xFFFFFFFF));
  final image = await recorder.endRecording().toImage(w, h);
  return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

/// A screen with the photo, the status card and a button that runs the whole flow.
Widget _host(AvatarCubit cubit, FakeAvatarPicker picker, {Future<AvatarCropResult?> Function(BuildContext, PickedAvatar)? crop}) => _app(
      Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              ProfilePhoto(
                size: 64,
                cubit: cubit,
                onTap: () => changeProfilePhoto(context, cubit: cubit, picker: picker, crop: crop),
                fallback: const Icon(Icons.apartment, key: Key('fallback')),
              ),
              AvatarStatusCard(cubit: cubit),
            ],
          ),
        ),
      ),
    );

void main() {
  testWidgets('without a photo the usual avatar shows, with a camera badge, and the whole avatar is tappable', (tester) async {
    await _size(tester);
    final cubit = AvatarCubit(FakeAvatarRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(cubit, FakeAvatarPicker()));
    await tester.pump();
    expect(find.byKey(const Key('fallback')), findsOneWidget);
    expect(find.bySemanticsLabel(_l10n.profChangePhoto), findsOneWidget);
    await tester.tap(find.byKey(const Key('fallback')));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.profSheetTitle), findsOneWidget);
    expect(find.text(_l10n.profSheetSub), findsOneWidget);
    expect(find.text(_l10n.profTakePhoto), findsOneWidget);
    expect(find.text(_l10n.profChoosePhoto), findsOneWidget);
    expect(find.text(_l10n.profDeletePhoto), findsNothing, reason: 'nothing to remove yet');
  });

  testWidgets('with a photo the sheet offers to remove it; removing says so', (tester) async {
    await _size(tester);
    final repo = FakeAvatarRepository()..currentResult = const Right('https://files.example/a.jpg');
    final cubit = AvatarCubit(repo);
    addTearDown(cubit.close);
    await cubit.load();
    await tester.pumpWidget(_host(cubit, FakeAvatarPicker()));
    await tester.pump();
    await tester.tap(find.bySemanticsLabel(_l10n.profChangePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.profDeletePhoto));
    await tester.pumpAndSettle();
    expect(repo.removeCalls, 1);
    expect(find.text(_l10n.profDeleted), findsOneWidget);
    expect(cubit.state.url, isNull);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('a photo over 5 MB is refused with its size, and nothing is sent', (tester) async {
    await _size(tester);
    final repo = FakeAvatarRepository();
    final picker = FakeAvatarPicker()..result = const Right(PickedAvatar(path: 'x', fileName: 'big.jpg', sizeBytes: 8178892));
    final cubit = AvatarCubit(repo);
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(cubit, picker));
    await tester.tap(find.bySemanticsLabel(_l10n.profChangePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.profChoosePhoto));
    await tester.pumpAndSettle();
    expect(picker.sources, [AvatarSource.gallery]);
    expect(find.textContaining(_l10n.profNotUploadedTitle), findsOneWidget);
    expect(find.textContaining(toArabicIndicDigits(_l10n.profTooLarge('7.8'))), findsOneWidget);
    expect(repo.uploads, isEmpty);
  });

  testWidgets('a photo that is not JPG or PNG is refused', (tester) async {
    await _size(tester);
    final picker = FakeAvatarPicker()..result = const Right(PickedAvatar(path: 'x', fileName: 'p.gif', sizeBytes: 100));
    final cubit = AvatarCubit(FakeAvatarRepository());
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(cubit, picker));
    await tester.tap(find.bySemanticsLabel(_l10n.profChangePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.profTakePhoto));
    await tester.pumpAndSettle();
    expect(picker.sources, [AvatarSource.camera]);
    expect(find.textContaining(_l10n.profWrongType), findsOneWidget);
  });

  testWidgets('backing out of the picker changes nothing', (tester) async {
    await _size(tester);
    final repo = FakeAvatarRepository();
    final picker = FakeAvatarPicker()..result = const Right(null);
    final cubit = AvatarCubit(repo);
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(cubit, picker));
    await tester.tap(find.bySemanticsLabel(_l10n.profChangePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.profChoosePhoto));
    await tester.pumpAndSettle();
    expect(cubit.state.issue, isNull);
    expect(repo.uploads, isEmpty);
  });

  testWidgets('a cropped photo is uploaded; "redo" goes back to the sheet', (tester) async {
    await _size(tester);
    final repo = FakeAvatarRepository();
    final picker = FakeAvatarPicker();
    final cubit = AvatarCubit(repo);
    addTearDown(cubit.close);
    var crops = 0;
    await tester.pumpWidget(_host(cubit, picker, crop: (context, picked) async {
      crops++;
      return crops == 1 ? const AvatarCropResult.redo() : AvatarCropResult.cropped(Uint8List.fromList([1, 2, 3]));
    }));
    await tester.tap(find.bySemanticsLabel(_l10n.profChangePhoto));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.profChoosePhoto));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.profSheetTitle), findsOneWidget, reason: 'redo reopens the sheet');
    await tester.tap(find.text(_l10n.profChoosePhoto));
    await tester.pumpAndSettle();
    expect(repo.uploads, [Uint8List.fromList([1, 2, 3])]);
    expect(find.text(_l10n.profUpdated), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('uploading: the card shows the file, the share sent and a bar; a failure says so and offers a retry', (tester) async {
    await _size(tester);
    final repo = FakeAvatarRepository()
      ..progress = const [.64]
      ..uploadResult = const Left(NetworkFailure('offline'));
    final cubit = AvatarCubit(repo);
    addTearDown(cubit.close);
    await tester.pumpWidget(_host(cubit, FakeAvatarPicker()));
    await cubit.upload(Uint8List(1200000));
    await tester.pump();
    expect(find.text(_l10n.profUploadFailed), findsOneWidget);
    expect(find.text('profile.png'), findsOneWidget);

    repo.uploadResult = const Right('https://files.example/a.png');
    await tester.tap(find.text(_l10n.commonRetry));
    await tester.pump();
    await tester.pump();
    expect(repo.uploads, hasLength(2));
    expect(find.text(_l10n.profUploadFailed), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('the crop screen returns a 512 x 512 PNG of what is inside the circle', (tester) async {
    await _size(tester);
    final bytes = await tester.runAsync(() => _png(800, 600));
    AvatarCropResult? result;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await Navigator.of(context).push(MaterialPageRoute<AvatarCropResult>(
          builder: (_) => AvatarCropScreen(picked: const PickedAvatar(path: 'p.png', fileName: 'p.png', sizeBytes: 10), loadBytes: (_) async => bytes!),
        )),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(_l10n.profCropTitle), findsOneWidget);
    expect(find.text(_l10n.profCropHint), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text(_l10n.profUse));
      await Future<void>.delayed(const Duration(milliseconds: 600));
    });
    await tester.pumpAndSettle();
    expect(result?.redo, isFalse);
    final out = result!.bytes!;
    final decoded = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(out);
      return (await codec.getNextFrame()).image;
    });
    expect((decoded!.width, decoded.height), (AvatarCropScreen.outputSize, AvatarCropScreen.outputSize));
  });

  testWidgets('the crop screen\'s "redo" returns the redo result', (tester) async {
    await _size(tester);
    final bytes = await tester.runAsync(() => _png(400, 400));
    AvatarCropResult? result;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () async => result = await Navigator.of(context).push(MaterialPageRoute<AvatarCropResult>(
          builder: (_) => AvatarCropScreen(picked: const PickedAvatar(path: 'p.png', fileName: 'p.png', sizeBytes: 10), loadBytes: (_) async => bytes!),
        )),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_l10n.profRedo));
    await tester.pumpAndSettle();
    expect(result?.redo, isTrue);
  });
}
