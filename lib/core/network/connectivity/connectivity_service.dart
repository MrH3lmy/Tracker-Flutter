import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reports whether the device has *a* network interface up. This is
/// presence, not reachability — a phone on Wi-Fi with no internet still
/// reports present. `ApiClient` uses it only to refine a failed request's
/// error (no interface at all -> [OfflineFailure] instead of
/// [NetworkFailure]), never as proof a request will succeed.
abstract interface class ConnectivityService {
  Future<bool> get hasNetworkPresence;

  Stream<bool> get onNetworkPresenceChanged;
}

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> get hasNetworkPresence async =>
      hasNetworkPresenceFrom(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onNetworkPresenceChanged =>
      _connectivity.onConnectivityChanged.map(hasNetworkPresenceFrom);
}

/// Pure classification, split out so it's testable without the
/// connectivity_plus platform channel.
bool hasNetworkPresenceFrom(List<ConnectivityResult> results) =>
    results.any((result) => result != ConnectivityResult.none);

final connectivityServiceProvider = Provider<ConnectivityService>(
  (ref) => ConnectivityPlusService(),
);
