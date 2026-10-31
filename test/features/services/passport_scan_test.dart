// Reading a passport from a photo (design/gaps PASS): the data source (suggestions kept, the photo
// deleted), the cubit (stages, rows, cancel), the scan screen in each state, the SuggestionRow and
// the traveler form's entry. Arabic / RTL, 390 wide.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/core/network/file_upload_client.dart';
import 'package:seen_booking/core/presentation/widgets/suggestion_row.dart';
import 'package:seen_booking/core/theme/app_theme.dart';
import 'package:seen_booking/core/utils/latin_digits.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:seen_booking/core/config/feature_flags.dart';
import 'package:seen_booking/features/requests/domain/usecases/get_request_detail_usecase.dart';
import 'package:seen_booking/features/services/domain/entities/service_definition.dart';
import 'package:seen_booking/features/services/domain/repositories/services_repository.dart';
import 'package:seen_booking/features/services/domain/usecases/booking_flow_usecases.dart';
import 'package:seen_booking/features/services/domain/usecases/get_available_services_usecase.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_bloc.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_event.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_state.dart';
import 'package:seen_booking/features/services/presentation/screens/service_selection_screen.dart';
import 'package:seen_booking/features/services/presentation/widgets/passport_scan_entry.dart';
import 'package:seen_booking/features/services/data/datasources/passport_reader_remote_data_source.dart';
import 'package:seen_booking/features/services/domain/entities/passport_reading.dart';
import 'package:seen_booking/features/services/domain/services/passport_photo_picker.dart';
import 'package:seen_booking/features/services/presentation/bloc/passport_scan_cubit.dart';
import 'package:seen_booking/features/services/presentation/screens/passport_scan_screen.dart';

import '../../support/booking_fakes.dart';
import '../../support/passport_fakes.dart';

final _l10n = lookupAppLocalizations(const Locale('ar'));

const _fields = {'passportNumber': 'رقم الجواز', 'fullName': 'الاسم الكامل', 'nationality': 'الجنسية', 'birthDate': 'تاريخ الميلاد'};

PassportScanCubit _cubit(FakePassportReader reader, FakePassportPicker picker) =>
    PassportScanCubit(reader: reader, picker: picker, fieldKeys: _fields.keys.toList());

class _Client implements FileUploadClient {
  _Client(this.result);

  final Either<Failure, Map<String, dynamic>> result;

  @override
  Future<Either<Failure, Map<String, dynamic>>> readPassport({required String path, required String fileName}) async => result;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

Future<void> _open(WidgetTester tester, FakePassportReader reader, FakePassportPicker picker, {void Function(Map<String, String>?)? onResult}) async {
  await tester.binding.setSurfaceSize(const Size(390, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_app(Builder(
    builder: (context) => TextButton(
      onPressed: () async {
        // Awaited first: a null-aware call would not even evaluate its argument without a callback.
        final result = await Navigator.of(context).push<Map<String, String>>(
          MaterialPageRoute(builder: (_) => PassportScanScreen(fields: _fields, createCubit: (_) => _cubit(reader, picker))),
        );
        onResult?.call(result);
      },
      child: const Text('open'),
    ),
  )));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}


class _Services implements ServicesRepository {
  @override
  Future<Either<Failure, List<ServiceDefinition>>> getAvailableServices() async => const Right([bookingTestService]);
}

ServiceBookingBloc _bookingBloc() {
  final flow = FakeBookingFlowRepository();
  return ServiceBookingBloc(
    getAvailableServicesUseCase: GetAvailableServicesUseCase(_Services()),
    createDraftUseCase: CreateDraftRequestUseCase(flow),
    addTravelersUseCase: AddTravelersUseCase(flow),
    uploadDocumentUseCase: UploadBookingDocumentUseCase(flow),
    reviewDraftUseCase: ReviewDraftUseCase(flow),
    submitDraftUseCase: SubmitDraftRequestUseCase(flow),
    getRequestDetailUseCase: GetRequestDetailUseCase(FakeBookingRequestsRepository()),
    validator: ServiceSelectionScreen.buildValidator(_l10n),
    referenceRetryDelay: Duration.zero,
  )..add(const ServiceSelected(service: bookingTestService));
}

void main() {
  group('data source', () {
    late Directory dir;
    late String path;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('passport_test');
      path = '${dir.path}${Platform.pathSeparator}p.jpg';
      File(path).writeAsBytesSync([1, 2, 3]);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('keeps the suggestions with their verdict, drops empty values, and deletes the photo', () async {
      final source = PassportReaderRemoteDataSource(
        client: _Client(const Right({
          'allChecksPass': false,
          'suggestions': [
            {'key': 'passportNumber', 'value': ' N0849482 ', 'checked': true},
            {'key': 'nationality', 'value': 'YEM', 'checked': false},
            {'key': 'fullName', 'value': '  ', 'checked': true},
            {'key': 'birthDate', 'value': null, 'checked': true},
          ],
        })),
      );
      final reading = ((await source.read(path: path, fileName: 'p.jpg')) as Right).value as PassportReading;
      expect(reading.allChecksPass, isFalse);
      expect(reading.suggestions, const [
        PassportSuggestion(key: 'passportNumber', value: 'N0849482', checked: true),
        PassportSuggestion(key: 'nationality', value: 'YEM', checked: false),
      ]);
      expect(File(path).existsSync(), isFalse, reason: 'no copy of a passport image stays on the device');
    });

    test('a failed reading deletes the photo too', () async {
      final source = PassportReaderRemoteDataSource(client: _Client(const Left(ServerFailure('x', code: 'ocr_unavailable'))));
      expect((await source.read(path: path, fileName: 'p.jpg')).isLeft(), isTrue);
      expect(File(path).existsSync(), isFalse);
    });

    test('server codes become issues', () {
      PassportIssueKind kind(Failure f) => PassportIssue.from(f).kind;
      expect(kind(const ServerFailure('x', code: 'passport_not_image')), PassportIssueKind.notImage);
      expect(kind(const ServerFailure('x', code: 'ocr_unavailable')), PassportIssueKind.unavailable);
      expect(kind(const ServerFailure('x', code: 'too_many_attempts')), PassportIssueKind.rateLimited);
      expect(kind(const NetworkFailure('x')), PassportIssueKind.offline);
      expect(kind(const ForbiddenFailure('x')), PassportIssueKind.forbidden);
    });
  });

  group('cubit', () {
    test('a good reading shows only the form\'s fields, in the form\'s order, low confidence unselected', () async {
      final cubit = _cubit(FakePassportReader(), FakePassportPicker());
      await cubit.capture(PassportPhotoSource.camera);
      expect(cubit.state.stage, PassportStage.review);
      expect(cubit.state.rows.map((r) => r.suggestion.key), ['passportNumber', 'fullName', 'nationality']);
      expect(cubit.state.rows.map((r) => r.selected), [true, true, false]);
      expect(cubit.state.selectedCount, 2);
      expect(cubit.chosen, {'passportNumber': 'N0849482', 'fullName': 'AMAL SALEH'});
      cubit.toggle('nationality');
      cubit.toggle('fullName');
      expect(cubit.chosen, {'passportNumber': 'N0849482', 'nationality': 'YEM'});
      await cubit.close();
    });

    test('nothing the form asks for is an unreadable passport, not an empty review', () async {
      final reader = FakePassportReader()..result = const Right(PassportReading(suggestions: [PassportSuggestion(key: 'other', value: 'x', checked: true)], allChecksPass: true));
      final cubit = _cubit(reader, FakePassportPicker());
      await cubit.capture(PassportPhotoSource.gallery);
      expect((cubit.state.stage, cubit.state.issue?.kind), (PassportStage.failed, PassportIssueKind.unreadable));
      await cubit.close();
    });

    test('a file that is not JPG or PNG is refused before it is sent', () async {
      final reader = FakePassportReader();
      final picker = FakePassportPicker()..result = const Right(PassportPhoto(path: '/tmp/x.gif', fileName: 'x.gif'));
      final cubit = _cubit(reader, picker);
      await cubit.capture(PassportPhotoSource.gallery);
      expect((cubit.state.stage, cubit.state.notImage), (PassportStage.capture, true));
      expect(reader.reads, isEmpty);
      await cubit.close();
    });

    test('the server saying it is not an image goes back to capture with the note; unavailable is its own stage', () async {
      final reader = FakePassportReader()..result = const Left(ServerFailure('x', code: 'passport_not_image'));
      final cubit = _cubit(reader, FakePassportPicker());
      await cubit.capture(PassportPhotoSource.camera);
      expect((cubit.state.stage, cubit.state.notImage), (PassportStage.capture, true));
      reader.result = const Left(ServerFailure('x', code: 'ocr_unavailable'));
      await cubit.capture(PassportPhotoSource.camera);
      expect(cubit.state.stage, PassportStage.unavailable);
      await cubit.close();
    });

    test('backing out of the picker changes nothing; a refused camera is reported', () async {
      final picker = FakePassportPicker()..result = const Right(null);
      final cubit = _cubit(FakePassportReader(), picker);
      await cubit.capture(PassportPhotoSource.camera);
      expect(cubit.state, const PassportScanState());
      picker.result = const Left(ServerFailure('x CAMERA_PERMISSION_DENIED x', code: PassportPhotoPicker.cameraDeniedCode));
      await cubit.capture(PassportPhotoSource.camera);
      expect(cubit.state.pickerDenied, 'camera');
      await cubit.close();
    });

    test('cancelling while reading drops the late answer', () async {
      final reader = FakePassportReader()..hold = Completer<void>();
      final cubit = _cubit(reader, FakePassportPicker());
      final reading = cubit.capture(PassportPhotoSource.camera);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.stage, PassportStage.reading);
      cubit.cancel();
      reader.hold!.complete();
      await reading;
      expect(cubit.state.stage, PassportStage.capture);
      expect(cubit.state.rows, isEmpty);
      await cubit.close();
    });
  });

  group('SuggestionRow', () {
    testWidgets('shows the field and the value LTR; a doubtful row has its chip and is unchecked; an applied row has its own', (tester) async {
      var changed = false;
      await tester.pumpWidget(_app(Scaffold(
        body: Column(children: [
          SuggestionRow(
            field: 'رقم الجواز',
            value: 'N0849482',
            checked: false,
            confidence: SuggestionConfidence.low,
            lowConfidenceLabel: 'ثقة منخفضة',
            appliedLabel: 'طُبّق',
            onChanged: (_) => changed = true,
          ),
          const SuggestionRow(
            field: 'الجنسية',
            value: 'YEM',
            checked: true,
            applied: true,
            lowConfidenceLabel: 'ثقة منخفضة',
            appliedLabel: 'طُبّق',
            onChanged: null,
          ),
        ]),
      )));
      expect(find.text('ثقة منخفضة'), findsOneWidget);
      expect(find.text('طُبّق'), findsOneWidget);
      await tester.tap(find.text('N0849482'));
      expect(changed, isTrue);
    });
  });

  group('the scan screen', () {
    testWidgets('capture shows the guide, the tips and both ways to take the photo', (tester) async {
      await _open(tester, FakePassportReader(), FakePassportPicker());
      expect(find.text(_l10n.passGuideTitle), findsOneWidget);
      expect(find.text(_l10n.passTipLight), findsOneWidget);
      expect(find.text(_l10n.passCapture), findsOneWidget);
      expect(find.text(_l10n.passFromPhotos), findsOneWidget);
    });

    testWidgets('capture -> review: rows with their values; apply returns only the selected ones', (tester) async {
      Map<String, String>? result;
      final reader = FakePassportReader();
      await _open(tester, reader, FakePassportPicker(), onResult: (r) => result = r);
      await tester.tap(find.text(_l10n.passCapture));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.passReviewTitle), findsOneWidget);
      expect(find.text(toArabicIndicDigits(_l10n.passReadCount(3))), findsOneWidget);
      expect(find.text('N0849482'), findsOneWidget);
      expect(find.text(_l10n.passLowConfidence), findsOneWidget);
      expect(find.text(_l10n.passLowNote), findsOneWidget);
      expect(find.text(toArabicIndicDigits(_l10n.passApply(2))), findsOneWidget);

      await tester.tap(find.text(toArabicIndicDigits(_l10n.passApply(2))));
      await tester.pumpAndSettle();
      expect(result, {'passportNumber': 'N0849482', 'fullName': 'AMAL SALEH'});
    });

    testWidgets('apply is disabled when every row is unchecked; "Retake" goes back to capture', (tester) async {
      Map<String, String>? result;
      await _open(tester, FakePassportReader(), FakePassportPicker(), onResult: (r) => result = r);
      await tester.tap(find.text(_l10n.passCapture));
      await tester.pumpAndSettle();
      await tester.tap(find.text('N0849482'));
      await tester.tap(find.text('AMAL SALEH'));
      await tester.pump();
      await tester.tap(find.text(toArabicIndicDigits(_l10n.passApply(0))));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.text(_l10n.passReviewTitle), findsOneWidget);

      await tester.tap(find.text(_l10n.passRetake));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.passGuideTitle), findsOneWidget);
    });

    testWidgets('reading shows the loader and Cancel returns to capture', (tester) async {
      final reader = FakePassportReader()..hold = Completer<void>();
      await _open(tester, reader, FakePassportPicker());
      await tester.tap(find.text(_l10n.passCapture));
      await tester.pump();
      await tester.pump();
      expect(find.text(_l10n.passReading), findsOneWidget);
      await tester.tap(find.text(_l10n.commonCancel));
      await tester.pump();
      expect(find.text(_l10n.passGuideTitle), findsOneWidget);
      reader.hold!.complete();
      await tester.pumpAndSettle();
      expect(find.text(_l10n.passGuideTitle), findsOneWidget, reason: 'the late answer is dropped');
    });

    testWidgets('a failed reading says so, with Retake and Enter manually (which leaves with null)', (tester) async {
      var left = false;
      final reader = FakePassportReader()..result = const Left(ServerFailure('x', code: 'weird'));
      await _open(tester, reader, FakePassportPicker(), onResult: (_) => left = true);
      await tester.tap(find.text(_l10n.passCapture));
      await tester.pumpAndSettle();
      expect(find.textContaining(_l10n.passFailedTitle), findsOneWidget);
      expect(find.text(_l10n.passRetake), findsOneWidget);
      await tester.tap(find.text(_l10n.passManual));
      await tester.pumpAndSettle();
      expect(left, isTrue);
    });

    testWidgets('a service that is off explains it and offers to carry on by hand', (tester) async {
      var left = false;
      final reader = FakePassportReader()..result = const Left(ServerFailure('x', code: 'ocr_unavailable'));
      await _open(tester, reader, FakePassportPicker(), onResult: (_) => left = true);
      await tester.tap(find.text(_l10n.passCapture));
      await tester.pumpAndSettle();
      expect(find.text(_l10n.passUnavailableTitle), findsOneWidget);
      await tester.tap(find.text(_l10n.passContinueManual));
      await tester.pumpAndSettle();
      expect(left, isTrue);
    });

    testWidgets('a picked file that is not an image shows the note above the capture area', (tester) async {
      final picker = FakePassportPicker()..result = const Right(PassportPhoto(path: '/tmp/x.pdf', fileName: 'x.pdf'));
      final reader = FakePassportReader();
      await _open(tester, reader, picker);
      await tester.tap(find.text(_l10n.passFromPhotos));
      await tester.pumpAndSettle();
      expect(picker.sources, [PassportPhotoSource.gallery]);
      expect(find.text(_l10n.passNotImage), findsOneWidget);
      expect(reader.reads, isEmpty);
    });
  });

  group('the traveler form entry', () {
    Future<ServiceBookingBloc> show(WidgetTester tester, Future<Map<String, String>?> Function(BuildContext, Map<String, String>) openScan) async {
      final bloc = _bookingBloc();
      addTearDown(() => bloc.close().ignore());
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_app(Scaffold(
        body: BlocProvider.value(
          value: bloc,
          child: BlocBuilder<ServiceBookingBloc, ServiceBookingState>(
            builder: (context, state) =>
                state is ServiceBookingInProgress ? PassportScanEntry(state: state, openScan: openScan) : const SizedBox.shrink(),
          ),
        ),
      )));
      await tester.pump();
      await tester.pump();
      return bloc;
    }

    testWidgets('a scan button and the manual-entry note; applying fills the fields and says what is left', (tester) async {
      Map<String, String>? asked;
      final bloc = await show(tester, (context, fields) async {
        asked = fields;
        return {'fullName': 'AMAL SALEH', 'notAField': 'x'};
      });
      expect(find.text(_l10n.passScanButton), findsOneWidget);
      expect(find.text(_l10n.passManualHint), findsOneWidget);

      await tester.tap(find.text(_l10n.passScanButton));
      await tester.pump();
      await tester.pump();
      expect(asked, {'fullName': 'Full name', 'birthDate': 'Birth date', 'status': 'Status', 'spouse': 'Spouse'});
      final traveler = (bloc.state as ServiceBookingInProgress).activeTraveler;
      expect(traveler.fieldValues['fullName'], 'AMAL SALEH');
      expect(traveler.fieldValues.containsKey('notAField'), isFalse, reason: 'a key the service does not ask for is ignored');
      expect(find.text(_l10n.passManualHint), findsNothing);
      expect(find.textContaining('Birth date'), findsOneWidget, reason: 'the note names what is still to complete');
    });

    testWidgets('backing out of the scan changes nothing', (tester) async {
      final bloc = await show(tester, (context, fields) async => null);
      await tester.tap(find.text(_l10n.passScanButton));
      await tester.pump();
      await tester.pump();
      expect((bloc.state as ServiceBookingInProgress).activeTraveler.fieldValues, isEmpty);
      expect(find.text(_l10n.passManualHint), findsOneWidget);
    });

    test('the feature flag is on by default (the button can be hidden by turning it off)', () {
      expect(kEnablePassportScan, isTrue);
    });
  });
}
