import 'package:tracker_flutter/core/network/connectivity/connectivity_service.dart';

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.hasNetwork = true, this.error});

  bool hasNetwork;
  Object? error;

  @override
  Future<bool> get hasNetworkPresence async {
    if (error != null) throw error!;
    return hasNetwork;
  }

  @override
  Stream<bool> get onNetworkPresenceChanged => Stream.value(hasNetwork);
}
