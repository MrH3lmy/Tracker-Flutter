import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/features/auth/data/auth_result.dart';

void main() {
  group('AuthResult.fromJson', () {
    test('parses the native shape (refreshToken present)', () {
      final result = AuthResult.fromJson({
        'accessToken': 'access-1',
        'refreshToken': 'refresh-1',
        'user': {'id': 1, 'email': 'a@b.com', 'tier': 'FREE', 'role': 'USER'},
      });

      expect(result.accessToken, 'access-1');
      expect(result.refreshToken, 'refresh-1');
      expect(result.user.email, 'a@b.com');
    });

    test('parses the web shape (no refreshToken field)', () {
      final result = AuthResult.fromJson({
        'accessToken': 'access-1',
        'user': {'id': 1, 'email': 'a@b.com', 'tier': 'FREE', 'role': 'USER'},
      });

      expect(result.refreshToken, isNull);
    });
  });
}
