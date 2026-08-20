import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/network/api_client.dart';

final class MediaRepository {
  const MediaRepository(this._client);
  final ApiClient _client;

  String absoluteUrl(String relativePath) => _client.absoluteUrl(relativePath);

  Future<Uint8List> loadBytes(String relativePath) async {
    try {
      final Response<List<int>> response = await _client.dio.get<List<int>>(
        relativePath,
        options: Options(responseType: ResponseType.bytes),
      );
      final List<int>? data = response.data;
      if (data == null) {
        throw const FormatException('The media response was empty.');
      }
      return Uint8List.fromList(data);
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }
}
