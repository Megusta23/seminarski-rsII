import 'package:ladder_social_core/src/reference_data/reference_data_api_service.dart';
import 'package:ladder_social_core/src/reference_data/reference_data_models.dart';

final class ReferenceDataRepository {
  const ReferenceDataRepository(this._apiService);

  final ReferenceDataApiService _apiService;

  Future<List<CountryItem>> getCountries() => _apiService.getCountries();

  Future<List<CityItem>> getCities({String? countryId}) =>
      _apiService.getCities(countryId: countryId);

  Future<List<ReferenceItem>> getTaskCategories() =>
      _apiService.getTaskCategories();

  Future<List<ReferenceItem>> getRecurrenceTypes() =>
      _apiService.getRecurrenceTypes();
}
