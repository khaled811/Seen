import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../state/branch_scope.dart';
import '../../features/ads/data/datasources/ads_remote_data_source.dart';
import '../../features/home/data/datasources/home_remote_data_source.dart';
import '../../features/home/domain/repositories/home_repository.dart';
import '../../features/home/presentation/bloc/home_services_cubit.dart';
import '../../features/agents/data/datasources/sub_agent_edit_remote_data_source.dart';
import '../../features/agents/data/datasources/sub_agent_reclaim_remote_data_source.dart';
import '../../features/agents/domain/usecases/update_sub_agent_usecase.dart';
import '../../features/agents/presentation/bloc/edit_sub_agent_cubit.dart';
import '../../features/agents/data/datasources/sub_agent_top_up_remote_data_source.dart';
import '../../features/agents/domain/usecases/reclaim_from_sub_agent_usecase.dart';
import '../../features/agents/presentation/bloc/reclaim_cubit.dart';
import '../../features/agents/domain/usecases/sub_agent_top_up_usecases.dart';
import '../../features/agents/presentation/bloc/sub_agent_top_ups_cubit.dart';
import '../../features/services/data/datasources/prefill_remote_data_source.dart';
import '../../features/services/domain/repositories/prefill_repository.dart';
import '../../features/services/domain/usecases/prefill_usecases.dart';
import '../../features/services/presentation/bloc/prefill_cubit.dart';
import '../../features/ads/domain/repositories/ads_repository.dart';
import '../../features/ads/presentation/bloc/home_banner_cubit.dart';
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
import '../../features/requests/data/datasources/in_memory_recent_searches_store.dart';
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
import '../../features/services/presentation/bloc/drafts_bloc.dart';
import '../../features/auth/data/datasources/password_recovery_remote_data_source.dart';
import '../../features/auth/data/datasources/password_recovery_remote_data_source_debug_fallback.dart';
import '../../features/auth/data/repositories/password_recovery_repository_impl.dart';
import '../../features/auth/domain/repositories/password_recovery_repository.dart';
import '../../features/auth/domain/usecases/password_recovery_usecases.dart';
import '../../features/auth/presentation/bloc/password_recovery_bloc.dart';
import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_persisted_session_usecase.dart';
import '../../features/auth/domain/usecases/login_usecase.dart';
import '../../features/auth/domain/usecases/logout_usecase.dart';
import '../../features/auth/domain/usecases/resend_otp_usecase.dart';
import '../../features/auth/domain/usecases/verify_otp_usecase.dart';
import '../../features/agents/data/datasources/agents_remote_data_source.dart';
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
import '../../features/services/data/datasources/booking_flow_remote_data_source.dart';
import '../../features/services/data/repositories/booking_flow_repository_impl.dart';
import '../../features/services/domain/repositories/booking_flow_repository.dart';
import '../../features/services/domain/usecases/booking_flow_usecases.dart';
import '../../features/services/presentation/bloc/service_booking_bloc.dart';
import '../../features/profile/data/datasources/profile_remote_data_source.dart';
import '../../features/profile/data/repositories/profile_repository_impl.dart';
import '../../features/profile/domain/usecases/profile_usecases.dart';
import '../../features/profile/presentation/bloc/margin_agents_cubit.dart';
import '../../features/profile/presentation/bloc/profile_cubits.dart';
import '../../features/auth/data/datasources/account_security_remote_data_source.dart';
import '../../features/auth/data/datasources/two_factor_remote_data_source.dart';
import '../../features/auth/data/datasources/email_change_remote_data_source.dart';
import '../../features/auth/domain/repositories/account_security_repository.dart';
import '../../features/auth/domain/repositories/two_factor_repository.dart';
import '../../features/auth/domain/repositories/email_change_repository.dart';
import '../../features/auth/presentation/bloc/account_security_cubits.dart';
import '../../features/auth/presentation/bloc/two_factor_cubits.dart';
import '../../features/auth/presentation/bloc/email_change_cubit.dart';
import '../../features/requests/data/datasources/sensitive_values_remote_data_source.dart';
import '../../features/profile/data/datasources/avatar_remote_data_source.dart';
import '../../features/profile/data/services/plugin_avatar_picker.dart';
import '../../features/profile/domain/repositories/avatar_repository.dart';
import '../../features/profile/domain/services/avatar_picker.dart';
import '../../features/profile/presentation/bloc/avatar_cubit.dart';
import '../../features/requests/domain/repositories/sensitive_values_repository.dart';
import '../../features/legal/data/datasources/legal_data_sources.dart';
import '../../features/manifest/data/datasources/manifest_data_source.dart';
import '../../features/manifest/data/services/external_url_opener.dart';
import '../../features/manifest/domain/repositories/manifest_repository.dart';
import '../../features/manifest/presentation/bloc/manifest_build_cubit.dart';
import '../../features/manifest/presentation/bloc/manifest_summary_cubit.dart';
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
import '../../features/support/presentation/bloc/unread_notifications_cubit.dart';
import '../../features/wallet/data/datasources/wallet_remote_data_source.dart';
import '../../features/wallet/data/datasources/wallet_remote_data_source_debug_fallback.dart';
import '../../features/wallet/data/repositories/wallet_repository_impl.dart';
import '../../features/wallet/domain/repositories/wallet_repository.dart';
import '../../features/wallet/domain/usecases/get_top_up_options_usecase.dart';
import '../../features/wallet/domain/usecases/get_transactions_usecase.dart';
import '../../features/wallet/domain/usecases/get_wallet_balance_usecase.dart';
import '../../features/wallet/domain/usecases/request_top_up_usecase.dart';
import '../../features/wallet/presentation/bloc/wallet_bloc.dart';
import '../localization/app_language.dart';
import '../network/api_client.dart';
import '../network/auth_session_controller.dart';
import '../network/graphql_client_factory.dart';
import '../network/dio_staged_file_uploader.dart';
import '../network/file_upload_client.dart';
import '../services/staged_file_uploader.dart';
import '../../features/requests/presentation/bloc/staged_attachment_cubit.dart';
import '../network/graphql_service.dart';
import '../network/secure_cookie_storage.dart';
import '../network/session_manager.dart';
import '../network/session_remote_data_source.dart';
import '../network/strict_cookie_jar.dart';
import '../storage/install_marker.dart';
import '../../features/support/data/datasources/ticket_rating_remote_data_source.dart';
import '../../features/support/data/datasources/ticket_categories_remote_data_source.dart';
import '../../features/support/data/datasources/unread_tickets_remote_data_source.dart';
import '../../features/support/domain/repositories/ticket_rating_repository.dart';
import '../../features/support/domain/repositories/ticket_categories_repository.dart';
import '../../features/support/domain/repositories/unread_tickets_repository.dart';
import '../../features/support/presentation/bloc/ticket_rating_cubit.dart';
import '../../features/support/presentation/bloc/ticket_categories_cubit.dart';
import '../../features/support/presentation/bloc/unread_tickets_cubit.dart';
import '../../features/services/data/datasources/passport_reader_remote_data_source.dart';
import '../../features/services/data/services/plugin_passport_photo_picker.dart';
import '../../features/services/domain/repositories/passport_reader_repository.dart';
import '../../features/services/domain/services/passport_photo_picker.dart';
import '../../features/services/presentation/bloc/passport_scan_cubit.dart';
import '../../features/reports/data/datasources/reports_remote_data_source.dart';
import '../../features/reports/domain/entities/report.dart';
import '../../features/reports/domain/repositories/reports_repository.dart';
import '../../features/reports/presentation/bloc/report_cubits.dart';

/// Test seams for [InjectionContainer.init]. Production passes nothing.
///
/// Only the lowest-level collaborators are swappable on purpose: replacing the
/// [GraphQLService] gives every data source a controlled transport without
/// touching the rest of the graph.
class InjectionOverrides {
  const InjectionOverrides({this.graphQLService, this.secureStorage, this.sessionRemote});

  final GraphQLService? graphQLService;
  final FlutterSecureStorage? secureStorage;

  /// Replaces the real `refresh` / `logout` calls (they would otherwise go to
  /// the network).
  final SessionRemoteDataSource? sessionRemote;
}

/// Manual composition root.
///
/// A plain singleton class, not a service-locator package (`get_it` et al.):
/// at this app's current size a hand-written graph is easier to read and
/// trace than a package would be. Revisit once the number of features makes
/// this file unwieldy.
class InjectionContainer {
  InjectionContainer._();

  static final InjectionContainer instance = InjectionContainer._();

  /// Overrides applied when `init()` is called without any — set once from
  /// `test/flutter_test_config.dart` so every test that boots the real graph
  /// gets a controlled transport. Always null in the app.
  @visibleForTesting
  static InjectionOverrides? testDefaults;

  bool _initialized = false;

  late final FlutterSecureStorage secureStorage;
  late final AuthSessionController authSessionController;
  late final DataFreshness dataFreshness;
  /// The language the data layer picks `…Ar` / `…En` fields in.
  final appLanguage = AppLanguage();
  late final ApiClient apiClient;
  late final StrictPersistCookieJar cookieJar;
  late final SessionManager sessionManager;
  late final GraphQLClientFactory graphQLClientFactory;
  late final GraphQLService graphQLService;

  late final AuthRemoteDataSource authRemoteDataSource;
  late final AuthRepository authRepository;
  late final LoginUseCase loginUseCase;
  late final VerifyOtpUseCase verifyOtpUseCase;
  late final ResendOtpUseCase resendOtpUseCase;
  late final LogoutUseCase logoutUseCase;
  late final GetPersistedSessionUseCase getPersistedSessionUseCase;

  late final PasswordRecoveryRepository passwordRecoveryRepository;
  late final RequestPasswordResetUseCase requestPasswordResetUseCase;

  late final AgencyRegistrationRepository agencyRegistrationRepository;
  late final RegisterAgencyUseCase registerAgencyUseCase;

  late final WalletRemoteDataSource walletRemoteDataSource;
  late final WalletRepository walletRepository;
  late final GetWalletBalanceUseCase getWalletBalanceUseCase;
  late final GetTransactionsUseCase getTransactionsUseCase;
  late final RequestTopUpUseCase requestTopUpUseCase;
  late final GetTopUpOptionsUseCase getTopUpOptionsUseCase;
  late final CancelTopUpUseCase cancelTopUpUseCase;
  late final ExportStatementUseCase exportStatementUseCase;

  late final ServicesRemoteDataSource servicesRemoteDataSource;
  late final ServicesRepository servicesRepository;
  late final GetAvailableServicesUseCase getAvailableServicesUseCase;
  late final FileUploadClient fileUploadClient;
  late final StagedFileUploader stagedFileUploader;
  late final BookingFlowRemoteDataSource bookingFlowRemoteDataSource;
  late final BookingFlowRepository bookingFlowRepository;
  late final CreateDraftRequestUseCase createDraftRequestUseCase;
  late final AddTravelersUseCase addTravelersUseCase;
  late final UploadBookingDocumentUseCase uploadBookingDocumentUseCase;
  late final ReviewDraftUseCase reviewDraftUseCase;
  late final SubmitDraftRequestUseCase submitDraftRequestUseCase;
  late final RecentSearchesStore recentSearchesStore;

  /// The uploads running now: signing out warns about them (Figma AUTH-14).
  final pendingUploads = PendingUploads();

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
  late final FetchRequestFileUseCase fetchRequestFileUseCase;
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

  late final SupportRemoteDataSource supportRemoteDataSource;
  late final GetAgencyProfileUseCase getAgencyProfileUseCase;
  late final AdsRepository adsRepository;
  late final HomeRepository homeRepository;
  late final SubAgentTopUpUseCases subAgentTopUpUseCases;
  late final ReclaimFromSubAgentUseCase reclaimFromSubAgentUseCase;
  late final UpdateSubAgentUseCase updateSubAgentUseCase;
  late final PrefillRepository prefillRepository;
  late final GetMarginsUseCase getMarginsUseCase;
  late final SaveMarginsUseCase saveMarginsUseCase;
  late final TeamUseCases teamUseCases;
  late final AccountSecurityRepository accountSecurityRepository;
  late final TwoFactorRepository twoFactorRepository;
  late final EmailChangeRepository emailChangeRepository;
  late final SensitiveValuesRepository sensitiveValuesRepository;
  late final AvatarRepository avatarRepository;
  late final ReportsRepository reportsRepository;
  late final PassportReaderRepository passportReaderRepository;
  late final PassportPhotoPicker passportPhotoPicker;
  late final TicketRatingRepository ticketRatingRepository;
  late final TicketCategoriesRepository ticketCategoriesRepository;
  late final UnreadTicketsRepository unreadTicketsRepository;

  /// The unread-support count on Home's badge; emptied when the session ends.
  late final UnreadTicketsCubit unreadTicketsCubit;
  late final AvatarPicker avatarPicker;

  /// The signed-in user's profile photo, shared by the screens that show it; emptied when the
  /// session ends.
  late final AvatarCubit avatarCubit;
  late final HospitalRepository hospitalRepository;
  late final ManifestRepository manifestRepository;
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
  late final GetTicketUseCase getTicketUseCase;
  late final GetUnreadNotificationCountUseCase getUnreadNotificationCountUseCase;
  late final GetNotificationsUseCase getNotificationsUseCase;
  late final MarkNotificationReadUseCase markNotificationReadUseCase;
  late final MarkAllNotificationsReadUseCase markAllNotificationsReadUseCase;

  /// Builds the dependency graph. Call once, before `runApp`. Safe to call
  /// more than once — subsequent calls are no-ops, so [overrides] only take
  /// effect on the first call (asserted in debug builds).
  void init({InjectionOverrides? overrides}) {
    if (_initialized) {
      assert(overrides == null, 'InjectionContainer is already initialised; overrides were ignored.');
      return;
    }
    _initialized = true;
    overrides ??= testDefaults;

    secureStorage = overrides?.secureStorage ?? const FlutterSecureStorage();
    authSessionController = AuthSessionController();
    // The refresh cookie lives in encrypted storage; a fresh install never
    // trusts what an earlier install left in the Keychain.
    cookieJar = StrictPersistCookieJar(
      storage: SecureCookieStorage(
        storage: secureStorage,
        beforeFirstUse: () async {
          if (await InstallMarker().isFirstRunThenMark()) await SecureCookieStorage.wipe(secureStorage);
        },
      ),
    );
    apiClient = ApiClient.create(
      cookieJar: cookieJar,
      session: authSessionController,
      sessionRemote: overrides?.sessionRemote,
    );
    graphQLClientFactory = GraphQLClientFactory(
      authSessionController: authSessionController,
      httpClient: apiClient.graphqlHttpClient(),
    );
    sessionManager = SessionManager(
      tokens: apiClient.tokens,
      coordinator: apiClient.coordinator,
      remote: apiClient.sessionRemote,
      cookieJar: cookieJar,
      clearHttpCache: graphQLClientFactory.clearCache,
      // Closures, not values: the stores are created further down.
      cleanups: [
        () => recentSearchesStore.clear(),
        // The branch the previous person was looking at must not carry over to the next account.
        () async => BranchScope.shared.value = null,
        // So does the profile photo.
        () async => avatarCubit.clear(),
        () async => unreadTicketsCubit.clear(),
      ],
    );
    dataFreshness = DataFreshness();
    graphQLService = overrides?.graphQLService ??
        GraphQLService(clientFactory: graphQLClientFactory, freshness: dataFreshness);

    authRemoteDataSource =
        AuthRemoteDataSourceImpl(graphQLService: graphQLService);
    authRepository = AuthRepositoryImpl(
      remote: authRemoteDataSource,
      session: sessionManager,
    );

    // Inert unless `DebugFallbacks.enabled` (debug build AND
    // `--dart-define=USE_DEBUG_FALLBACKS=true`); never active in release.
    passwordRecoveryRepository = PasswordRecoveryRepositoryImpl(
      remote: DebugFallbackPasswordRecoveryRemoteDataSource(
        PasswordRecoveryRemoteDataSourceImpl(graphQLService: graphQLService, language: appLanguage),
      ),
    );
    requestPasswordResetUseCase = RequestPasswordResetUseCase(passwordRecoveryRepository);

    agencyRegistrationRepository = AgencyRegistrationRepositoryImpl(
      remote: DebugFallbackAgencyRegistrationRemoteDataSource(
        AgencyRegistrationRemoteDataSourceImpl(graphQLService: graphQLService, language: appLanguage),
      ),
    );
    registerAgencyUseCase = RegisterAgencyUseCase(agencyRegistrationRepository);

    loginUseCase = LoginUseCase(authRepository);
    verifyOtpUseCase = VerifyOtpUseCase(authRepository);
    resendOtpUseCase = ResendOtpUseCase(authRepository);
    logoutUseCase = LogoutUseCase(authRepository);
    getPersistedSessionUseCase = GetPersistedSessionUseCase(authRepository);

    // Wrapped unconditionally: the fallback is itself gated on
    // `DebugFallbacks.enabled` (see core/config/debug_fallbacks.dart), so this
    // is a no-op passthrough unless a debug build opts in.
    walletRemoteDataSource = DebugFallbackWalletRemoteDataSource(
      WalletRemoteDataSourceImpl(graphQLService: graphQLService, language: appLanguage),
    );
    walletRepository = WalletRepositoryImpl(remote: walletRemoteDataSource);
    getWalletBalanceUseCase = GetWalletBalanceUseCase(walletRepository);
    getTransactionsUseCase = GetTransactionsUseCase(walletRepository);
    requestTopUpUseCase = RequestTopUpUseCase(walletRepository);
    getTopUpOptionsUseCase = GetTopUpOptionsUseCase(walletRepository);
    cancelTopUpUseCase = CancelTopUpUseCase(TopUpCancellationRepositoryImpl(remote: walletRemoteDataSource));
    exportStatementUseCase = ExportStatementUseCase(StatementRepositoryImpl(remote: walletRemoteDataSource));

    // Same reasoning as the wallet fallback above: inert in release builds.
    servicesRemoteDataSource = DebugFallbackServicesRemoteDataSource(
      ServicesRemoteDataSourceImpl(graphQLService: graphQLService, language: appLanguage),
    );
    servicesRepository = ServicesRepositoryImpl(remote: servicesRemoteDataSource);
    getAvailableServicesUseCase = GetAvailableServicesUseCase(servicesRepository);
    fileUploadClient = FileUploadClient(
      dio: apiClient.dio,
      coordinator: apiClient.coordinator,
      session: authSessionController,
      apiBase: apiClient.graphqlUri,
    );
    stagedFileUploader = DioStagedFileUploader(fileUploadClient);
    avatarPicker = PluginAvatarPicker();
    bookingFlowRemoteDataSource = BookingFlowRemoteDataSourceImpl(
      graphQLService: graphQLService,
      uploads: fileUploadClient,
      language: appLanguage,
    );
    bookingFlowRepository = BookingFlowRepositoryImpl(remote: bookingFlowRemoteDataSource);
    createDraftRequestUseCase = CreateDraftRequestUseCase(bookingFlowRepository);
    addTravelersUseCase = AddTravelersUseCase(bookingFlowRepository);
    uploadBookingDocumentUseCase = UploadBookingDocumentUseCase(bookingFlowRepository);
    reviewDraftUseCase = ReviewDraftUseCase(bookingFlowRepository);
    submitDraftRequestUseCase = SubmitDraftRequestUseCase(bookingFlowRepository);
    // Drafts and recent searches hold personal data, so they live in memory
    // only and are emptied by `sessionEndedCleanups` on logout/expiry.
    recentSearchesStore = InMemoryRecentSearchesStore();

    // Same reasoning as the wallet/services fallbacks above: inert in
    // release builds.
    requestsRemoteDataSource = DebugFallbackRequestsRemoteDataSource(
      RequestsRemoteDataSourceImpl(graphQLService: graphQLService, language: appLanguage),
    );
    requestsRepository = RequestsRepositoryImpl(remote: requestsRemoteDataSource);
    getRequestsUseCase = GetRequestsUseCase(requestsRepository);
    getRequestDetailUseCase = GetRequestDetailUseCase(requestsRepository);
    cancelRequestUseCase = CancelRequestUseCase(requestsRepository);
    remindApproverUseCase = RemindApproverUseCase(requestsRepository);
    missingDocumentRepository = MissingDocumentRepositoryImpl(
      remote: DebugFallbackMissingDocumentRemoteDataSource(
        MissingDocumentRemoteDataSourceImpl(
          graphQLService: graphQLService,
          uploads: fileUploadClient,
          language: appLanguage,
        ),
      ),
    );
    documentPicker = PluginDocumentPicker();
    getMissingDocumentUseCase = GetMissingDocumentUseCase(missingDocumentRepository);
    uploadMissingDocumentUseCase = UploadMissingDocumentUseCase(missingDocumentRepository);
    pickDocumentUseCase = PickDocumentUseCase(documentPicker);
    documentFileRepository = DocumentFileRepositoryImpl(
      remote: DebugFallbackDocumentFileRemoteDataSource(DocumentFileRemoteDataSourceImpl(graphQLService: graphQLService)),
    );
    documentExporter = PluginDocumentExporter();
    fetchDocumentFileUseCase = FetchDocumentFileUseCase(documentFileRepository);
    fetchRequestFileUseCase = FetchRequestFileUseCase(documentFileRepository);
    saveDocumentUseCase = SaveDocumentUseCase(documentExporter);
    shareDocumentUseCase = ShareDocumentUseCase(documentExporter);

    // Same reasoning as the other feature fallbacks above: inert in release
    // builds.
    agentsRemoteDataSource = AgentsRemoteDataSourceImpl(graphQLService: graphQLService, language: appLanguage);
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

    // Same reasoning as the other feature fallbacks above: inert in release
    // builds.
    supportRemoteDataSource = DebugFallbackSupportRemoteDataSource(
      SupportRemoteDataSourceImpl(graphQLService: graphQLService, language: appLanguage),
    );
    supportRepository = SupportRepositoryImpl(remote: supportRemoteDataSource);
    adsRepository = AdsRemoteDataSource(graphQLService: graphQLService, language: appLanguage);
    homeRepository = HomeRemoteDataSource(graphQLService: graphQLService, language: appLanguage);
    subAgentTopUpUseCases = SubAgentTopUpUseCases(SubAgentTopUpRemoteDataSource(graphQLService: graphQLService));
    updateSubAgentUseCase = UpdateSubAgentUseCase(SubAgentEditRemoteDataSource(graphQLService: graphQLService));
    reclaimFromSubAgentUseCase = ReclaimFromSubAgentUseCase(SubAgentReclaimRemoteDataSource(graphQLService: graphQLService));
    final profileRepository = ProfileRepositoryImpl(
      remote: ProfileRemoteDataSourceImpl(graphQLService: graphQLService, language: appLanguage),
    );
    getAgencyProfileUseCase = GetAgencyProfileUseCase(profileRepository);
    getMarginsUseCase = GetMarginsUseCase(profileRepository);
    saveMarginsUseCase = SaveMarginsUseCase(profileRepository);
    teamUseCases = TeamUseCases(profileRepository);
    accountSecurityRepository =
        DebugFallbackAccountSecurityRepository(AccountSecurityRemoteDataSource(graphQLService: graphQLService));
    twoFactorRepository = TwoFactorRemoteDataSource(graphQLService: graphQLService);
    emailChangeRepository = EmailChangeRemoteDataSource(graphQLService: graphQLService, language: appLanguage);
    sensitiveValuesRepository = SensitiveValuesRemoteDataSource(graphQLService: graphQLService, language: appLanguage);
    passportReaderRepository = PassportReaderRemoteDataSource(client: fileUploadClient);
    passportPhotoPicker = PluginPassportPhotoPicker();
    reportsRepository = ReportsRemoteDataSource(graphQLService: graphQLService, language: appLanguage);
    avatarRepository = AvatarRemoteDataSource(graphQLService: graphQLService, uploader: stagedFileUploader);
    avatarCubit = AvatarCubit(avatarRepository);
    ticketRatingRepository = TicketRatingRemoteDataSource(graphQLService: graphQLService);
    ticketCategoriesRepository = TicketCategoriesRemoteDataSource(graphQLService: graphQLService, language: appLanguage);
    unreadTicketsRepository = UnreadTicketsRemoteDataSource(graphQLService: graphQLService);
    unreadTicketsCubit = UnreadTicketsCubit(unreadTicketsRepository);
    notificationPreferencesRepository = DebugFallbackNotificationPreferencesRepository(
      const NotificationPreferencesRemoteDataSource(),
    );
    serviceInterestRepository = ServiceInterestRepositoryImpl();
    branchRepository = BranchRemoteDataSource(graphQLService: graphQLService);
    hospitalRepository = DebugFallbackHospitalRepository(const HospitalRemoteDataSource());
    manifestRepository = DebugFallbackManifestRepository(const ManifestRemoteDataSource());
    prefillRepository = PrefillRemoteDataSource(graphQLService: graphQLService, language: appLanguage);
    getLegalDocumentUseCase = GetLegalDocumentUseCase(
      LegalRepositoryImpl(
        remote: DebugFallbackLegalRemoteDataSource(LegalRemoteDataSourceImpl(graphQLService: graphQLService)),
        cache: const SharedPreferencesLegalCache(),
      ),
    );
    final systemStatusRepository = SystemStatusRepositoryImpl(
      remote: DebugFallbackSystemStatusRemoteDataSource(
        const SystemStatusRemoteDataSourceImpl(),
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
    getTicketUseCase = GetTicketUseCase(supportRepository);
    getUnreadNotificationCountUseCase = GetUnreadNotificationCountUseCase(supportRepository);
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
  PasswordRecoveryBloc createPasswordRecoveryBloc() => PasswordRecoveryBloc(requestReset: requestPasswordResetUseCase);

  /// Builds a fresh [AgencyRegistrationBloc]; the registration flow owns it.
  AgencyRegistrationBloc createAgencyRegistrationBloc(AgencyRegistrationDraft draft) => AgencyRegistrationBloc(
        draft: draft,
        register: registerAgencyUseCase,
      );

  /// A fresh optional attachment that is sent as soon as it is picked (top-up
  /// receipt, ticket file). The screen that asks for it owns and closes it.
  StagedAttachmentCubit createStagedAttachmentCubit() =>
      StagedAttachmentCubit(picker: () => documentPicker, uploader: () => stagedFileUploader);

  /// Builds a fresh [WalletBloc]. The caller (the wallet screen's own
  /// `BlocProvider`) owns its lifetime from here on.
  /// Builds the cubit that edits one sub-agency; the sheet owns it.
  EditSubAgentCubit createEditSubAgentCubit(String agentId, {required String name, required String ownerName}) =>
      EditSubAgentCubit(updateSubAgentUseCase, agentId: agentId, currentName: name, currentOwnerName: ownerName);

  /// Builds the cubit that takes money back from one sub-agency; the sheet owns it.
  ReclaimCubit createReclaimCubit(String subAgentId) => ReclaimCubit(reclaimFromSubAgentUseCase, subAgentId: subAgentId);

  /// Builds the sub-agent funding requests cubit; the approvals screen owns it.
  SubAgentTopUpsCubit createSubAgentTopUpsCubit() => SubAgentTopUpsCubit(subAgentTopUpUseCases);

  /// Builds a fresh [HomeServicesCubit]; the home screen owns it.
  HomeServicesCubit createHomeServicesCubit() => HomeServicesCubit(homeRepository);

  /// Builds a fresh [HomeBannerCubit]; the home screen owns it.
  HomeBannerCubit createHomeBannerCubit() => HomeBannerCubit(adsRepository);

  WalletBloc createWalletBloc() => WalletBloc(
        getWalletBalanceUseCase: getWalletBalanceUseCase,
        getTransactionsUseCase: getTransactionsUseCase,
        requestTopUpUseCase: requestTopUpUseCase,
        getTopUpOptionsUseCase: getTopUpOptionsUseCase,
      );

  /// Builds a fresh [ServiceBookingBloc]. [validator] is built by the caller
  /// (needs `AppLocalizations`, only available where there's a `BuildContext`)
  /// — see `ServiceSelectionScreen.buildValidator`.
  ServiceBookingBloc createServiceBookingBloc({
    required DynamicFieldValidator validator,
  }) =>
      ServiceBookingBloc(
        getAvailableServicesUseCase: getAvailableServicesUseCase,
        createDraftUseCase: createDraftRequestUseCase,
        addTravelersUseCase: addTravelersUseCase,
        uploadDocumentUseCase: uploadBookingDocumentUseCase,
        reviewDraftUseCase: reviewDraftUseCase,
        submitDraftUseCase: submitDraftRequestUseCase,
        getRequestDetailUseCase: getRequestDetailUseCase,
        validator: validator,
      );

  /// Builds a fresh [DraftsBloc]; the drafts list screen owns it.
  DraftsBloc createDraftsBloc() => DraftsBloc(getRequests: getRequestsUseCase);

  /// The PDF engine for the document viewer. No PDF plugin is installed yet, so
  /// this is null and PDFs fall back to the download / share card; wire an
  /// adapter over a PDF plugin here (docs/BACKEND_MIGRATION_GAPS.md, section 13).
  PdfPageRenderer Function()? get createPdfPageRenderer => null;

  /// Builds a fresh [DocumentViewerBloc]; the viewer screen owns it.
  DocumentViewerBloc createDocumentViewerBloc() => DocumentViewerBloc(
        fetchDocument: fetchDocumentFileUseCase,
        fetchFile: fetchRequestFileUseCase,
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

  MarginsCubit createMarginsCubit({required String agentId, required bool canEdit}) =>
      MarginsCubit(get: getMarginsUseCase, save: saveMarginsUseCase, agentId: agentId, canEdit: canEdit);

  /// The sub-agencies to pick from before editing margins; the picker screen owns it.
  MarginAgentsCubit createMarginAgentsCubit() => MarginAgentsCubit(getSubAgentsUseCase);

  TeamCubit createTeamCubit() => TeamCubit(teamUseCases);

  /// Builds the cubit of the notification-preferences screen; the screen owns it.
  NotificationPreferencesCubit createNotificationPreferencesCubit() =>
      NotificationPreferencesCubit(notificationPreferencesRepository);

  /// Builds the "notify me at launch" cubit of the coming-soon sheet; the sheet owns it.
  ServiceInterestCubit createServiceInterestCubit(String serviceKey) =>
      ServiceInterestCubit(serviceInterestRepository, serviceKey: serviceKey);

  /// Builds the cubit of the branches screen; the screen owns it.
  BranchesCubit createBranchesCubit() => BranchesCubit(branches: branchRepository, team: teamUseCases);

  /// Builds the "copy an earlier request" cubit of one service; the traveler form's link owns it.
  PrefillCubit createPrefillCubit(String serviceId) => PrefillCubit(
        candidates: GetPrefillCandidatesUseCase(prefillRepository),
        values: GetPrefillValuesUseCase(prefillRepository),
        serviceId: serviceId,
      );

  /// Builds the cubit of the manifest being built; the screen owns it.
  ManifestBuildCubit createManifestBuildCubit(String serviceId, String serviceLabel) =>
      ManifestBuildCubit(manifestRepository, PluginManifestImportPicker(), serviceId: serviceId, serviceLabel: serviceLabel);

  /// Builds the cubit of a sent manifest's summary; the screen owns it.
  ManifestSummaryCubit createManifestSummaryCubit(String manifestId) =>
      ManifestSummaryCubit(manifestRepository, launchExternalUrl, manifestId: manifestId);

  /// Builds the hospital picker's cubit for a medical service; the sheet owns it.
  HospitalPickerCubit createHospitalPickerCubit(String serviceId) =>
      HospitalPickerCubit(hospitalRepository, serviceId: serviceId);

  /// Builds the cubits of the change-password / change-phone screens; each screen owns its own.
  ChangePasswordCubit createChangePasswordCubit() =>
      ChangePasswordCubit(accountSecurityRepository, onChanged: authSessionController.notifyUnauthenticated);

  ChangePhoneCubit createChangePhoneCubit() => ChangePhoneCubit(accountSecurityRepository);

  EmailChangeCubit createEmailChangeCubit() => EmailChangeCubit(emailChangeRepository);

  TwoFactorStatusCubit createTwoFactorStatusCubit() => TwoFactorStatusCubit(twoFactorRepository);

  TwoFactorFlowCubit createTwoFactorFlowCubit(TwoFactorFlowMode mode) => TwoFactorFlowCubit(twoFactorRepository, mode: mode);

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
        onRead: unreadTicketsCubit.refresh,
      );

  PassportScanCubit createPassportScanCubit(List<String> fieldKeys) =>
      PassportScanCubit(reader: passportReaderRepository, picker: passportPhotoPicker, fieldKeys: fieldKeys);

  ReportResultCubit createReportResultCubit(ReportRequest request) => ReportResultCubit(reportsRepository, request);

  ReportExportCubit createReportExportCubit(ReportRequest request) => ReportExportCubit(reportsRepository, documentExporter, request);

  TicketRatingCubit createTicketRatingCubit(String ticketId) => TicketRatingCubit(ticketRatingRepository, ticketId: ticketId);

  TicketCategoriesCubit createTicketCategoriesCubit() => TicketCategoriesCubit(ticketCategoriesRepository);

  SupportBloc createSupportBloc() => SupportBloc(
        getTicketsUseCase: getTicketsUseCase,
        createTicketUseCase: createTicketUseCase,
        replyToTicketUseCase: replyToTicketUseCase,
        getTicketUseCase: getTicketUseCase,
      );

  /// The unread-notifications badge counter (polls while the app is in the
  /// foreground). The screen that shows the badge owns it.
  UnreadNotificationsCubit createUnreadNotificationsCubit() =>
      UnreadNotificationsCubit(getCount: getUnreadNotificationCountUseCase);

  /// Builds a fresh [NotificationsBloc]. The caller (the notifications
  /// screen's own `BlocProvider`) owns its lifetime from here on.
  NotificationsBloc createNotificationsBloc() => NotificationsBloc(
        getNotificationsUseCase: getNotificationsUseCase,
        markNotificationReadUseCase: markNotificationReadUseCase,
        markAllNotificationsReadUseCase: markAllNotificationsReadUseCase,
      );
}
