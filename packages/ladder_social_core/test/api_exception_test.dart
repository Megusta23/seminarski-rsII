import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ladder_social_core/ladder_social_core.dart';

void main() {
  test('ApiException reads ProblemDetails and field errors', () {
    final RequestOptions request = RequestOptions(path: '/api/auth/register');
    final DioException error = DioException(
      requestOptions: request,
      response: Response<dynamic>(
        requestOptions: request,
        statusCode: 400,
        data: <String, dynamic>{
          'title': 'Validation failed',
          'detail': 'One or more authentication fields are invalid.',
          'traceId': 'trace-123',
          'errors': <String, dynamic>{
            'email': <String>['Enter a valid email address.'],
          },
        },
      ),
      type: DioExceptionType.badResponse,
    );

    final ApiException exception = ApiException.from(error);

    expect(exception.statusCode, 400);
    expect(exception.traceId, 'trace-123');
    expect(
      exception.validationMessage('Email'),
      'Enter a valid email address.',
    );
  });

  test('ApiException preserves an exception already attached by ApiClient', () {
    const ApiException attached = ApiException(
      message: 'Session expired.',
      statusCode: 401,
    );
    final RequestOptions request = RequestOptions(path: '/api/profile/me');
    final DioException error = DioException(
      requestOptions: request,
      error: attached,
      type: DioExceptionType.unknown,
    );

    expect(ApiException.from(error), same(attached));
  });
}
