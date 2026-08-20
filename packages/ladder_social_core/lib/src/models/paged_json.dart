import 'package:ladder_social_core/src/models/json_helpers.dart';
import 'package:ladder_social_core/src/models/paged_result.dart';

PagedResult<T> parsePagedResult<T>(
  Object? data,
  T Function(Map<String, dynamic>) fromJson,
) {
  final Map<String, dynamic> json = jsonMap(data, context: 'paged response');
  return PagedResult<T>(
    items: List<T>.unmodifiable(
      jsonList(json['items'], context: 'paged items')
          .map((Object? item) => fromJson(jsonMap(item, context: 'paged item'))),
    ),
    page: requiredInt(json, 'page'),
    pageSize: requiredInt(json, 'pageSize'),
    totalCount: requiredInt(json, 'totalCount'),
    totalPages: requiredInt(json, 'totalPages'),
  );
}
