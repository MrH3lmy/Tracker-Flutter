import 'package:tracker_flutter/core/network/connectivity/connectivity_service.dart';

class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.hasNetwork = true});

  bool hasNetwork;

  @override
  Future<bool> get hasNetworkPresence async => hasNetwork;

  @override
  Stream<bool> get onNetworkPresenceChanged => Stream.value(hasNetwork);
}
