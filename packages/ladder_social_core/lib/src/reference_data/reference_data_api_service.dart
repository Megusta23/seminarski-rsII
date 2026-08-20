import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/network/api_client.dart';
import 'package:ladder_social_core/src/reference_data/reference_data_models.dart';

final class ReferenceDataApiService {
  const ReferenceDataApiService(this._apiClient);

  final ApiClient _apiClient;

  Future<List<CountryItem>> getCountries() => _getList<CountryItem>(
        '/api/reference-data/countries',
        CountryItem.fromJson,
      );

  Future<List<CityItem>> getCities({String? countryId}) => _getList<CityItem>(
        '/api/reference-data/cities',
        CityItem.fromJson,
        queryParameters: <String, dynamic>{
          if (countryId != null) 'countryId': countryId,
        },
      );

  Future<List<ReferenceItem>> getTaskCategories() => _getList<ReferenceItem>(
        '/api/reference-data/task-categories',
        ReferenceItem.fromJson,
      );

  Future<List<ReferenceItem>> getRecurrenceTypes() => _getList<ReferenceItem>(
        '/api/reference-data/recurrence-types',
        ReferenceItem.fromJson,
      );

  Future<List<T>> _getList<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final Response<dynamic> response = await _apiClient.dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
      );
      final Object? data = response.data;
      if (data is! List<dynamic>) {
        throw const FormatException('The server returned an invalid JSON list.');
      }

      return List<T>.unmodifiable(
        data.map<T>((dynamic item) {
          if (item is! Map<dynamic, dynamic>) {
            throw const FormatException(
              'A reference-data item has an invalid JSON format.',
            );
          }
          return fromJson(Map<String, dynamic>.from(item));
        }),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }
}
