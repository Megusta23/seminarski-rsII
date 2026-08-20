import 'package:dio/dio.dart';
import 'package:ladder_social_core/src/errors/api_exception.dart';
import 'package:ladder_social_core/src/leaderboard/leaderboard_models.dart';
import 'package:ladder_social_core/src/models/json_helpers.dart';
import 'package:ladder_social_core/src/network/api_client.dart';

final class LeaderboardRepository {
  const LeaderboardRepository(this._client);
  final ApiClient _client;

  Future<LeaderboardResult> getDaily({DateTime? date}) =>
      _get('/api/leaderboard/daily', 'date', date);

  Future<LeaderboardResult> getWeekly({DateTime? weekContaining}) =>
      _get('/api/leaderboard/weekly', 'weekContaining', weekContaining);

  Future<LeaderboardResult> _get(
    String path,
    String parameter,
    DateTime? value,
  ) async {
    try {
      final Response<dynamic> response = await _client.dio.get<dynamic>(
        path,
        queryParameters: <String, dynamic>{
          if (value != null) parameter: dateOnlyString(value),
        },
      );
      return LeaderboardResult.fromJson(
        jsonMap(response.data, context: 'leaderboard'),
      );
    } on DioException catch (error) {
      throw ApiException.from(error);
    } on FormatException catch (error) {
      throw ApiException(message: error.message);
    }
  }
}
