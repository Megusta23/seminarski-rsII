import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/admin/admin_models.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';
import 'package:ladder_social_core/src/models/paged_json.dart';
import 'package:ladder_social_core/src/models/paged_result.dart';
import 'package:ladder_social_core/src/network/api_client.dart';

final class AdminRepository {
  const AdminRepository(this._client);
  final ApiClient _client;

  Future<AdminDashboard> getDashboard() =>
      _getOne('/api/admin/dashboard', AdminDashboard.fromJson);

  Future<PagedResult<AdminUserItem>> getUsers({
    String? search,
    bool? isActive,
    String? cityId,
    int page = 1,
    int pageSize = 20,
  }) => _getPage(
        '/api/admin/users',
        AdminUserItem.fromJson,
        query: <String, dynamic>{
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (isActive != null) 'isActive': isActive,
          if (cityId != null) 'cityId': cityId,
          'page': page,
          'pageSize': pageSize,
        },
      );

  Future<AdminUserDetail> getUser(String id) =>
      _getOne('/api/admin/users/$id', AdminUserDetail.fromJson);

  Future<void> setUserActive(String id, bool isActive) =>
      _put('/api/admin/users/$id/active', <String, dynamic>{'isActive': isActive});

  Future<PagedResult<AdminPostItem>> getPosts({
    String? search,
    bool? isVisible,
    int page = 1,
    int pageSize = 20,
  }) => _getPage(
        '/api/admin/posts',
        AdminPostItem.fromJson,
        query: <String, dynamic>{
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (isVisible != null) 'isVisible': isVisible,
          'page': page,
          'pageSize': pageSize,
        },
      );

  Future<void> setPostVisibility(String id, bool isVisible) => _put(
        '/api/admin/posts/$id/visibility',
        <String, dynamic>{'isVisible': isVisible},
      );

  Future<PagedResult<AdminCountry>> getCountries({
    String? search,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) => _referencePage(
        'countries',
        AdminCountry.fromJson,
        search: search,
        isActive: isActive,
        page: page,
        pageSize: pageSize,
      );

  Future<AdminCountry> createCountry({
    required String name,
    required String isoCode,
    int sortOrder = 0,
  }) => _postOne(
        '/api/admin/reference-data/countries',
        <String, dynamic>{
          'name': name.trim(),
          'isoCode': isoCode.trim(),
          'sortOrder': sortOrder,
        },
        AdminCountry.fromJson,
      );

  Future<AdminCountry> updateCountry(AdminCountry item) => _putOne(
        '/api/admin/reference-data/countries/${item.id}',
        <String, dynamic>{
          'name': item.name.trim(),
          'isoCode': item.isoCode.trim(),
          'isActive': item.isActive,
          'sortOrder': item.sortOrder,
        },
        AdminCountry.fromJson,
      );

  Future<void> deactivateCountry(String id) =>
      _delete('/api/admin/reference-data/countries/$id');

  Future<PagedResult<AdminCity>> getCities({
    String? search,
    bool? isActive,
    String? countryId,
    int page = 1,
    int pageSize = 20,
  }) => _referencePage(
        'cities',
        AdminCity.fromJson,
        search: search,
        isActive: isActive,
        countryId: countryId,
        page: page,
        pageSize: pageSize,
      );

  Future<AdminCity> createCity({
    required String name,
    required String countryId,
    int sortOrder = 0,
  }) => _postOne(
        '/api/admin/reference-data/cities',
        <String, dynamic>{
          'name': name.trim(),
          'countryId': countryId,
          'sortOrder': sortOrder,
        },
        AdminCity.fromJson,
      );

  Future<AdminCity> updateCity(AdminCity item) => _putOne(
        '/api/admin/reference-data/cities/${item.id}',
        <String, dynamic>{
          'name': item.name.trim(),
          'countryId': item.countryId,
          'isActive': item.isActive,
          'sortOrder': item.sortOrder,
        },
        AdminCity.fromJson,
      );

  Future<void> deactivateCity(String id) =>
      _delete('/api/admin/reference-data/cities/$id');

  Future<PagedResult<AdminReferenceItem>> getTaskCategories({
    String? search,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) => _referencePage(
        'task-categories',
        AdminReferenceItem.fromJson,
        search: search,
        isActive: isActive,
        page: page,
        pageSize: pageSize,
      );

  Future<PagedResult<AdminReferenceItem>> getRecurrenceTypes({
    String? search,
    bool? isActive,
    int page = 1,
    int pageSize = 20,
  }) => _referencePage(
        'recurrence-types',
        AdminReferenceItem.fromJson,
        search: search,
        isActive: isActive,
        page: page,
        pageSize: pageSize,
      );

  Future<AdminReferenceItem> createReferenceItem({
    required String resource,
    required String name,
    required String code,
    int sortOrder = 0,
  }) => _postOne(
        '/api/admin/reference-data/$resource',
        <String, dynamic>{
          'name': name.trim(),
          'code': code.trim(),
          'sortOrder': sortOrder,
        },
        AdminReferenceItem.fromJson,
      );

  Future<AdminReferenceItem> updateReferenceItem({
    required String resource,
    required AdminReferenceItem item,
  }) => _putOne(
        '/api/admin/reference-data/$resource/${item.id}',
        <String, dynamic>{
          'name': item.name.trim(),
          'code': item.code.trim(),
          'isActive': item.isActive,
          'sortOrder': item.sortOrder,
        },
        AdminReferenceItem.fromJson,
      );

  Future<void> deactivateReferenceItem(String resource, String id) =>
      _delete('/api/admin/reference-data/$resource/$id');

  Future<DownloadedFile> downloadActivityReport({
    required DateTime fromDate,
    required DateTime toDate,
  }) => _download(
        '/api/admin/reports/activity',
        query: <String, dynamic>{
          'fromDate': dateOnlyString(fromDate),
          'toDate': dateOnlyString(toDate),
        },
        fallbackName:
            'ladder-social-activity-${dateOnlyString(fromDate)}-${dateOnlyString(toDate)}.pdf',
      );

  Future<DownloadedFile> downloadUserReport(String userId) => _download(
        '/api/admin/reports/users/$userId',
        fallbackName: 'ladder-social-user-$userId.pdf',
      );

  Future<T> _getOne<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(path);
      return fromJson(jsonMap(response.data));
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<PagedResult<T>> _getPage<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson, {
    required Map<String, dynamic> query,
  }) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        path,
        queryParameters: query,
      );
      return parsePagedResult(response.data, fromJson);
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<PagedResult<T>> _referencePage<T>(
    String resource,
    T Function(Map<String, dynamic>) fromJson, {
    String? search,
    bool? isActive,
    String? countryId,
    int page = 1,
    int pageSize = 20,
  }) => _getPage(
        '/api/admin/reference-data/$resource',
        fromJson,
        query: <String, dynamic>{
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          if (isActive != null) 'isActive': isActive,
          if (countryId != null) 'countryId': countryId,
          'page': page,
          'pageSize': pageSize,
        },
      );

  Future<T> _postOne<T>(
    String path,
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final Response<dynamic> response = await _client.dio.post<dynamic>(
        path,
        data: data,
      );
      return fromJson(jsonMap(response.data));
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<T> _putOne<T>(
    String path,
    Map<String, dynamic> data,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final Response<dynamic> response = await _client.dio.put<dynamic>(
        path,
        data: data,
      );
      return fromJson(jsonMap(response.data));
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }

  Future<void> _put(String path, Map<String, dynamic> data) async {
    try {
      await _client.dio.put<void>(path, data: data);
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<void> _delete(String path) async {
    try {
      await _client.dio.delete<void>(path);
    } on DioException catch (error) {
      throw ApiException.from(error);
    }
  }

  Future<DownloadedFile> _download(
    String path, {
    Map<String, dynamic>? query,
    required String fallbackName,
  }) async {
    try {
      final Response<List<int>> response = await _client.dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );
      final List<int>? data = response.data;
      if (data == null) {
        throw const FormatException('The report response was empty.');
      }
      final Headers headers = response.headers;
      final String contentDisposition = headers.value('content-disposition') ?? '';
      final RegExpMatch? fileNameMatch =
          RegExp(r'''filename\*?=(?:UTF-8'')?"?([^";]+)''').firstMatch(contentDisposition);
      return DownloadedFile(
        bytes: Uint8List.fromList(data),
        fileName: Uri.decodeComponent(fileNameMatch?.group(1) ?? fallbackName),
        contentType: headers.value('content-type') ?? 'application/pdf',
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }
}
