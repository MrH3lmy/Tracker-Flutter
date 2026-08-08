import '../domain/user.dart';

/// The wire shape both contracts return. [refreshToken] is only ever
/// present for the native contract (Tracker-BE's `AuthResponse`) — the
/// browser contract (`AuthResponseBody`) omits the field entirely because
/// the refresh token travels solely via an `HttpOnly` cookie Dart code
/// never sees.
class AuthResult {
  const AuthResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String?,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final String? refreshToken;
  final User user;
}
