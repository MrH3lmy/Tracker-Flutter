enum UserTier { free, premium }

enum UserRole { user, admin }

/// Mirrors Tracker-BE's `UserResponse` — never carries a password, token, or
/// any credential.
class User {
  const User({
    required this.id,
    required this.email,
    required this.displayName,
    required this.tier,
    required this.role,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String,
      displayName: json['displayName'] as String?,
      tier: _tierFromJson(json['tier'] as String?),
      role: _roleFromJson(json['role'] as String?),
    );
  }

  final int id;
  final String email;
  final String? displayName;
  final UserTier tier;
  final UserRole role;

  static UserTier _tierFromJson(String? raw) => switch (raw) {
    'PREMIUM' => UserTier.premium,
    _ => UserTier.free,
  };

  static UserRole _roleFromJson(String? raw) => switch (raw) {
    'ADMIN' => UserRole.admin,
    _ => UserRole.user,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == id &&
          other.email == email &&
          other.displayName == displayName &&
          other.tier == tier &&
          other.role == role);

  @override
  int get hashCode => Object.hash(id, email, displayName, tier, role);
}
