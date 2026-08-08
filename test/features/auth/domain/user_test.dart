import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/features/auth/domain/user.dart';

void main() {
  group('User.fromJson', () {
    test('parses a full response', () {
      final user = User.fromJson({
        'id': 42,
        'email': 'a@b.com',
        'displayName': 'Ada',
        'tier': 'PREMIUM',
        'role': 'ADMIN',
      });

      expect(user.id, 42);
      expect(user.email, 'a@b.com');
      expect(user.displayName, 'Ada');
      expect(user.tier, UserTier.premium);
      expect(user.role, UserRole.admin);
    });

    test('defaults to free/user for unrecognized or missing tier/role', () {
      final user = User.fromJson({'id': 1, 'email': 'a@b.com'});

      expect(user.displayName, isNull);
      expect(user.tier, UserTier.free);
      expect(user.role, UserRole.user);
    });

    test('equality is value-based', () {
      final a = User.fromJson({
        'id': 1,
        'email': 'a@b.com',
        'tier': 'FREE',
        'role': 'USER',
      });
      final b = User.fromJson({
        'id': 1,
        'email': 'a@b.com',
        'tier': 'FREE',
        'role': 'USER',
      });

      expect(a, b);
    });
  });
}
