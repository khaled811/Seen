import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/datasources/agency_registration_remote_data_source.dart';
import '../../features/auth/data/datasources/agency_registration_remote_data_source_debug_fallback.dart';
import '../../features/auth/data/repositories/agency_registration_repository_impl.dart';
import '../../features/auth/domain/entities/agency_registration.dart';
import '../../features/auth/domain/repositories/agency_registration_repository.dart';
import '../../features/auth/domain/usecases/agency_registration_usecases.dart';
import '../../features/auth/presentation/bloc/agency_registration_bloc.dart';
import '../services/pending_uploads.dart';
import '../../features/requests/data/datasources/missing_document_remote_data_source.dart';
import '../../features/support/data/repositories/ticket_actions_repository_impl.dart';
import '../../features/support/domain/usecases/ticket_actions_usecases.dart';
import '../../features/support/presentation/bloc/ticket_actions_cubit.dart';
import '../../features/wallet/data/repositories/top_up_cancellation_repository_impl.dart';
import '../../features/wallet/data/repositories/statement_repository_impl.dart';
import '../../features/wallet/domain/usecases/export_statement_usecase.dart';
import '../../features/wallet/presentation/bloc/statement_export_cubit.dart';
import '../../features/wallet/presentation/bloc/top_up_history_cubit.dart';
import '../../features/wallet/domain/usecases/cancel_top_up_usecase.dart';
import '../../features/wallet/presentation/bloc/top_up_cancel_cubit.dart';
import '../../features/requests/data/datasources/secure_recent_searches_store.dart';
import '../../features/requests/domain/repositories/recent_searches_store.dart';
import '../../features/requests/presentation/bloc/recent_searches_cubit.dart';
import '../../features/requests/data/datasources/missing_document_remote_data_source_debug_fallback.dart';
import '../../features/requests/data/repositories/missing_document_repository_impl.dart';
import '../../features/requests/data/services/plugin_document_picker.dart';
import '../../features/requests/domain/repositories/missing_document_repository.dart';
import '../../features/requests/domain/services/document_picker.dart';
import '../../features/requests/domain/usecases/missing_document_usecases.dart';
import '../../features/requests/domain/usecases/remind_approver_usecase.dart';
import '../../features/requests/presentation/bloc/approver_reminder_cubit.dart';
import '../../features/requests/presentation/bloc/missing_document_bloc.dart';
import '../../features/requests/data/datasources/document_file_remote_data_source.dart';
import '../../features/requests/data/datasources/document_file_remote_data_source_debug_fallback.dart';
import '../../features/requests/data/repositories/document_file_repository_impl.dart';
import '../../features/requests/data/services/plugin_document_exporter.dart';
import '../../features/requests/domain/repositories/document_file_repository.dart';
import '../../features/requests/domain/services/document_exporter.dart';
import '../../features/requests/domain/services/pdf_page_renderer.dart';
import '../../features/requests/domain/usecases/request_document_usecases.dart';
import '../../features/requests/presentation/bloc/document_viewer_bloc.dart';
import '../../features/agents/domain/usecases/sub_agent_management_usecases.dart';
import '../../features/agents/presentation/bloc/agent_profile_bloc.dart';
import '../../features/agents/presentation/bloc/sub_agent_management_bloc.dart';
import '../network/connectivity_monitor.dart';
import '../network/data_freshness.dart';
import '../presentation/connectivity/connectivity_cubit.dart';
import '../../features/services/data/datasources/booking_draft_local_data_source.dart';
import '../../features/services/data/repositories/booking_draft_repository_impl.dart';
import '../../features/services/domain/repositories/booking_draft_repository.dart';
import '../../features/services/domain/usecases/booking_draft_usecases.dart';
import '../../features/services/presentation/bloc/drafts_bloc.dart';
import '../../features/auth/data/datasources/password_recovery_remote_data_source.dart';
import '../../features/auth/data/datasources/password_recovery_remote_data_source_debug_fallback.dart';
import '../../features/auth/data/repositories/password_recovery_repository_impl.dart';
import '../../features/auth/domain/repositories/password_recovery_repository.dart';
import '../../features/auth/domain/usecases/password_recovery_usecases.dart';
import '../../features/auth/presentation/bloc/password_recovery_bloc.dart';
import '../../features/auth/data/datasources/auth_local_data_source.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_persisted_session_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/resend_otp_usecase.dart';
import '../../features/auth/domain/usecases/verify_otp_usecase.dart';
import '../../features/agents/data/datasources/agents_remote_data_source.dart';
import '../../features/agents/data/datasources/agents_remote_data_source_debug_fallback.dart';
import '../../features/agents/data/repositories/agents_repository_impl.dart';
import '../../features/agents/domain/repositories/agents_repository.dart';
import '../../features/agents/domain/usecases/approve_sub_agent_request_usecase.dart';
import '../../features/agents/domain/usecases/fund_sub_agent_wallet_usecase.dart';
import '../../features/agents/domain/usecases/get_pending_approval_requests_usecase.dart';
import '../../features/agents/domain/usecases/get_sub_agents_usecase.dart';
import '../../features/agents/domain/usecases/reject_sub_agent_request_usecase.dart';
import '../../features/agents/presentation/bloc/agents_bloc.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/auth/presentation/bloc/auth_event.dart';
import '../../features/dynamic_forms/domain/validators/dynamic_field_validator.dart';
import '../../features/requests/data/datasources/requests_remote_data_source.dart';
import '../../features/requests/data/datasources/requests_remote_data_source_debug_fallback.dart';
import '../../features/requests/data/repositories/requests_repository_impl.dart';
import '../../features/requests/domain/repositories/requests_repository.dart';
import '../../features/requests/domain/usecases/cancel_request_usecase.dart';
import '../../features/requests/domain/usecases/get_request_detail_usecase.dart';
import '../../features/requests/domain/usecases/get_requests_usecase.dart';
import '../../features/requests/presentation/bloc/requests_bloc.dart';
import '../../features/services/data/datasources/services_remote_data_source.dart';
import '../../features/services/data/datasources/services_remote_data_source_debug_fallback.dart';
import '../../features/services/data/repositories/services_repository_impl.dart';
import '../../features/services/domain/repositories/services_repository.dart';
import '../../features/services/domain/usecases/get_available_services_usecase.dart';
import '../../features/services/domain/usecases/submit_booking_usecase.dart';
import '../../features/services/presentation/bloc/service_booking_bloc.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/profile/data/datasources/profile_remote_data_source_debug_fallback.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/usecases/profile_usecases.dart';
import '../../features/profile/presentation/bloc/profile_cubits.dart';
import '../../features/auth/data/datasources/account_security_remote_data_source.dart';
import '../../features/auth/domain/repositories/account_security_repository.dart';
import '../../features/auth/presentation/bloc/account_security_cubits.dart';
import '../../features/legal/data/datasources/legal_data_sources.dart';
import '../../features/services/data/datasources/hospital_data_source.dart';
import '../../features/services/domain/repositories/hospital_repository.dart';
import '../../features/services/presentation/bloc/hospital_picker_cubit.dart';
import '../../features/profile/data/datasources/branch_data_source.dart';
import '../../features/profile/domain/repositories/branch_repository.dart';
import '../../features/profile/presentation/bloc/branches_cubit.dart';
import '../../features/services/data/datasources/service_interest_data_source.dart';
import '../../features/services/domain/repositories/service_interest_repository.dart';
import '../../features/services/presentation/bloc/service_interest_cubit.dart';
import '../../features/support/data/datasources/notification_preferences_data_source.dart';
import '../../features/support/domain/repositories/notification_preferences_repository.dart';
import '../../features/support/presentation/bloc/notification_preferences_cubit.dart';
import '../../features/legal/data/repositories/legal_repository_impl.dart';
import '../../features/legal/domain/entities/legal_document.dart';
import '../../features/legal/presentation/bloc/legal_cubit.dart';
import '../../features/system_status/data/datasources/system_status_remote_data_source.dart';
import '../../features/system_status/data/datasources/system_status_remote_data_source_debug_fallback.dart';
import '../../features/system_status/data/repositories/system_status_repository_impl.dart';
import '../../features/system_status/data/services/plugin_push_permission_service.dart';
import '../../features/system_status/data/services/url_app_settings_launcher.dart';
import '../../features/system_status/domain/services/app_settings_launcher.dart';
import '../../features/system_status/data/services/url_store_launcher.dart';
import '../../features/system_status/domain/services/push_permission_service.dart';
import '../../features/system_status/presentation/bloc/push_permission_cubit.dart';
import '../../features/system_status/domain/services/store_launcher.dart';
import '../../features/system_status/domain/usecases/system_status_usecases.dart';
import '../../features/system_status/presentation/bloc/access_request_cubit.dart';
import '../../features/system_status/presentation/bloc/app_status_cubit.dart';
import '../../features/support/data/datasources/support_remote_data_source.dart';
import '../../features/support/data/datasources/support_remote_data_source_debug_fallback.dart';
import '../../features/support/data/repositories/support_repository_impl.dart';
import '../../features/support/domain/repositories/support_repository.dart';
import '../../features/support/domain/usecases/create_ticket_usecase.dart';
import '../../features/support/domain/usecases/get_notifications_usecase.dart';
import '../../features/support/domain/usecases/get_tickets_usecase.dart';
import '../../features/support/domain/usecases/mark_all_notifications_read_usecase.dart';
import '../../features/support/domain/usecases/mark_notification_read_usecase.dart';
import '../../features/support/domain/usecases/reply_to_ticket_usecase.dart';
import '../../features/support/presentation/bloc/notifications_bloc.dart';
import '../../features/support/presentation/bloc/support_bloc.dart';
import '../../features/wallet/data/datasources/wallet_remote_data_source.dart';
import '../../features/wallet/data/datasources/wallet_remote_data_source_debug_fallback.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/repositories/wallet_repository.dart';
import '../../features/wallet/domain/usecases/get_transactions_usecase.dart';
import '../../features/wallet/domain/usecases/get_wallet_balance_usecase.dart';
import '../../features/wallet/domain/usecases/request_top_up_usecase.dart';
import '../../features/wallet/presentation/bloc/wallet_bloc.dart';
import '../network/auth_session_controller.dart';
import '../network/graphql_client_factory.dart';
import '../network/graphql_service.dart';

/// Manual composition root.
///
/// A plain singleton class, not a service-locator package (`get_it` et al.):
/// at this app's current size a hand-written graph is easier to read and
/// trace than a package would be. Revisit once the number of features makes
/// this file unwieldy.
class InjectionContainer {
  InjectionContainer._();

  static final InjectionContainer instance = InjectionContainer._();

  bool _initialized = false;

  late final FlutterSecureStorage secureStorage;
  late final AuthSessionController authSessionController;
  late final DataFreshness dataFreshness;
  late final GraphQLClientFactory graphQLClientFactory;
  late final GraphQLService graphQLService;

  late final AuthRemoteDataSource authRemoteDataSource;
  late final AuthLocalDataSource authLocalDataSource;
  late final AuthRepository authRepository;
  late final LoginUseCase loginUseCase;
  late final VerifyOtpUseCase verifyOtpUseCase;
  late final ResendOtpUseCase resendOtpUseCase;
  late final LogoutUseCase logoutUseCase;
  late final GetPersistedSessionUseCase getPersistedSessionUseCase;

  late final PasswordRecoveryRepository passwordRecoveryRepository;
  late final RequestPasswordResetCodeUseCase requestPasswordResetCodeUseCase;
  late final ResendPasswordResetCodeUseCase resendPasswordResetCodeUseCase;
  late final VerifyPasswordResetCodeUseCase verifyPasswordResetCodeUseCase;
  late final ResetPasswordUseCase resetPasswordUseCase;

  late final AgencyRegistrationRepository agencyRegistrationRepository;
  late final StartAgencyRegistrationUseCase startAgencyRegistrationUseCase;
  late final ResendRegistrationCodeUseCase resendRegistrationCodeUseCase;
  late final VerifyRegistrationPhoneUseCase verifyRegistrationPhoneUseCase;
  late final CompleteAgencyRegistrationUseCase completeAgencyRegistrationUseCase;

  late final WalletRemoteDataSource walletRemoteDataSource;
  late final WalletRepository walletRepository;
  late final GetWalletBalanceUseCase getWalletBalanceUseCase;
  late final GetTransactionsUseCase getTransactionsUseCase;
  late final RequestTopUpUseCase requestTopUpUseCase;
  late final CancelTopUpUseCase cancelTopUpUseCase;
  late final ExportStatementUseCase exportStatementUseCase;

  late final ServicesRemoteDataSource servicesRemoteDataSource;
  late final ServicesRepository servicesRepository;
  late final GetAvailableServicesUseCase getAvailableServicesUseCase;
  late final SubmitBookingUseCase submitBookingUseCase;
  late final BookingDraftRepository bookingDraftRepository;
  late final RecentSearchesStore recentSearchesStore;

  /// The uploads running now: signing out warns about them (Figma AUTH-14).
  final pendingUploads = PendingUploads();
  late final GetBookingDraftsUseCase getBookingDraftsUseCase;
  late final SaveBookingDraftUseCase saveBookingDraftUseCase;
  late final DeleteBookingDraftUseCase deleteBookingDraftUseCase;

  late final RequestsRemoteDataSource requestsRemoteDataSource;
  late final RequestsRepository requestsRepository;
  late final GetRequestsUseCase getRequestsUseCase;
  late final GetRequestDetailUseCase getRequestDetailUseCase;
  late final CancelRequestUseCase cancelRequestUseCase;
  late final RemindApproverUseCase remindApproverUseCase;
  late final MissingDocumentRepository missingDocumentRepository;
  late final DocumentPicker documentPicker;
  late final DocumentFileRepository documentFileRepository;
  late final DocumentExporter documentExporter;
  late final FetchDocumentFileUseCase fetchDocumentFileUseCase;
  late final SaveDocumentUseCase saveDocumentUseCase;
  late final ShareDocumentUseCase shareDocumentUseCase;
  late final GetMissingDocumentUseCase getMissingDocumentUseCase;
  late final UploadMissingDocumentUseCase uploadMissingDocumentUseCase;
  late final PickDocumentUseCase pickDocumentUseCase;

  late final AgentsRemoteDataSource agentsRemoteDataSource;
  late final AgentsRepository agentsRepository;
  late final GetSubAgentsUseCase getSubAgentsUseCase;
  late final GetPendingApprovalRequestsUseCase getPendingApprovalRequestsUseCase;
  late final ApproveSubAgentRequestUseCase approveSubAgentRequestUseCase;
  late final RejectSubAgentRequestUseCase rejectSubAgentRequestUseCase;
  late final FundSubAgentWalletUseCase fundSubAgentWalletUseCase;
  late final CreateSubAgentUseCase createSubAgentUseCase;
  late final GetSubAgentProfileUseCase getSubAgentProfileUseCase;
  late final SetSubAgentActiveUseCase setSubAgentActiveUseCase;
  late final UpdateCreditLimitUseCase updateCreditLimitUseCase;

  late final SupportRemoteDataSource supportRemoteDataSource;
  late final GetAgencyProfileUseCase getAgencyProfileUseCase;
  late final GetMarginsUseCase getMarginsUseCase;
  late final SaveMarginsUseCase saveMarginsUseCase;
  late final TeamUseCases teamUseCases;
  late final AccountSecurityRepository accountSecurityRepository;
  late final HospitalRepository hospitalRepository;
  late final BranchRepository branchRepository;
  late final ServiceInterestRepository serviceInterestRepository;
  late final NotificationPreferencesRepository notificationPreferencesRepository;
  late final GetLegalDocumentUseCase getLegalDocumentUseCase;
  late final GetAppStatusUseCase getAppStatusUseCase;
  late final RequestAccessUseCase requestAccessUseCase;
  late final StoreLauncher storeLauncher;
  late final PushPermissionService pushPermissionService;
  late final AppSettingsLauncher appSettingsLauncher;
  late final SupportRepository supportRepository;
  late final GetTicketsUseCase getTicketsUseCase;
  late final CreateTicketUseCase createTicketUseCase;
  late final ReplyToTicketUseCase replyToTicketUseCase;
  late final GetNotificationsUseCase getNotificationsUseCase;
  late final MarkNotificationReadUseCase markNotificationReadUseCase;
  late final MarkAllNotificationsReadUseCase markAllNotificationsReadUseCase;

  /// Builds the dependency graph. Call once, before `runApp`. Safe to call
  /// more than once — subsequent calls are no-ops.
  void init() {
    if (_initialized) return;
    _initialized = true;

    secureStorage = const FlutterSecureStorage();
    authSessionController = AuthSessionController();
    graphQLClientFactory = GraphQLClientFactory(
      authSessionController: authSessionController,
      secureStorage: secureStorage,
    );
    dataFreshness = DataFreshness();
    graphQLService = GraphQLService(clientFactory: graphQLClientFactory, freshness: dataFreshness);

    authRemoteDataSource =
        AuthRemoteDataSourceImpl(graphQLService: graphQLService);
    authLocalDataSource =
        AuthLocalDataSourceImpl(secureStorage: secureStorage);
    authRepository = AuthRepositoryImpl(
      remote: authRemoteDataSource,
      local: authLocalDataSource,
    );

    // Inert in release builds: the fallback is gated on `kDebugMode`.
    passwordRecoveryRepository = PasswordRecoveryRepositoryImpl(
      remote: DebugFallbackPasswordRecoveryRemoteDataSource(
        PasswordRecoveryRemoteDataSourceImpl(graphQLService: graphQLService),
      ),
    );
    requestPasswordResetCodeUseCase = RequestPasswordResetCodeUseCase(passwordRecoveryRepository);
    resendPasswordResetCodeUseCase = ResendPasswordResetCodeUseCase(passwordRecoveryRepository);
    verifyPasswordResetCodeUseCase = VerifyPasswordResetCodeUseCase(passwordRecoveryRepository);
    resetPasswordUseCase = ResetPasswordUseCase(passwordRecoveryRepository);

    agencyRegistrationRepository = AgencyRegistrationRepositoryImpl(
      remote: DebugFallbackAgencyRegistrationRemoteDataSource(
        AgencyRegistrationRemoteDataSourceImpl(graphQLService: graphQLService),
      ),
    );
    startAgencyRegistrationUseCase = StartAgencyRegistrationUseCase(agencyRegistrationRepository);
    resendRegistrationCodeUseCase = ResendRegistrationCodeUseCase(agencyRegistrationRepository);
    verifyRegistrationPhoneUseCase = VerifyRegistrationPhoneUseCase(agencyRegistrationRepository);
    completeAgencyRegistrationUseCase = CompleteAgencyRegistrationUseCase(agencyRegistrationRepository);

    loginUseCase = LoginUseCase(authRepository);
    verifyOtpUseCase = VerifyOtpUseCase(authRepository);
    resendOtpUseCase = ResendOtpUseCase(authRepository);
    logoutUseCase = LogoutUseCase(authRepository);
    getPersistedSessionUseCase = GetPersistedSessionUseCase(authRepository);

    // Wrapped unconditionally: the fallback is itself gated on `kDebugMode`
    // (a compile-time constant), so this is a no-op passthrough — and is
    // dead-code-eliminated entirely — in a release build.
    walletRemoteDataSource = DebugFallbackWalletRemoteDataSource(
      WalletRemoteDataSourceImpl(graphQLService: graphQLService),
    );
    walletRepository = WalletRepositoryImpl(remote: walletRemoteDataSource);
    getWalletBalanceUseCase = GetWalletBalanceUseCase(walletRepository);
    getTransactionsUseCase = GetTransactionsUseCase(walletRepository);
    requestTopUpUseCase = RequestTopUpUseCase(walletRepository);
    cancelTopUpUseCase = CancelTopUpUseCase(TopUpCancellationRepositoryImpl(remote: walletRemoteDataSource));
    exportStatementUseCase = ExportStatementUseCase(StatementRepositoryImpl(remote: walletRemoteDataSource));

    // Same reasoning as the wallet fallback above: inert in release builds.
    servicesRemoteDataSource = DebugFallbackServicesRemoteDataSource(
      ServicesRemoteDataSourceImpl(graphQLService: graphQLService),
    );
    servicesRepository = ServicesRepositoryImpl(remote: servicesRemoteDataSource);
    getAvailableServicesUseCase = GetAvailableServicesUseCase(servicesRepository);
    submitBookingUseCase = SubmitBookingUseCase(servicesRepository);
    // Drafts live on the device, in encrypted storage, one document per agent.
    bookingDraftRepository = BookingDraftRepositoryImpl(
      local: SecureBookingDraftLocalDataSource(
        storage: secureStorage,
        userId: () async => (await authRepository.getPersistedSession())?.userId,
      ),
    );
    recentSearchesStore = SecureRecentSearchesStore(
      storage: secureStorage,
      userId: () async => (await authRepository.getPersistedSession())?.userId,
    );
    getBookingDraftsUseCase = GetBookingDraftsUseCase(bookingDraftRepository);
    saveBookingDraftUseCase = SaveBookingDraftUseCase(bookingDraftRepository);
    deleteBookingDraftUseCase = DeleteBookingDraftUseCase(bookingDraftRepository);

    // Same reasoning as the wallet/services fallbacks above: inert in
    // release builds.
    requestsRemoteDataSource = DebugFallbackRequestsRemoteDataSource(
      RequestsRemoteDataSourceImpl(graphQLService: graphQLService),
    );
    requestsRepository = RequestsRepositoryImpl(remote: requestsRemoteDataSource);
    getRequestsUseCase = GetRequestsUseCase(requestsRepository);
    getRequestDetailUseCase = GetRequestDetailUseCase(requestsRepository);
    cancelRequestUseCase = CancelRequestUseCase(requestsRepository);
    remindApproverUseCase = RemindApproverUseCase(requestsRepository);
    missingDocumentRepository = MissingDocumentRepositoryImpl(
      remote: DebugFallbackMissingDocumentRemoteDataSource(
        MissingDocumentRemoteDataSourceImpl(graphQLService: graphQLService),
      ),
    );
    documentPicker = PluginDocumentPicker();
    getMissingDocumentUseCase = GetMissingDocumentUseCase(missingDocumentRepository);
    uploadMissingDocumentUseCase = UploadMissingDocumentUseCase(missingDocumentRepository);
    pickDocumentUseCase = PickDocumentUseCase(documentPicker);
    documentFileRepository = DocumentFileRepositoryImpl(
      remote: DebugFallbackDocumentFileRemoteDataSource(DocumentFileRemoteDataSourceImpl()),
    );
    documentExporter = PluginDocumentExporter();
    fetchDocumentFileUseCase = FetchDocumentFileUseCase(documentFileRepository);
    saveDocumentUseCase = SaveDocumentUseCase(documentExporter);
    shareDocumentUseCase = ShareDocumentUseCase(documentExporter);

    // Same reasoning as the other feature fallbacks above: inert in release
    // builds.
    agentsRemoteDataSource = DebugFallbackAgentsRemoteDataSource(
      AgentsRemoteDataSourceImpl(graphQLService: graphQLService),
    );
    agentsRepository = AgentsRepositoryImpl(remote: agentsRemoteDataSource);
    getSubAgentsUseCase = GetSubAgentsUseCase(agentsRepository);
    getPendingApprovalRequestsUseCase =
        GetPendingApprovalRequestsUseCase(agentsRepository);
    approveSubAgentRequestUseCase = ApproveSubAgentRequestUseCase(agentsRepository);
    rejectSubAgentRequestUseCase = RejectSubAgentRequestUseCase(agentsRepository);
    fundSubAgentWalletUseCase = FundSubAgentWalletUseCase(agentsRepository);
    createSubAgentUseCase = CreateSubAgentUseCase(agentsRepository);
    getSubAgentProfileUseCase = GetSubAgentProfileUseCase(agentsRepository);
    setSubAgentActiveUseCase = SetSubAgentActiveUseCase(agentsRepository);
    updateCreditLimitUseCase = UpdateCreditLimitUseCase(agentsRepository);

    // Same reasoning as the other feature fallbacks above: inert in release
    // builds.
    supportRemoteDataSource = DebugFallbackSupportRemoteDataSource(
      SupportRemoteDataSourceImpl(graphQLService: graphQLService),
    );
    supportRepository = SupportRepositoryImpl(remote: supportRemoteDataSource);
    final profileRepository = ProfileRepositoryImpl(
      remote: DebugFallbackProfileRemoteDataSource(ProfileRemoteDataSourceImpl(graphQLService: graphQLService)),
    );
    getAgencyProfileUseCase = GetAgencyProfileUseCase(profileRepository);
    getMarginsUseCase = GetMarginsUseCase(profileRepository);
    saveMarginsUseCase = SaveMarginsUseCase(profileRepository);
    teamUseCases = TeamUseCases(profileRepository);
    accountSecurityRepository =
        DebugFallbackAccountSecurityRepository(AccountSecurityRemoteDataSource(graphQLService: graphQLService));
    notificationPreferencesRepository = DebugFallbackNotificationPreferencesRepository(
      NotificationPreferencesRemoteDataSource(graphQLService: graphQLService),
    );
    serviceInterestRepository = ServiceInterestRepositoryImpl(graphQLService: graphQLService);
    branchRepository = DebugFallbackBranchRepository(BranchRemoteDataSource(graphQLService: graphQLService));
    hospitalRepository = DebugFallbackHospitalRepository(HospitalRemoteDataSource(graphQLService: graphQLService));
    getLegalDocumentUseCase = GetLegalDocumentUseCase(
      LegalRepositoryImpl(
        remote: DebugFallbackLegalRemoteDataSource(LegalRemoteDataSourceImpl(graphQLService: graphQLService)),
        cache: const SharedPreferencesLegalCache(),
      ),
    );
    final systemStatusRepository = SystemStatusRepositoryImpl(
      remote: DebugFallbackSystemStatusRemoteDataSource(
        SystemStatusRemoteDataSourceImpl(graphQLService: graphQLService),
      ),
    );
    getAppStatusUseCase = GetAppStatusUseCase(systemStatusRepository);
    requestAccessUseCase = RequestAccessUseCase(systemStatusRepository);
    storeLauncher = const UrlStoreLauncher();
    pushPermissionService = PluginPushPermissionService();
    appSettingsLauncher = const UrlAppSettingsLauncher();
    getTicketsUseCase = GetTicketsUseCase(supportRepository);
    createTicketUseCase = CreateTicketUseCase(supportRepository);
    replyToTicketUseCase = ReplyToTicketUseCase(supportRepository);
    getNotificationsUseCase = GetNotificationsUseCase(supportRepository);
    markNotificationReadUseCase = MarkNotificationReadUseCase(supportRepository);
    markAllNotificationsReadUseCase = MarkAllNotificationsReadUseCase(supportRepository);
  }

  /// Builds a fresh [AuthBloc] and kicks off session restore. Call once per
  /// app run (e.g. from the root `BlocProvider`) — the Bloc, not this
  /// container, owns its lifetime from here on.
  AuthBloc createAuthBloc() => AuthBloc(
        loginUseCase: loginUseCase,
        verifyOtpUseCase: verifyOtpUseCase,
        resendOtpUseCase: resendOtpUseCase,
        logoutUseCase: logoutUseCase,
        getPersistedSessionUseCase: getPersistedSessionUseCase,
        authSessionController: authSessionController,
      )..add(const AuthCheckRequested());

  /// Builds a fresh [PasswordRecoveryBloc]; the forgot-password flow owns it.
  PasswordRecoveryBloc createPasswordRecoveryBloc() => PasswordRecoveryBloc(
        requestCode: requestPasswordResetCodeUseCase,
        resendCode: resendPasswordResetCodeUseCase,
        verifyCode: verifyPasswordResetCodeUseCase,
        resetPassword: resetPasswordUseCase,
      );

  /// Builds a fresh [AgencyRegistrationBloc]; the registration flow owns it.
  AgencyRegistrationBloc createAgencyRegistrationBloc(AgencyRegistrationDraft draft) => AgencyRegistrationBloc(
        draft: draft,
        start: startAgencyRegistrationUseCase,
        resendCode: resendRegistrationCodeUseCase,
        verifyPhone: verifyRegistrationPhoneUseCase,
        complete: completeAgencyRegistrationUseCase,
      );

  /// Builds a fresh [WalletBloc]. The caller (the wallet screen's own
  /// `BlocProvider`) owns its lifetime from here on.
  WalletBloc createWalletBloc() => WalletBloc(
        getWalletBalanceUseCase: getWalletBalanceUseCase,
        getTransactionsUseCase: getTransactionsUseCase,
        requestTopUpUseCase: requestTopUpUseCase,
      );

  /// Builds a fresh [ServiceBookingBloc]. [validator] is built by the caller
  /// (needs `AppLocalizations`, only available where there's a `BuildContext`)
  /// — see `ServiceSelectionScreen.buildValidator`.
  ServiceBookingBloc createServiceBookingBloc({
    required DynamicFieldValidator validator,
  }) =>
      ServiceBookingBloc(
        getAvailableServicesUseCase: getAvailableServicesUseCase,
        submitBookingUseCase: submitBookingUseCase,
        getWalletBalanceUseCase: getWalletBalanceUseCase,
        validator: validator,
        deleteDraftUseCase: deleteBookingDraftUseCase,
      );

  /// Builds a fresh [DraftsBloc]; the drafts list screen owns it.
  DraftsBloc createDraftsBloc() => DraftsBloc(getDrafts: getBookingDraftsUseCase, deleteDraft: deleteBookingDraftUseCase, saveDraft: saveBookingDraftUseCase);

  /// The PDF engine for the document viewer. No PDF plugin is installed yet, so
  /// this is null and PDFs fall back to the download / share card; wire an
  /// adapter over a PDF plugin here (docs/BACKEND_MIGRATION_GAPS.md, section 13).
  PdfPageRenderer Function()? get createPdfPageRenderer => null;

  /// Builds a fresh [DocumentViewerBloc]; the viewer screen owns it.
  DocumentViewerBloc createDocumentViewerBloc() => DocumentViewerBloc(
        fetchDocument: fetchDocumentFileUseCase,
        saveDocument: saveDocumentUseCase,
        shareDocument: shareDocumentUseCase,
      );

  /// Builds a fresh [MissingDocumentBloc]; the upload screen owns it.
  MissingDocumentBloc createMissingDocumentBloc() => MissingDocumentBloc(
        pendingUploads: pendingUploads,
        getMissingDocument: getMissingDocumentUseCase,
        uploadDocument: uploadMissingDocumentUseCase,
        pickDocument: pickDocumentUseCase,
      );

  /// Builds a fresh [StatementExportCubit]; the export sheet owns it.
  StatementExportCubit createStatementExportCubit() => StatementExportCubit(
        exportStatement: exportStatementUseCase,
        fetchDocument: fetchDocumentFileUseCase,
        saveDocument: saveDocumentUseCase,
        shareDocument: shareDocumentUseCase,
      );

  /// Builds a fresh [TopUpHistoryCubit]; the history screen owns it.
  TopUpHistoryCubit createTopUpHistoryCubit() => TopUpHistoryCubit(getTransactions: getTransactionsUseCase);

  /// Builds a fresh [TopUpCancelCubit]; the top-up detail screen owns it.
  TopUpCancelCubit createTopUpCancelCubit() => TopUpCancelCubit(cancelTopUp: cancelTopUpUseCase);

  /// Builds a fresh [RecentSearchesCubit]; the search screen owns it.
  RecentSearchesCubit createRecentSearchesCubit() => RecentSearchesCubit(recentSearchesStore);

  /// Builds a fresh [ApproverReminderCubit]; the detail's action bar owns it.
  ApproverReminderCubit createApproverReminderCubit() => ApproverReminderCubit(remindApprover: remindApproverUseCase);

  /// Builds a fresh [RequestsBloc]. The caller (the dashboard screen's own
  /// `BlocProvider`) owns its lifetime from here on.
  RequestsBloc createRequestsBloc() => RequestsBloc(
        getRequestsUseCase: getRequestsUseCase,
        getRequestDetailUseCase: getRequestDetailUseCase,
        cancelRequestUseCase: cancelRequestUseCase,
      );

  /// Builds the cubit of the notification-permission screen; the screen owns it.
  PushPermissionCubit createPushPermissionCubit() => PushPermissionCubit(pushPermissionService);

  /// Builds the cubits of the account screens (agency details, margins, team); each screen owns its own.
  AgencyDetailsCubit createAgencyDetailsCubit() => AgencyDetailsCubit(getAgencyProfileUseCase);

  MarginsCubit createMarginsCubit({required bool canEdit}) =>
      MarginsCubit(get: getMarginsUseCase, save: saveMarginsUseCase, canEdit: canEdit);

  TeamCubit createTeamCubit() => TeamCubit(teamUseCases);

  /// Builds the cubit of the notification-preferences screen; the screen owns it.
  NotificationPreferencesCubit createNotificationPreferencesCubit() =>
      NotificationPreferencesCubit(notificationPreferencesRepository);

  /// Builds the "notify me at launch" cubit of the coming-soon sheet; the sheet owns it.
  ServiceInterestCubit createServiceInterestCubit(String serviceKey) =>
      ServiceInterestCubit(serviceInterestRepository, serviceKey: serviceKey);

  /// Builds the cubit of the branches screen; the screen owns it.
  BranchesCubit createBranchesCubit() => BranchesCubit(branches: branchRepository, team: teamUseCases);

  /// Builds the hospital picker's cubit for a medical service; the sheet owns it.
  HospitalPickerCubit createHospitalPickerCubit(String serviceId) =>
      HospitalPickerCubit(hospitalRepository, serviceId: serviceId);

  /// Builds the cubits of the change-password / change-phone screens; each screen owns its own.
  ChangePasswordCubit createChangePasswordCubit() => ChangePasswordCubit(accountSecurityRepository);

  ChangePhoneCubit createChangePhoneCubit() => ChangePhoneCubit(accountSecurityRepository);

  /// Builds the cubit of a legal text screen (terms or privacy); the screen owns it.
  LegalCubit createLegalCubit(LegalKind kind, LegalLanguage initial) =>
      LegalCubit(kind: kind, initial: initial, get: getLegalDocumentUseCase);

  /// Builds the app-wide [AppStatusCubit] (maintenance / update gate); the root provider owns it.
  AppStatusCubit createAppStatusCubit() => AppStatusCubit(
        getStatus: getAppStatusUseCase,
        currentVersion: () async => (await PackageInfo.fromPlatform()).version,
      );

  /// Builds an [AccessRequestCubit] for a refused [area]; the no-permission view owns it.
  AccessRequestCubit createAccessRequestCubit(String area) => AccessRequestCubit(requestAccessUseCase, area: area);

  /// Builds the app-wide [ConnectivityCubit]; the root provider owns it.
  ConnectivityCubit createConnectivityCubit() =>
      ConnectivityCubit(monitor: PluginConnectivityMonitor(), freshness: dataFreshness);

  /// Builds a fresh [AgentProfileBloc]; the profile screen owns it.
  AgentProfileBloc createAgentProfileBloc() =>
      AgentProfileBloc(getProfile: getSubAgentProfileUseCase, setActive: setSubAgentActiveUseCase);

  /// Builds a fresh [AddSubAgentBloc]; the add-agent screen owns it.
  AddSubAgentBloc createAddSubAgentBloc() => AddSubAgentBloc(createSubAgent: createSubAgentUseCase);

  /// Builds a fresh [CreditLimitBloc]; the credit-limit sheet owns it.
  CreditLimitBloc createCreditLimitBloc() => CreditLimitBloc(updateCreditLimit: updateCreditLimitUseCase);

  /// Builds a fresh [AgentsBloc]. The caller (the sub-agents list screen's
  /// own `BlocProvider`) owns its lifetime from here on.
  AgentsBloc createAgentsBloc() => AgentsBloc(
        getSubAgentsUseCase: getSubAgentsUseCase,
        getPendingApprovalRequestsUseCase: getPendingApprovalRequestsUseCase,
        approveSubAgentRequestUseCase: approveSubAgentRequestUseCase,
        rejectSubAgentRequestUseCase: rejectSubAgentRequestUseCase,
        fundSubAgentWalletUseCase: fundSubAgentWalletUseCase,
        getWalletBalanceUseCase: getWalletBalanceUseCase,
      );

  /// Builds a fresh [SupportBloc]. The caller (the tickets list screen's
  /// own `BlocProvider`) owns its lifetime from here on.
  TicketActionsCubit createTicketActionsCubit() => TicketActionsCubit(
        markRead: MarkTicketReadUseCase(TicketActionsRepositoryImpl(remote: supportRemoteDataSource)),
        reopen: ReopenTicketUseCase(TicketActionsRepositoryImpl(remote: supportRemoteDataSource)),
      );

  SupportBloc createSupportBloc() => SupportBloc(
        getTicketsUseCase: getTicketsUseCase,
        createTicketUseCase: createTicketUseCase,
        replyToTicketUseCase: replyToTicketUseCase,
      );

  /// Builds a fresh [NotificationsBloc]. The caller (the notifications
  /// screen's own `BlocProvider`) owns its lifetime from here on.
  NotificationsBloc createNotificationsBloc() => NotificationsBloc(
        getNotificationsUseCase: getNotificationsUseCase,
        markNotificationReadUseCase: markNotificationReadUseCase,
        markAllNotificationsReadUseCase: markAllNotificationsReadUseCase,
      );
}
