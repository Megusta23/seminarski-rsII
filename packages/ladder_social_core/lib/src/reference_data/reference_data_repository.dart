import 'package:ladder_social_core/src/reference_data/reference_data_api_service.dart';
import 'package:ladder_social_core/src/reference_data/reference_data_models.dart';

final class ReferenceDataRepository {
  const ReferenceDataRepository(this._apiService);

  final ReferenceDataApiService _apiService;

  Future<List<CountryItem>> getCountries({
    String? search,
    int page = 1,
    int pageSize = 100,
  }) =>
      _apiService.getCountries(
        search: search,
        page: page,
        pageSize: pageSize,
      );

  Future<List<CityItem>> getCities({
    String? countryId,
    String? search,
    int page = 1,
    int pageSize = 100,
  }) =>
      _apiService.getCities(
        countryId: countryId,
        search: search,
        page: page,
        pageSize: pageSize,
      );

  Future<List<ReferenceItem>> getTaskCategories({
    String? search,
    int page = 1,
    int pageSize = 100,
  }) =>
      _apiService.getTaskCategories(
        search: search,
        page: page,
        pageSize: pageSize,
      );

  Future<List<ReferenceItem>> getRecurrenceTypes({
    String? search,
    int page = 1,
    int pageSize = 100,
  }) =>
      _apiService.getRecurrenceTypes(
        search: search,
        page: page,
        pageSize: pageSize,
      );
}
