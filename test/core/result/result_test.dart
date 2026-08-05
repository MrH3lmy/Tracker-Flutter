import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';

void main() {
  group('Result', () {
    test('success exposes the value and not a failure', () {
      const result = Result<int>.success(42);

      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('failure exposes the failure and not a value', () {
      const result = Result<int>.failure(NetworkFailure());

      expect(result.isSuccess, isFalse);
      expect(result.isFailure, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, isA<NetworkFailure>());
    });

    test('when dispatches to the matching branch', () {
      const success = Result<int>.success(1);
      const failure = Result<int>.failure(UnknownFailure());

      expect(
        success.when(success: (v) => 'ok:$v', failure: (f) => 'err'),
        'ok:1',
      );
      expect(
        failure.when(success: (v) => 'ok:$v', failure: (f) => 'err'),
        'err',
      );
    });

    test('map transforms only the success value', () {
      const success = Result<int>.success(2);
      const failure = Result<int>.failure(UnknownFailure());

      expect(success.map((v) => v * 10).valueOrNull, 20);
      expect(failure.map((v) => v * 10).failureOrNull, isA<UnknownFailure>());
    });

    test('equality is value-based', () {
      expect(const Result<int>.success(1), const Result<int>.success(1));
      expect(
        const Result<int>.success(1) == const Result<int>.success(2),
        isFalse,
      );
    });
  });
}
