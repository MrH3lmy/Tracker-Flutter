import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A scriptable [HttpClientAdapter] so interceptor/client tests exercise
/// real `Dio` request/response plumbing without touching the network.
class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this.handler);

  final ResponseBody Function(RequestOptions options, int callNumber) handler;

  int callCount = 0;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    callCount++;
    requests.add(options);
    return handler(options, callCount);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonResponseBody(
  Object? data, {
  int statusCode = 200,
  Map<String, List<String>> headers = const {},
}) {
  final bytes = utf8.encode(data == null ? '' : jsonEncode(data));
  return ResponseBody.fromBytes(
    bytes,
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
      ...headers,
    },
  );
}
