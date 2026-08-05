import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
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

    test('redacts a standalone bearer credential', () {
      final result = AppLogger.redact('request failed: Bearer abc.def.ghi');
      expect(result, isNot(contains('abc.def.ghi')));
      expect(result, contains('Bearer <redacted>'));
    });

    test('leaves non-sensitive text untouched', () {
      const message = 'GET /api/projects -> 200 in 42ms';
      expect(AppLogger.redact(message), message);
    });
  });

  group('AppLogger.formatRecord', () {
    test('keeps diagnostic context while sanitizing error and stack trace', () {
      final record = LogRecord(
        Level.SEVERE,
        'Refresh failed for token=message-secret',
        'auth',
        StateError('refresh_token=error-secret'),
        StackTrace.fromString(
          'Authorization: Bearer stack-secret\n#0 AuthClient.refresh',
        ),
      );

      final formatted = AppLogger.formatRecord(record);

      expect(formatted, contains('[SEVERE] auth:'));
      expect(formatted, contains('Error:'));
      expect(formatted, contains('Stack trace:'));
      expect(formatted, contains('#0 AuthClient.refresh'));
      expect(formatted, isNot(contains('message-secret')));
      expect(formatted, isNot(contains('error-secret')));
      expect(formatted, isNot(contains('stack-secret')));
    });
  });
}
