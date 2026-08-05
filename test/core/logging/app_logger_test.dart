import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/logging/app_logger.dart';

void main() {
  group('AppLogger.redact', () {
    test('redacts a password field', () {
      final result = AppLogger.redact('login failed for password: hunter2');
      expect(result, isNot(contains('hunter2')));
      expect(result, contains('<redacted>'));
    });

    test('redacts bearer tokens and cookies case-insensitively', () {
      final result = AppLogger.redact(
        'Authorization: Bearer abc.def, Set-Cookie: sid=xyz',
      );
      expect(result, isNot(contains('abc.def')));
      expect(result, isNot(contains('xyz')));
    });

    test('leaves non-sensitive text untouched', () {
      const message = 'GET /api/projects -> 200 in 42ms';
      expect(AppLogger.redact(message), message);
    });
  });
}
