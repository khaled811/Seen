// SYS-06 (skeletons), SYS-07 (permission sheet), SYS-08 (shared components). Arabic / RTL.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/presentation/gallery/components_gallery_screen.dart';
import 'package:seen_booking/core/presentation/widgets/components.dart';
import 'package:seen_booking/core/presentation/widgets/inline_banner.dart';
import 'package:seen_booking/core/presentation/widgets/skeleton.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/features/requests/domain/entities/missing_document.dart';
import 'package:seen_booking/features/requests/domain/services/document_picker.dart';
import 'package:seen_booking/features/services/presentation/bloc/traveler_attachment_cubit.dart';
import 'package:seen_booking/features/services/presentation/widgets/seen_attachment_slot.dart';
import 'package:seen_booking/features/system_status/domain/services/app_settings_launcher.dart';
import 'package:seen_booking/features/system_status/presentation/widgets/permission_denied_sheet.dart';

Widget _app(Widget home, {bool reduceMotion = false}) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light,
      builder: (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion), child: child!),
      home: Scaffold(body: home),
    );

class _Settings implements AppSettingsLauncher {
  int opened = 0;
  @override
  Future<bool> open() async {
    opened++;
    return true;
  }
}

class _DeniedPicker implements DocumentPicker {
  _DeniedPicker(this.code);
  final String code;
  PickedDocument? file;

  @override
  Future<Either<Failure, PickedDocument?>> pick(DocumentSource source, {required List<String> allowedExtensions}) async {
    if (source == DocumentSource.file) {
      return Right(file);
    }
    return Left(ServerFailure('denied', code: code));
  }
}

void main() {
  group('skeletons (SYS-06)', () {
    testWidgets('boxes pulse under a group, and one group runs one ticker', (tester) async {
      await tester.pumpWidget(_app(const SeenSkeletonGroup(
        child: Column(children: [SeenSkeletonBox(height: 10), SeenSkeletonBox(height: 10), SeenSkeletonBox(height: 10)]),
      )));
      expect(find.byType(FadeTransition).evaluate().where((e) => e.widget is FadeTransition && (e.widget as FadeTransition).opacity.value <= 1).length, greaterThanOrEqualTo(3));
      await tester.pump(const Duration(milliseconds: 800));
      final fade = tester.widget<FadeTransition>(find.descendant(of: find.byType(SeenSkeletonBox).first, matching: find.byType(FadeTransition)));
      expect(fade.opacity.value, inInclusiveRange(0.55, 1.0));
      // Remove it: the controller must be disposed (no ticker left running).
      await tester.pumpWidget(_app(const SizedBox()));
    });

    testWidgets('with "reduce motion" they are drawn still', (tester) async {
      await tester.pumpWidget(_app(const SeenSkeletonGroup(child: SeenSkeletonBox(height: 10)), reduceMotion: true));
      expect(find.descendant(of: find.byType(SeenSkeletonBox), matching: find.byType(FadeTransition)), findsNothing);
      // Nothing is animating, so the tree settles.
      await tester.pumpAndSettle();
    });

    testWidgets('a box with no group is still, never crashes', (tester) async {
      await tester.pumpWidget(_app(const SeenSkeletonBox(width: 50, height: 10)));
      expect(find.byType(SeenSkeletonBox), findsOneWidget);
    });

    testWidgets('the cards skeleton is announced as loading and shows three cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(const SeenCardsSkeleton(label: 'جارٍ التحميل')));
      expect(find.byType(SeenCardSkeleton), findsNWidgets(3));
      expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'جارٍ التحميل'), findsOneWidget);
    });
  });

  group('components (SYS-08)', () {
    testWidgets('toast shows the message with an action that runs and dismisses it', (tester) async {
      var undone = 0;
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () => showSeenToast(context, message: 'تم الحفظ', actionLabel: 'تراجع', onAction: () => undone++),
          child: const Text('go'),
        ),
      )));
      await tester.tap(find.text('go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('تم الحفظ'), findsOneWidget);
      await tester.tap(find.text('تراجع'));
      await tester.pumpAndSettle();
      expect(undone, 1);
      expect(find.text('تم الحفظ'), findsNothing);
    });

    testWidgets('checkbox and switch toggle; disabled ones do not', (tester) async {
      var check = false;
      var on = false;
      await tester.pumpWidget(_app(StatefulBuilder(
        builder: (context, set) => Column(children: [
          SeenCheckbox(value: check, onChanged: (v) => set(() => check = v), semanticLabel: 'c'),
          SeenSwitch(value: on, onChanged: (v) => set(() => on = v), semanticLabel: 's'),
          const SeenCheckbox(value: true, onChanged: null),
          const SeenSwitch(value: false, onChanged: null),
        ]),
      )));
      await tester.tap(find.byType(SeenCheckbox).first);
      await tester.tap(find.byType(SeenSwitch).first);
      await tester.pump();
      expect(check, isTrue);
      expect(on, isTrue);
      await tester.tap(find.byType(SeenCheckbox).last);
      await tester.tap(find.byType(SeenSwitch).last);
      await tester.pump();
      expect(check, isTrue);
      expect(on, isTrue);
    });

    testWidgets('list row taps; a row without a handler has no chevron', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_app(Column(children: [
        SeenListRow(icon: Icons.info, title: 'عنوان الصف', subtitle: 'وصف قصير', onTap: () => taps++),
        const SeenListRow(icon: Icons.info, title: 'ثابت'),
      ])));
      await tester.tap(find.text('عنوان الصف'));
      expect(taps, 1);
      expect(find.byType(Icon), findsNWidgets(3)); // two tiles + one chevron
    });

    testWidgets('progress clamps; badge caps at 99+', (tester) async {
      await tester.pumpWidget(_app(const Column(children: [
        SeenProgressBar(fraction: 2, width: 100),
        SeenProgressBar(fraction: double.nan, width: 100),
        SeenCountBadge(count: 120),
        SeenCountBadge(count: 3),
      ])));
      final bars = tester.widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox)).toList();
      expect(bars[0].widthFactor, 1);
      expect(bars[1].widthFactor, 0);
      expect(find.text('99+'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('the info banner exists and the gallery renders every component', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light,
        home: const ComponentsGalleryScreen(),
      ));
      expect(find.byType(SeenInlineBanner), findsNWidgets(4));
      expect(find.text('معلومة'), findsOneWidget);
      expect(find.byType(SeenSwitch), findsNWidgets(2));
      expect(find.byType(SeenCheckbox), findsNWidgets(3));
      expect(find.byType(SeenCountBadge), findsOneWidget);
    });
  });

  group('permission refused for good (SYS-07)', () {
    Future<PermissionSheetChoice?> open(WidgetTester tester, _Settings settings, DeniedPermission p) async {
      PermissionSheetChoice? result;
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await showPermissionDeniedSheet(context, permission: p, launcher: settings),
          child: const Text('go'),
        ),
      )));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('camera: explains, opens the settings', (tester) async {
      final settings = _Settings();
      await open(tester, settings, DeniedPermission.camera);
      expect(find.text('اسمح بالوصول إلى الكاميرا'), findsOneWidget);
      expect(find.textContaining('مرفوض نهائيًا'), findsOneWidget);
      await tester.tap(find.text('فتح الإعدادات'));
      await tester.pumpAndSettle();
      expect(settings.opened, 1);
      expect(find.text('اسمح بالوصول إلى الكاميرا'), findsNothing);
    });

    testWidgets('photos variant has its own wording', (tester) async {
      await open(tester, _Settings(), DeniedPermission.photos);
      expect(find.text('اسمح بالوصول إلى الصور'), findsOneWidget);
    });

    test('the attachment cubit tells a refused camera from a broken one', () async {
      final denied = TravelerAttachmentCubit(() => _DeniedPicker(cameraDeniedCode));
      await denied.pick('t1', DocumentSource.camera);
      expect(denied.state.error, AttachmentError.cameraDenied);
      final photos = TravelerAttachmentCubit(() => _DeniedPicker(photosDeniedCode));
      await photos.pick('t1', DocumentSource.gallery);
      expect(photos.state.error, AttachmentError.photosDenied);
      final other = TravelerAttachmentCubit(() => _DeniedPicker('PICKER_UNAVAILABLE'));
      await other.pick('t1', DocumentSource.camera);
      expect(other.state.error, AttachmentError.unavailable);
      await denied.close();
      await photos.close();
      await other.close();
    });

    testWidgets('booking attachment: camera refused -> sheet -> "choose a file" carries on with the file picker', (tester) async {
      final picker = _DeniedPicker(cameraDeniedCode)..file = const PickedDocument(path: '/tmp/p.pdf', fileName: 'p.pdf', sizeBytes: 100);
      final cubit = TravelerAttachmentCubit(() => picker);
      addTearDown(() => cubit.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(BlocProvider.value(
        value: cubit,
        child: const SeenAttachmentSlot(travelerId: 't1', title: 'نسخة جواز السفر', caption: 'cap'),
      )));
      await tester.tap(find.text('نسخة جواز السفر'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('الكاميرا'));
      await tester.pumpAndSettle();
      expect(find.text('اسمح بالوصول إلى الكاميرا'), findsOneWidget);
      await tester.tap(find.text('اختيار ملف بدلًا من ذلك'));
      await tester.pumpAndSettle();
      expect(cubit.state.files['t1']?.fileName, 'p.pdf');
    });
  });
}
