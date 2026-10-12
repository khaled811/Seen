import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:seen_booking/core/constants/enums.dart';
import 'package:seen_booking/core/error/failure.dart';
import 'package:seen_booking/features/dynamic_forms/domain/entities/dynamic_form_field.dart';
import 'package:seen_booking/features/dynamic_forms/domain/validators/dynamic_field_validator.dart';
import 'package:seen_booking/features/dynamic_forms/domain/validators/form_validation_messages.dart';
import 'package:seen_booking/features/services/domain/entities/service_booking_request.dart';
import 'package:seen_booking/features/services/domain/entities/service_booking_result.dart';
import 'package:seen_booking/features/services/domain/entities/service_definition.dart';
import 'package:seen_booking/features/services/domain/repositories/services_repository.dart';
import 'package:seen_booking/features/services/domain/usecases/get_available_services_usecase.dart';
import 'package:seen_booking/features/services/domain/usecases/submit_booking_usecase.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_bloc.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_event.dart';
import 'package:seen_booking/features/services/presentation/bloc/service_booking_state.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_balance.dart';
import 'package:seen_booking/features/wallet/domain/entities/wallet_transaction.dart';
import 'package:seen_booking/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:seen_booking/features/wallet/domain/usecases/get_wallet_balance_usecase.dart';

const _messages = FormValidationMessages(
  required: 'required',
  invalidEmail: 'invalidEmail',
  invalidPhone: 'invalidPhone',
  invalidNumber: 'invalidNumber',
  invalidDate: 'invalidDate',
  invalidSelection: 'invalidSelection',
  tooShort: _id,
  tooLong: _id,
  numberTooSmall: _id,
  numberTooLarge: _id,
  expiryTooSoon: _id,
  dateInFuture: _idString,
);
String _id(num n) => '$n';
String _idString(String s) => s;

const _service = ServiceDefinition(
  id: 'egypt_national_security',
  category: ServiceCategory.egyptNationalSecurity,
  name: 'Egypt National Security Approval',
  description: '',
  perPersonPriceCents: 15000, // $150.00
  availability: ServiceAvailability.available,
);

const _travelerFields = [
  DynamicFormField(
    key: 'fullName',
    type: FieldType.text,
    label: 'Full name',
    required: true,
  ),
];

const _balance = WalletBalance(
  availableCents: 100000,
  holdCents: 0,
  creditLimitCents: 500000,
  currency: WalletCurrency.usd,
);

final _bookingResult = ServiceBookingResult(
  requestId: 'req-1',
  status: RequestStatus.submitted,
  totalPriceCents: 30000,
  createdAt: DateTime(2026, 1, 1),
);

/// Hand-rolled fakes — small interfaces, not worth a mocking dependency.
class _FakeServicesRepository implements ServicesRepository {
  Either<Failure, List<ServiceDefinition>> catalogResult = const Right([_service]);
  Either<Failure, ServiceBookingResult> submitResult = Right(_bookingResult);
  ServiceBookingRequest? lastRequest;
  int submitCalls = 0;

  @override
  Future<Either<Failure, List<ServiceDefinition>>> getAvailableServices() async =>
      catalogResult;

  @override
  Future<Either<Failure, ServiceBookingResult>> submitBooking(
    ServiceBookingRequest request,
  ) async {
    submitCalls++;
    lastRequest = request;
    return submitResult;
  }
}

class _FakeWalletRepository implements WalletRepository {
  Either<Failure, WalletBalance> balanceResult = const Right(_balance);

  @override
  Future<Either<Failure, WalletBalance>> getBalance() async => balanceResult;

  @override
  Future<Either<Failure, List<WalletTransaction>>> getTransactions({
    TransactionType? type,
    DateTime? from,
    DateTime? to,
    int page = 1,
    int pageSize = 20,
  }) async =>
      throw UnimplementedError('Not used by ServiceBookingBloc');

  @override
  Future<Either<Failure, WalletTransaction>> requestTopUp({
    required int amountCents,
    required TopUpMethod method,
    required String referenceNumber,
    String? notes,
  }) async =>
      throw UnimplementedError('Not used by ServiceBookingBloc');
}

void main() {
  late _FakeServicesRepository servicesRepository;
  late _FakeWalletRepository walletRepository;
  late ServiceBookingBloc bloc;

  setUp(() {
    servicesRepository = _FakeServicesRepository();
    walletRepository = _FakeWalletRepository();
    bloc = ServiceBookingBloc(
      getAvailableServicesUseCase: GetAvailableServicesUseCase(servicesRepository),
      submitBookingUseCase: SubmitBookingUseCase(servicesRepository),
      getWalletBalanceUseCase: GetWalletBalanceUseCase(walletRepository),
      validator: const DynamicFieldValidator(_messages),
    );
  });

  tearDown(() => bloc.close());

  Future<ServiceBookingInProgress> selectService() async {
    bloc.add(const ServiceCatalogRequested());
    await bloc.stream.firstWhere((s) => s is ServiceCatalogLoaded);
    bloc.add(
      const ServiceSelected(service: _service, travelerFields: _travelerFields),
    );
    return await bloc.stream.firstWhere(
      (s) => s is ServiceBookingInProgress && !s.walletBalanceLoading,
    ) as ServiceBookingInProgress;
  }

  test('initial state is ServiceBookingInitial', () {
    expect(bloc.state, const ServiceBookingInitial());
  });

  test('ServiceCatalogRequested emits [Loading, Loaded]', () async {
    final states = <ServiceBookingState>[];
    final sub = bloc.stream.listen(states.add);
    bloc.add(const ServiceCatalogRequested());
    await bloc.stream.firstWhere((s) => s is ServiceCatalogLoaded);
    await sub.cancel();
    expect(states, [const ServiceCatalogLoading(), const ServiceCatalogLoaded([_service])]);
  });

  test('ServiceSelected starts with one traveler and loads the wallet balance', () async {
    final state = await selectService();
    expect(state.travelers, hasLength(1));
    expect(state.walletBalance, _balance);
    expect(state.activeTravelerIndex, 0);
  });

  group('traveler additions', () {
    test('TravelerAdded appends a traveler and makes it active', () async {
      await selectService();
      bloc.add(const TravelerAdded());
      final state = await bloc.stream.first as ServiceBookingInProgress;
      expect(state.travelers, hasLength(2));
      expect(state.activeTravelerIndex, 1);
    });

    test('TravelerRemoved refuses to remove the last traveler', () async {
      await selectService();
      bloc.add(const TravelerRemoved(0));
      // No new state should be emitted; the bloc's own state stays as-is.
      await Future<void>.delayed(Duration.zero);
      expect(bloc.state, isA<ServiceBookingInProgress>());
      expect((bloc.state as ServiceBookingInProgress).travelers, hasLength(1));
    });

    test('TravelerRemoved removes a traveler and its errors', () async {
      await selectService();
      bloc.add(const TravelerAdded());
      await bloc.stream.first;

      bloc.add(const TravelerRemoved(0));
      final state = await bloc.stream.first as ServiceBookingInProgress;
      expect(state.travelers, hasLength(1));
    });
  });

  group('price computation', () {
    test('totalPriceCents scales with traveler count', () async {
      final initial = await selectService();
      expect(initial.totalPriceCents, 15000); // 1 traveler

      bloc.add(const TravelerAdded());
      final withTwo = await bloc.stream.first as ServiceBookingInProgress;
      expect(withTwo.totalPriceCents, 30000); // 2 travelers

      bloc.add(const TravelerAdded());
      final withThree = await bloc.stream.first as ServiceBookingInProgress;
      expect(withThree.totalPriceCents, 45000); // 3 travelers
    });
  });

  group('validation', () {
    test('TravelerContinuePressed blocks on missing required fields', () async {
      await selectService();
      bloc.add(const TravelerContinuePressed());
      final state = await bloc.stream.first as ServiceBookingInProgress;
      expect(state.reviewReady, isFalse);
      expect(state.travelerErrors[state.travelers.first.id], {'fullName': 'required'});
    });

    test('TravelerContinuePressed sets reviewReady once fields are valid', () async {
      final initial = await selectService();
      bloc.add(
        const TravelerFieldChanged(
          travelerIndex: 0,
          fieldKey: 'fullName',
          value: 'Ahmed Hassan',
        ),
      );
      await bloc.stream.first;

      bloc.add(const TravelerContinuePressed());
      final state = await bloc.stream.firstWhere(
        (s) => s is ServiceBookingInProgress && s.reviewReady,
      ) as ServiceBookingInProgress;

      expect(state.reviewReady, isTrue);
      expect(state.travelerErrors, isEmpty);
      expect(initial.travelers, hasLength(1)); // sanity: same traveler set throughout
    });
  });

  group('submission', () {
    Future<ServiceBookingInProgress> fillValidTraveler() async {
      await selectService();
      bloc.add(
        const TravelerFieldChanged(
          travelerIndex: 0,
          fieldKey: 'fullName',
          value: 'Ahmed Hassan',
        ),
      );
      return await bloc.stream.first as ServiceBookingInProgress;
    }

    test('submits and reaches success with the built request', () async {
      await fillValidTraveler();
      bloc.add(const BookingSubmitted());

      await bloc.stream.firstWhere(
        (s) => s is ServiceBookingInProgress && s.submissionStatus == BookingSubmissionStatus.submitting,
      );
      final success = await bloc.stream.firstWhere(
        (s) => s is ServiceBookingInProgress && s.submissionStatus == BookingSubmissionStatus.success,
      ) as ServiceBookingInProgress;

      expect(success.submissionResult, _bookingResult);
      expect(servicesRepository.submitCalls, 1);
      expect(servicesRepository.lastRequest!.serviceId, _service.id);
      expect(servicesRepository.lastRequest!.travelers, hasLength(1));
    });

    test('does not call the repository when validation fails', () async {
      await selectService(); // fullName left empty
      bloc.add(const BookingSubmitted());
      await Future<void>.delayed(Duration.zero);
      expect(servicesRepository.submitCalls, 0);
    });

    test('surfaces a repository failure', () async {
      await fillValidTraveler();
      servicesRepository.submitResult = const Left(ServerFailure('rejected'));

      bloc.add(const BookingSubmitted());
      final failed = await bloc.stream.firstWhere(
        (s) => s is ServiceBookingInProgress && s.submissionStatus == BookingSubmissionStatus.failure,
      ) as ServiceBookingInProgress;

      expect(failed.submissionError, 'rejected');
    });
  });
}
