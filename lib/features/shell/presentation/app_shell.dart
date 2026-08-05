import 'package:flutter/material.dart';

import '../../../core/widgets/adaptive_scaffold.dart';

/// Authenticated application shell.
///
/// Holds the single set of navigation destinations shared by every
/// platform; the destination list grows as feature epics land (projects,
/// boards, archive, settings, ...). Only one destination exists today
/// because only the bootstrap epic's placeholder screen exists.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const destinations = [
    AdaptiveDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: 'Home',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      appBar: AppBar(title: const Text('Tracker')),
      destinations: destinations,
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      body: child,
    );
  }
}
