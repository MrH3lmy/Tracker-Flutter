import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/network/request_policy.dart';

void main() {
  group('RequestPolicy defaults', () {
    test('GET is idempotent (safe to retry) with no policy set', () {
      final options = RequestOptions(path: '/tasks', method: 'GET');
      expect(options.isSafeToRetry, isTrue);
    });

    test('POST is not safe to retry with no policy set', () {
      final options = RequestOptions(path: '/tasks', method: 'POST');
      expect(options.isSafeToRetry, isFalse);
    });

    test('an explicit retryable policy makes a POST safe to retry', () {
      const policy = RequestPolicy(retryable: true);
      final options = RequestOptions(
        path: '/tasks',
        method: 'POST',
      ).copyWith(extra: policy.toOptions().extra);

      expect(options.isSafeToRetry, isTrue);
    });

    test('skipAuth defaults to false', () {
      final options = RequestOptions(path: '/tasks');
      expect(options.policy.skipAuth, isFalse);
    });

    test('an explicit skipAuth policy round-trips through toOptions', () {
      const policy = RequestPolicy(skipAuth: true);
      final options = RequestOptions(
        path: '/auth/refresh',
      ).copyWith(extra: policy.toOptions().extra);

      expect(options.policy.skipAuth, isTrue);
    });
  });
}
