import 'package:dio/dio.dart';

import '../error/app_failure.dart';
import '../result/result.dart';
import 'connectivity/connectivity_service.dart';
import 'errors/dio_failure_mapper.dart';
import 'pagination/page_meta.dart';
import 'pagination/paginated_result.dart';
import 'request_policy.dart';

/// Result-returning wrapper around [Dio] — the only thing feature
/// repositories should depend on. Nothing here throws; every failure comes
/// back as a [Result.failure] carrying an [AppFailure].
class ApiClient {
  ApiClient(this._dio, this._connectivity);

  final Dio _dio;
  final ConnectivityService _connectivity;

  Future<Result<T>> get<T>(
    String path, {
    required T Function(dynamic data) decode,
    Map<String, dynamic>? queryParameters,
    RequestPolicy policy = const RequestPolicy(idempotent: true),
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.get<dynamic>(
      path,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: policy.toOptions(),
    ),
    decode,
  );

  Future<Result<T>> post<T>(
    String path, {
    required T Function(dynamic data) decode,
    Object? data,
    Map<String, dynamic>? queryParameters,
    RequestPolicy policy = const RequestPolicy(),
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.post<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: policy.toOptions(),
    ),
    decode,
  );

  Future<Result<T>> put<T>(
    String path, {
    required T Function(dynamic data) decode,
    Object? data,
    Map<String, dynamic>? queryParameters,
    RequestPolicy policy = const RequestPolicy(idempotent: true),
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.put<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: policy.toOptions(),
    ),
    decode,
  );

  Future<Result<T>> patch<T>(
    String path, {
    required T Function(dynamic data) decode,
    Object? data,
    Map<String, dynamic>? queryParameters,
    RequestPolicy policy = const RequestPolicy(),
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.patch<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: policy.toOptions(),
    ),
    decode,
  );

  Future<Result<T>> delete<T>(
    String path, {
    required T Function(dynamic data) decode,
    Object? data,
    Map<String, dynamic>? queryParameters,
    RequestPolicy policy = const RequestPolicy(idempotent: true),
    CancelToken? cancelToken,
  }) => _send(
    () => _dio.delete<dynamic>(
      path,
      data: data,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
      options: policy.toOptions(),
    ),
    decode,
  );

  /// Fetches one bounded page and parses Tracker-BE's pagination headers —
  /// there is no "load everything" path by design.
  Future<Result<PaginatedResult<T>>> getPaginated<T>(
    String path, {
    required T Function(dynamic item) decodeItem,
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        cancelToken: cancelToken,
        options: const RequestPolicy(idempotent: true).toOptions(),
      );
      final raw = response.data;
      final items = (raw is List ? raw : const <dynamic>[])
          .map(decodeItem)
          .toList(growable: false);
      final meta = PageMeta.fromHeaders(response.headers);
      return Result.success(PaginatedResult(items: items, meta: meta));
    } on DioException catch (exception) {
      return Result.failure(await _mapFailure(exception));
    } catch (exception) {
      return Result.failure(UnknownFailure(cause: exception));
    }
  }

  Future<Result<T>> _send<T>(
    Future<Response<dynamic>> Function() send,
    T Function(dynamic data) decode,
  ) async {
    try {
      final response = await send();
      return Result.success(decode(response.data));
    } on DioException catch (exception) {
      return Result.failure(await _mapFailure(exception));
    } catch (exception) {
      return Result.failure(UnknownFailure(cause: exception));
    }
  }

  /// Refines a connection error using an actual connectivity signal instead
  /// of assuming: no network interface at all -> [OfflineFailure]; an
  /// interface is up but the request still failed -> the mapper's
  /// [NetworkFailure] (the server, not the device, is the likely problem).
  Future<AppFailure> _mapFailure(DioException exception) async {
    if (exception.type == DioExceptionType.connectionError) {
      final hasNetwork = await _connectivity.hasNetworkPresence;
      if (!hasNetwork) {
        return OfflineFailure(
          message: "You're offline. Check your connection and try again.",
          cause: exception,
        );
      }
    }
    return mapDioExceptionToFailure(exception);
  }
}
