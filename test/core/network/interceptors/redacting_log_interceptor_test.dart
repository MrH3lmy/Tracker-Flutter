import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart' as pkg;
import 'package:tracker_flutter/core/logging/app_logger.dart';
import 'package:tracker_flutter/core/network/interceptors/redacting_log_interceptor.dart';

import '../../../helpers/fake_http_client_adapter.dart';

void main() {
  late List<pkg.LogRecord> records;
  late StreamSubscription<pkg.LogRecord> subscription;

  setUp(() {
    records = [];
    pkg.Logger.root.level = pkg.Level.ALL;
    subscription = pkg.Logger.root.onRecord.listen(records.add);
  });

  tearDown(() => subscription.cancel());

  String loggedText() => records.map((r) => r.message).join('\n');

  Dio buildDio(FakeHttpClientAdapter adapter, {required bool logBodies}) {
    late Dio dio;
    dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = adapter
      ..interceptors.add(
        RedactingLogInterceptor(
          AppLogger('test-network'),
          logBodies: logBodies,
        ),
      );
    return dio;
  }

  test('never logs an Authorization header value', () async {
    final adapter = FakeHttpClientAdapter(
      (options, call) => jsonResponseBody({'ok': true}),
    );
    final dio = buildDio(adapter, logBodies: true);

    await dio.get<dynamic>(
      '/tasks',
      options: Options(headers: {'Authorization': 'Bearer super-secret'}),
    );

    final logged = loggedText();
    expect(logged, isNot(contains('super-secret')));
    expect(logged, contains('<redacted>'));
  });

  test('redacts a password field in a logged request body', () async {
    final adapter = FakeHttpClientAdapter(
      (options, call) => jsonResponseBody({'ok': true}),
    );
    final dio = buildDio(adapter, logBodies: true);

    await dio.post<dynamic>(
      '/login',
      data: {'email': 'a@b.com', 'password': 'hunter2'},
    );

    final logged = loggedText();
    expect(logged, isNot(contains('hunter2')));
    expect(logged, contains('a@b.com'));
  });

  test('never logs file content for multipart attachment uploads', () async {
    final adapter = FakeHttpClientAdapter(
      (options, call) => jsonResponseBody({'ok': true}),
    );
    final dio = buildDio(adapter, logBodies: true);

    final formData = FormData.fromMap({
      'title': 'attachment',
      'file': MultipartFile.fromBytes(
        List.filled(10, 1),
        filename: 'confidential-report.pdf',
      ),
    });

    await dio.post<dynamic>('/attachments', data: formData);

    final logged = loggedText();
    expect(logged, contains('FormData'));
    expect(logged, contains('file')); // field name only
    expect(logged, isNot(contains('confidential-report.pdf')));
  });

  test('does not log request bodies when logBodies is false', () async {
    final adapter = FakeHttpClientAdapter(
      (options, call) => jsonResponseBody({'ok': true}),
    );
    final dio = buildDio(adapter, logBodies: false);

    await dio.post<dynamic>(
      '/login',
      data: {'email': 'a@b.com', 'password': 'hunter2'},
    );

    final logged = loggedText();
    expect(logged, isNot(contains('body:')));
    expect(logged, isNot(contains('hunter2')));
  });

  test(
    'logs the final outcome of a failed request without leaking data',
    () async {
      final adapter = FakeHttpClientAdapter(
        (options, call) =>
            jsonResponseBody({'message': 'nope'}, statusCode: 500),
      );
      final dio = buildDio(adapter, logBodies: true);

      await expectLater(
        () => dio.post<dynamic>('/login', data: {'password': 'hunter2'}),
        throwsA(isA<DioException>()),
      );

      final logged = loggedText();
      expect(logged, contains('failed'));
      expect(logged, isNot(contains('hunter2')));
    },
  );
}
