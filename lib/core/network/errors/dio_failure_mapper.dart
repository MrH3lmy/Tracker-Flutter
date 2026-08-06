import 'package:dio/dio.dart';

import '../../error/app_failure.dart';

/// Maps Dio's transport-level exceptions onto the shared [AppFailure]
/// taxonomy so features never depend on `DioException` directly.
///
/// [DioExceptionType.connectionError] maps to [NetworkFailure] here — it
/// only means the request itself couldn't reach the server, not that the
/// device has no network at all. Callers that want to distinguish "offline"
/// from "server unreachable" should cross-check a connectivity signal
/// before presenting [NetworkFailure] to the user (see `ApiClient`).
AppFailure mapDioExceptionToFailure(DioException exception) {
  switch (exception.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return TimeoutFailure(
        message: 'The request took too long. Please try again.',
        cause: exception,
      );

    case DioExceptionType.connectionError:
      return NetworkFailure(
        message: 'Could not reach the server. Please try again.',
        cause: exception,
      );

    case DioExceptionType.cancel:
      return CancelledFailure(cause: exception);

    case DioExceptionType.badCertificate:
      return NetworkFailure(
        message: 'A secure connection could not be established.',
        cause: exception,
      );

    case DioExceptionType.badResponse:
      return _mapResponse(exception);

    case DioExceptionType.unknown:
      return UnknownFailure(
        message: 'Something went wrong. Please try again.',
        cause: exception,
      );
  }
}

AppFailure _mapResponse(DioException exception) {
  final response = exception.response;
  final statusCode = response?.statusCode;

  switch (statusCode) {
    case 401:
      return UnauthorizedFailure(cause: exception);
    case 409:
      return ConflictFailure(
        message: _extractMessage(response),
        cause: exception,
      );
    case 400:
    case 422:
      return ValidationFailure(
        fieldErrors: _extractFieldErrors(response),
        message: _extractMessage(response),
        cause: exception,
      );
    case 429:
      return RateLimitedFailure(
        retryAfter: extractRetryAfter(response),
        cause: exception,
      );
  }

  if (statusCode != null && statusCode >= 500) {
    return ServerFailure(statusCode: statusCode, cause: exception);
  }

  return UnknownFailure(message: _extractMessage(response), cause: exception);
}

/// Reads a `Retry-After` header as a whole number of seconds. HTTP also
/// permits an HTTP-date form; that's not handled here since Tracker-BE has
/// not been observed sending one, but the value is simply ignored (not
/// misparsed) in that case.
Duration? extractRetryAfter(Response<dynamic>? response) {
  final raw = response?.headers.value('retry-after');
  if (raw == null) return null;
  final seconds = int.tryParse(raw.trim());
  if (seconds == null) return null;
  return Duration(seconds: seconds);
}

/// Best-effort extraction from a JSON error body — the exact Tracker-BE
/// error contract isn't fixed yet, so this degrades gracefully instead of
/// throwing when the shape doesn't match.
String? _extractMessage(Response<dynamic>? response) {
  final data = response?.data;
  if (data is Map && data['message'] is String) {
    return data['message'] as String;
  }
  return null;
}

Map<String, String> _extractFieldErrors(Response<dynamic>? response) {
  final data = response?.data;
  if (data is! Map) return const {};
  final errors = data['errors'];
  if (errors is! Map) return const {};

  final result = <String, String>{};
  for (final entry in errors.entries) {
    final key = entry.key;
    final value = entry.value;
    if (key is String && value is String) {
      result[key] = value;
    } else if (key is String && value is List && value.isNotEmpty) {
      result[key] = value.first.toString();
    }
  }
  return result;
}
