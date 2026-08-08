import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'client_platform.dart';

/// Persists the native refresh credential only. There is deliberately no
/// method here that could plausibly be used for an access token — those
/// live in memory only (`AuthRepository`), never in storage.
abstract interface class SecureTokenStorage {
  /// Never throws: any read failure (corruption, an invalidated platform
  /// key, a broken platform channel) is indistinguishable from "no
  /// credential" to callers and is reported as `null` rather than an
  /// exception, so `AuthRepository` doesn't need its own defensive catch
  /// around every read.
  Future<String?> readRefreshToken();

  Future<void> writeRefreshToken(String token);
  Future<void> deleteRefreshToken();
}

/// OS-backed secure storage (Keychain / Keystore / Credential Manager /
/// Secret Service) for native platforms. Any failure — corruption, an
/// invalidated Keystore key after the user changed their lock-screen
/// credentials, a platform channel error — is treated as "no usable
/// credential" rather than propagated, since a broken read must still let
/// `AuthRepository` reach a safe signed-out state instead of crashing
/// startup.
class FlutterSecureTokenStorage implements SecureTokenStorage {
  FlutterSecureTokenStorage([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _refreshTokenKey = 'tracker.refreshToken';

  @override
  Future<String?> readRefreshToken() async {
    try {
      return await _storage.read(key: _refreshTokenKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> writeRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  @override
  Future<void> deleteRefreshToken() async {
    try {
      await _storage.delete(key: _refreshTokenKey);
    } catch (_) {
      // Best-effort: if storage is unreadable/corrupted, there is nothing
      // more a delete can reliably do either.
    }
  }
}

/// Flutter Web has no refresh credential to store: the browser contract
/// keeps the refresh token in an `HttpOnly` cookie Dart code never
/// receives. This exists purely so `AuthRepository` doesn't need
/// `kIsWeb` branches sprinkled through it — there is nothing to leak
/// because there is nothing to write in the first place, which is the
/// point (no JavaScript-readable storage is used for it, ever).
class NoopTokenStorage implements SecureTokenStorage {
  const NoopTokenStorage();

  @override
  Future<String?> readRefreshToken() async => null;

  @override
  Future<void> writeRefreshToken(String token) async {}

  @override
  Future<void> deleteRefreshToken() async {}
}

final secureTokenStorageProvider = Provider<SecureTokenStorage>((ref) {
  final platform = ref.watch(clientPlatformProvider);
  return platform == ClientPlatform.web
      ? const NoopTokenStorage()
      : FlutterSecureTokenStorage();
});
