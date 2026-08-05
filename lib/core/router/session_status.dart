import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder session states for route guarding.
///
/// The real state machine (unknown while restoring session, authenticated,
/// unauthenticated, refreshing, unrecoverable) is built in the
/// cross-platform-authentication epic. Until then [sessionStatusProvider]
/// always reports [SessionStatus.authenticated] so the app shell is
/// reachable, and [AppRouter] already reads it on every navigation — wiring
/// in the real controller later requires no router changes.
enum SessionStatus { unknown, authenticated, unauthenticated }

final sessionStatusProvider = Provider<SessionStatus>(
  (ref) => SessionStatus.authenticated,
);
