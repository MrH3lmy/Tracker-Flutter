import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/network/errors/dio_failure_mapper.dart';

RequestOptions _options() => RequestOptions(path: '/things');

DioException _badResponse({
  required int statusCode,
  Object? data,
  Map<String, List<String>> headers = const {},
}) {
  final options = _options();
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: statusCode,
      data: data,
      headers: Headers.fromMap(headers),
    ),
  );
}

void main() {
  group('mapDioExceptionToFailure', () {
    test('maps timeouts to TimeoutFailure', () {
      for (final type in [
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final failure = mapDioExceptionToFailure(
          DioException(requestOptions: _options(), type: type),
        );
        expect(failure, isA<TimeoutFailure>());
      }
    });

    test('maps connectionError to NetworkFailure', () {
      final failure = mapDioExceptionToFailure(
        DioException(
          requestOptions: _options(),
          type: DioExceptionType.connectionError,
        ),
      );
      expect(failure, isA<NetworkFailure>());
    });

    test('maps cancel to CancelledFailure', () {
      final failure = mapDioExceptionToFailure(
        DioException(requestOptions: _options(), type: DioExceptionType.cancel),
      );
      expect(failure, isA<CancelledFailure>());
    });

    test('maps 401 to UnauthorizedFailure', () {
      final failure = mapDioExceptionToFailure(_badResponse(statusCode: 401));
      expect(failure, isA<UnauthorizedFailure>());
    });

    test('maps 409 to ConflictFailure with a message', () {
      final failure = mapDioExceptionToFailure(
        _badResponse(
          statusCode: 409,
          data: {'message': 'Task was already archived'},
        ),
      );
      expect(failure, isA<ConflictFailure>());
      expect(failure.message, 'Task was already archived');
    });

    test('maps 422 to ValidationFailure with field errors', () {
      final failure = mapDioExceptionToFailure(
        _badResponse(
          statusCode: 422,
          data: {
            'message': 'Validation failed',
            'errors': {
              'title': 'must not be blank',
              'dueDate': ['must be in the future'],
            },
          },
        ),
      );
      expect(failure, isA<ValidationFailure>());
      final validation = failure as ValidationFailure;
      expect(validation.fieldErrors['title'], 'must not be blank');
      expect(validation.fieldErrors['dueDate'], 'must be in the future');
    });

    test('maps 429 to RateLimitedFailure with retryAfter', () {
      final failure = mapDioExceptionToFailure(
        _badResponse(
          statusCode: 429,
          headers: {
            'retry-after': ['30'],
          },
        ),
      );
      expect(failure, isA<RateLimitedFailure>());
      expect(
        (failure as RateLimitedFailure).retryAfter,
        const Duration(seconds: 30),
      );
    });

    test('maps 5xx to ServerFailure with the status code', () {
      final failure = mapDioExceptionToFailure(_badResponse(statusCode: 503));
      expect(failure, isA<ServerFailure>());
      expect((failure as ServerFailure).statusCode, 503);
    });

    test('maps an unmapped status to UnknownFailure without throwing', () {
      final failure = mapDioExceptionToFailure(_badResponse(statusCode: 418));
      expect(failure, isA<UnknownFailure>());
    });

    test('degrades gracefully when the error body has an unexpected shape', () {
      final failure = mapDioExceptionToFailure(
        _badResponse(statusCode: 422, data: 'not a map'),
      );
      expect(failure, isA<ValidationFailure>());
      expect((failure as ValidationFailure).fieldErrors, isEmpty);
    });
  });
}
