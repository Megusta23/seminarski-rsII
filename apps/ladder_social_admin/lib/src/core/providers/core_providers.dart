import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ladder_social_admin/src/features/auth/application/admin_auth_controller.dart';
import 'package:ladder_social_admin/src/features/auth/application/admin_auth_state.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

final Provider<TokenStore> tokenStoreProvider = Provider<TokenStore>(
  (Ref ref) => TokenStore(),
);

final Provider<ApiClient> apiClientProvider = Provider<ApiClient>((Ref ref) {
  final ApiClient client = ApiClient(
    baseUrl: AppConfig.apiBaseUrl,
    tokenStore: ref.watch(tokenStoreProvider),
  );
  client.setUnauthorizedHandler(
    () => ref.read(adminAuthControllerProvider.notifier).handleUnauthorized(),
  );
  return client;
});

final Provider<AuthApiService> authApiServiceProvider = Provider<AuthApiService>(
  (Ref ref) => AuthApiService(ref.watch(apiClientProvider)),
);
final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>(
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
  (Ref ref) => ReferenceDataRepository(ref.watch(referenceDataApiServiceProvider)),
);
final Provider<AdminRepository> adminRepositoryProvider = Provider<AdminRepository>(
  (Ref ref) => AdminRepository(ref.watch(apiClientProvider)),
);
final Provider<MediaRepository> mediaRepositoryProvider = Provider<MediaRepository>(
  (Ref ref) => MediaRepository(ref.watch(apiClientProvider)),
);

final StateNotifierProvider<AdminAuthController, AdminAuthState>
    adminAuthControllerProvider =
    StateNotifierProvider<AdminAuthController, AdminAuthState>(
  (Ref ref) => AdminAuthController(ref.watch(authRepositoryProvider)),
);

void _requireAdmin(Ref ref) {
  final String? userId = ref.watch(
    adminAuthControllerProvider.select(
      (AdminAuthState state) => state.session?.userId,
    ),
  );
  if (userId == null) {
    throw const ApiException(message: 'Administrator authentication is required.');
  }
}

final AutoDisposeFutureProvider<CurrentProfile> adminProfileProvider =
    FutureProvider.autoDispose<CurrentProfile>((Ref ref) async {
  _requireAdmin(ref);
  return ref.watch(authRepositoryProvider).getCurrentProfile();
});

final AutoDisposeFutureProvider<AdminAccessResult> adminAccessProvider =
    FutureProvider.autoDispose<AdminAccessResult>((Ref ref) async {
  _requireAdmin(ref);
  return ref.watch(authRepositoryProvider).checkAdminAccess();
});

final AutoDisposeFutureProvider<List<CountryItem>> adminCountryOptionsProvider =
    FutureProvider.autoDispose<List<CountryItem>>((Ref ref) async {
  _requireAdmin(ref);
  return ref.watch(referenceDataRepositoryProvider).getCountries();
});
