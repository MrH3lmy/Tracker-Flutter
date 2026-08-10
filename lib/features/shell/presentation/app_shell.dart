import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/adaptive_scaffold.dart';
import '../../auth/data/auth_repository.dart';

enum _AccountAction { signOut, signOutAll }

/// Authenticated application shell.
///
/// Holds the single set of navigation destinations shared by every
/// platform; the destination list grows as feature epics land (archive,
/// settings, ...). Projects and the global Board view exist today (epic #4
/// slices 1-2) — Board is intentionally not scoped to the selected project;
/// see `BoardScreen`'s doc comment for why.
///
/// The account menu lives here rather than on individual screens so
/// sign-out stays available regardless of which destination is active.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.routerState, required this.child});

  final GoRouterState routerState;
  final Widget child;

  static const _destinationPaths = [AppRoutes.home, AppRoutes.board];

  static const destinations = [
    AdaptiveDestination(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: 'Projects',
    ),
    AdaptiveDestination(
      icon: Icons.view_column_outlined,
      selectedIcon: Icons.view_column,
      label: 'Board',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).userOrNull;
    // -1 (no match, shouldn't happen for a route inside this shell) clamps
    // to the first destination rather than crashing on a negative index.
    final selectedIndex = _destinationPaths
        .indexOf(routerState.matchedLocation)
        .clamp(0, _destinationPaths.length - 1);

    return AdaptiveScaffold(
      appBar: AppBar(
        title: const Text('Tracker'),
        actions: [
          PopupMenuButton<_AccountAction>(
            tooltip: 'Account',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (action) {
              final notifier = ref.read(authRepositoryProvider.notifier);
              switch (action) {
                case _AccountAction.signOut:
                  unawaited(notifier.logout());
                case _AccountAction.signOutAll:
                  unawaited(notifier.logoutAll());
              }
            },
            itemBuilder: (context) => [
              if (user != null)
                PopupMenuItem<_AccountAction>(
                  enabled: false,
                  child: Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const PopupMenuItem(
                value: _AccountAction.signOut,
                child: Text('Sign out'),
              ),
              const PopupMenuItem(
                value: _AccountAction.signOutAll,
                child: Text('Sign out everywhere'),
              ),
            ],
          ),
        ],
      ),
      destinations: destinations,
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) => context.go(_destinationPaths[index]),
      body: child,
    );
  }
}
