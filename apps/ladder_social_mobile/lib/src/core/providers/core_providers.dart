import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_core/ladder_social_core.dart';
import 'package:ladder_social_mobile/src/features/auth/application/auth_controller.dart';
import 'package:ladder_social_mobile/src/features/auth/application/auth_state.dart';

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (Ref ref) => TokenStore(),
);

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  final ApiClient client = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokenStore: ref.watch(tokenStoreProvider),
  );
  client.setUnauthorizedHandler(
    () => ref.read(mobileAuthControllerProvider.notifier).handleUnauthorized(),
  );
  return client;
});

final Provider<AuthApiService> authApiServiceProvider =
    Provider<AuthApiService>(
  (Ref ref) => AuthApiService(ref.watch(apiClientProvider)),
);

final Provider<AuthRepository> authRepositoryProvider =
    Provider<AuthRepository>(
  (Ref ref) => AuthRepository(
    apiService: ref.watch(authApiServiceProvider),
    tokenStore: ref.watch(tokenStoreProvider),
  ),
);

final Provider<ReferenceDataApiService> referenceDataApiServiceProvider =
    Provider<ReferenceDataApiService>(
  (Ref ref) => ReferenceDataApiService(ref.watch(apiClientProvider)),
);

final Provider<ReferenceDataRepository> referenceDataRepositoryProvider =
    Provider<ReferenceDataRepository>(
  (Ref ref) => ReferenceDataRepository(
    ref.watch(referenceDataApiServiceProvider),
  ),
);

final Provider<TaskRepository> taskRepositoryProvider = Provider<TaskRepository>(
  (Ref ref) => TaskRepository(TaskApiService(ref.watch(apiClientProvider))),
);
final Provider<FeedRepository> feedRepositoryProvider = Provider<FeedRepository>(
  (Ref ref) => FeedRepository(ref.watch(apiClientProvider)),
);
final Provider<FriendRepository> friendRepositoryProvider =
    Provider<FriendRepository>(
  (Ref ref) => FriendRepository(ref.watch(apiClientProvider)),
);
final Provider<LeaderboardRepository> leaderboardRepositoryProvider =
    Provider<LeaderboardRepository>(
  (Ref ref) => LeaderboardRepository(ref.watch(apiClientProvider)),
);
final Provider<NotificationRepository> notificationRepositoryProvider =
    Provider<NotificationRepository>(
  (Ref ref) => NotificationRepository(ref.watch(apiClientProvider)),
);
final Provider<ChatRepository> chatRepositoryProvider = Provider<ChatRepository>(
  (Ref ref) => ChatRepository(ref.watch(apiClientProvider)),
);
final Provider<MediaRepository> mediaRepositoryProvider =
    Provider<MediaRepository>(
  (Ref ref) => MediaRepository(ref.watch(apiClientProvider)),
);

final StateNotifierProvider<MobileAuthController, MobileAuthState>
    mobileAuthControllerProvider =
    StateNotifierProvider<MobileAuthController, MobileAuthState>(
  (Ref ref) => MobileAuthController(ref.watch(authRepositoryProvider)),
);

void _requireAuthenticated(Ref ref) {
  final String? userId = ref.watch(
    mobileAuthControllerProvider.select(
      (MobileAuthState state) => state.session?.userId,
    ),
  );
  if (userId == null) {
    throw const ApiException(message: 'Authentication is required.');
  }
}

final AutoDisposeFutureProvider<CurrentProfile> currentProfileProvider =
    FutureProvider.autoDispose<CurrentProfile>((Ref ref) async {
  _requireAuthenticated(ref);
  return ref.watch(authRepositoryProvider).getCurrentProfile();
});

final AutoDisposeFutureProvider<List<CountryItem>> countriesProvider =
    FutureProvider.autoDispose<List<CountryItem>>((Ref ref) async {
  _requireAuthenticated(ref);
  return ref.watch(referenceDataRepositoryProvider).getCountries();
});

final AutoDisposeFutureProvider<List<CityItem>> citiesProvider =
    FutureProvider.autoDispose<List<CityItem>>((Ref ref) async {
  _requireAuthenticated(ref);
  return ref.watch(referenceDataRepositoryProvider).getCities();
});

final AutoDisposeFutureProvider<List<ReferenceItem>> taskCategoriesProvider =
    FutureProvider.autoDispose<List<ReferenceItem>>((Ref ref) async {
  _requireAuthenticated(ref);
  return ref.watch(referenceDataRepositoryProvider).getTaskCategories();
});

final AutoDisposeFutureProvider<List<ReferenceItem>> recurrenceTypesProvider =
    FutureProvider.autoDispose<List<ReferenceItem>>((Ref ref) async {
  _requireAuthenticated(ref);
  return ref.watch(referenceDataRepositoryProvider).getRecurrenceTypes();
});

final AutoDisposeFutureProvider<NotificationSummary> notificationSummaryProvider =
    FutureProvider.autoDispose<NotificationSummary>((Ref ref) async {
  _requireAuthenticated(ref);
  return ref.watch(notificationRepositoryProvider).getSummary();
});
