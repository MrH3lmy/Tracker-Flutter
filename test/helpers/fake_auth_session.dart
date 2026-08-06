import 'package:tracker_flutter/core/network/auth/auth_session.dart';

/// A controllable [AuthSession] test double: set [token]/[refreshResult]
/// up front, then assert on [refreshCalls]/[signOutCalls] afterward.
class FakeAuthSession implements AuthSession {
  FakeAuthSession({this.token, this.refreshResult, this.refreshDelay});

  String? token;
  String? refreshResult;
  Duration? refreshDelay;

  int refreshCalls = 0;
  int signOutCalls = 0;

  @override
  String? get accessToken => token;

  @override
  Future<String?> refreshAccessToken() async {
    refreshCalls++;
    if (refreshDelay != null) {
      await Future<void>.delayed(refreshDelay!);
    }
    token = refreshResult;
    return refreshResult;
  }

  @override
  Future<void> forceSignOut() async {
    signOutCalls++;
    token = null;
  }
}
