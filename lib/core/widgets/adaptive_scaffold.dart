import 'package:flutter/material.dart';

import '../utils/breakpoints.dart';

class AdaptiveDestination {
  const AdaptiveDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// A scaffold that swaps navigation chrome by window size instead of
/// stretching a single phone layout to every platform:
///  - compact (phones): bottom navigation bar
///  - medium (small tablets / split-screen): unlabeled navigation rail
///  - expanded (desktop / web / large tablets): extended navigation rail
class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.body,
    this.appBar,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget body;
  final PreferredSizeWidget? appBar;

  @override
  Widget build(BuildContext context) {
    final breakpoint = AppBreakpoint.of(context);

    switch (breakpoint) {
      case AppBreakpoint.compact:
        return Scaffold(
          appBar: appBar,
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: [
              for (final d in destinations)
                NavigationDestination(
                  icon: Icon(d.icon),
                  selectedIcon: Icon(d.selectedIcon),
                  label: d.label,
                ),
            ],
          ),
        );

      case AppBreakpoint.medium:
      case AppBreakpoint.expanded:
        final extended = breakpoint == AppBreakpoint.expanded;
        return Scaffold(
          appBar: appBar,
          body: Row(
            children: [
              NavigationRail(
                extended: extended,
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                labelType: extended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.selected,
                destinations: [
                  for (final d in destinations)
                    NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.selectedIcon),
                      label: Text(d.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: body),
            ],
          ),
        );
    }
  }
}
