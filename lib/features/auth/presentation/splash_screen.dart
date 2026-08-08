import 'package:flutter/material.dart';

/// Shown while [SessionStatus.unknown] — session restoration (a silent
/// refresh on web, a stored-token exchange on native) is still in flight.
/// The router holds every other route behind this one until it resolves,
/// so a protected screen never briefly renders before we know whether the
/// user is actually signed in.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
