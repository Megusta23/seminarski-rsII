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

final StateNotifierProvider<MobileAuthController, MobileAuthState>
    mobileAuthControllerProvider =
    StateNotifierProvider<MobileAuthController, MobileAuthState>(
  (Ref ref) => MobileAuthController(ref.watch(authRepositoryProvider)),
);

final AutoDisposeFutureProvider<CurrentProfile> currentProfileProvider =
    FutureProvider.autoDispose<CurrentProfile>((Ref ref) async {
  final String? userId = ref.watch(
    mobileAuthControllerProvider.select(
      (MobileAuthState state) => state.session?.userId,
    ),
  );

  if (userId == null) {
    throw const ApiException(message: 'Authentication is required.');
  }

  return ref.watch(authRepositoryProvider).getCurrentProfile();
});

final AutoDisposeFutureProvider<List<CityItem>> citiesProvider =
    FutureProvider.autoDispose<List<CityItem>>((Ref ref) async {
  final String? userId = ref.watch(
    mobileAuthControllerProvider.select(
      (MobileAuthState state) => state.session?.userId,
    ),
  );

  if (userId == null) {
    throw const ApiException(message: 'Authentication is required.');
  }

  return ref.watch(referenceDataRepositoryProvider).getCities();
});
