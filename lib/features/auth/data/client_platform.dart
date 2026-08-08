import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mirrors Tracker-BE's `Platform` enum — sent explicitly on native
/// register/login so sessions carry real device metadata, and used here to
/// pick which of the two auth contracts (web cookie vs. native body) a
/// request uses. Names match the backend's enum constants exactly.
enum ClientPlatform { web, android, ios, windows, macos, linux }

/// Pure function (no globals read directly) so the branching is testable
/// without needing to fake `kIsWeb`/`defaultTargetPlatform` themselves —
/// [resolveClientPlatform] below supplies the real values.
ClientPlatform clientPlatformFrom({
  required bool isWeb,
  required TargetPlatform targetPlatform,
}) {
  if (isWeb) return ClientPlatform.web;
  return switch (targetPlatform) {
    TargetPlatform.android => ClientPlatform.android,
    TargetPlatform.iOS => ClientPlatform.ios,
    TargetPlatform.windows => ClientPlatform.windows,
    TargetPlatform.macOS => ClientPlatform.macos,
    TargetPlatform.linux => ClientPlatform.linux,
    // Fuchsia has no equivalent in the backend contract and isn't a
    // supported target; fall back to the closest native bucket rather than
    // crashing.
    TargetPlatform.fuchsia => ClientPlatform.linux,
  };
}

ClientPlatform resolveClientPlatform() =>
    clientPlatformFrom(isWeb: kIsWeb, targetPlatform: defaultTargetPlatform);

final clientPlatformProvider = Provider<ClientPlatform>(
  (ref) => resolveClientPlatform(),
);
