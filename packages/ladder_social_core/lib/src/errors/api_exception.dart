import 'package:dio/dio.dart';

final class ApiException implements Exception {
  const ApiException({
    required this.message,
    this.statusCode,
    this.traceId,
    this.validationErrors = const <String, List<String>>{},
  });

  factory ApiException.from(Object error) {
    if (error is ApiException) {
      return error;
    }

    if (error is DioException) {
      if (error.error is ApiException) {
        return error.error! as ApiException;
      }

      final Object? data = error.response?.data;
      if (data is Map<dynamic, dynamic>) {
        final Map<String, dynamic> json = Map<String, dynamic>.from(data);
        return ApiException(
          message: (json['detail'] ?? json['title'] ?? 'Request failed')
              .toString(),
          statusCode: error.response?.statusCode,
          traceId: json['traceId']?.toString(),
          validationErrors: _parseErrors(json['errors']),
        );
      }

      return ApiException(
        message: error.message ?? 'The server could not be reached.',
        statusCode: error.response?.statusCode,
      );
    }

    return ApiException(message: error.toString());
  }

  final String message;
  final int? statusCode;
  final String? traceId;
  final Map<String, List<String>> validationErrors;

  String? validationMessage(String field) {
    final String normalizedField = field.toLowerCase();
    for (final MapEntry<String, List<String>> entry
        in validationErrors.entries) {
      if (entry.key.toLowerCase() == normalizedField && entry.value.isNotEmpty) {
        return entry.value.join('\n');
      }
    }
    return null;
  }

  @override
  String toString() => message;

  static Map<String, List<String>> _parseErrors(Object? rawErrors) {
    if (rawErrors is! Map<dynamic, dynamic>) {
      return const <String, List<String>>{};
    }

    return Map<String, List<String>>.unmodifiable(
      rawErrors.map<String, List<String>>(
        (dynamic key, dynamic value) => MapEntry<String, List<String>>(
          key.toString(),
          value is List<dynamic>
              ? List<String>.unmodifiable(
                  value.map((dynamic item) => item.toString()),
                )
              : <String>[value.toString()],
        ),
      ),
    );
  }
}
