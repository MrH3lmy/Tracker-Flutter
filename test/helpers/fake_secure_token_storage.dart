import 'package:tracker_flutter/features/auth/data/secure_token_storage.dart';

class FakeSecureTokenStorage implements SecureTokenStorage {
  FakeSecureTokenStorage({String? initialToken}) : storedToken = initialToken;

  String? storedToken;
  int writeCalls = 0;
  int deleteCalls = 0;

  @override
  Future<String?> readRefreshToken() async => storedToken;

  @override
  Future<void> writeRefreshToken(String token) async {
    writeCalls++;
    storedToken = token;
  }

  @override
  Future<void> deleteRefreshToken() async {
    deleteCalls++;
    storedToken = null;
  }
}
