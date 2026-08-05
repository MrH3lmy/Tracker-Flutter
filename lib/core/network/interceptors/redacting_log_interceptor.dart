import 'package:dio/dio.dart';

import '../../logging/app_logger.dart';

/// Logs request/response lines through [AppLogger] (which redacts
/// credentials) and never logs raw bodies unless [logBodies] is true —
/// callers should only pass `true` outside production. Even then, request
/// bodies are stringified defensively so file/attachment bytes in
/// [FormData] are represented by field names only, never their content.
class RedactingLogInterceptor extends Interceptor {
  RedactingLogInterceptor(this._logger, {required this.logBodies});

  final AppLogger _logger;
  final bool logBodies;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final headers = options.headers.isEmpty
        ? ''
        : '\n  headers: ${AppLogger.redact(options.headers.toString())}';
    final body = logBodies && options.data != null
        ? '\n  body: ${AppLogger.redact(_describe(options.data))}'
        : '';
    _logger.debug('--> ${options.method} ${options.uri}$headers$body');
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    _logger.debug(
      '<-- ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _logger.warning(
      'xxx ${err.requestOptions.method} ${err.requestOptions.uri} failed: '
      '${err.type.name}'
      '${err.response?.statusCode != null ? ' (${err.response?.statusCode})' : ''}',
      err,
      err.stackTrace,
    );
    handler.next(err);
  }

  static String _describe(Object? data) {
    if (data is FormData) {
      final fields = data.fields.map((e) => e.key).join(', ');
      final files = data.files.map((e) => e.key).join(', ');
      return 'FormData(fields: [$fields], files: [$files])';
    }
    if (data is Map ||
        data is List ||
        data is String ||
        data is num ||
        data is bool) {
      return data.toString();
    }
    return '<${data.runtimeType}>';
  }
}
