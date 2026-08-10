import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/adaptive_scaffold.dart';
import '../../auth/data/auth_repository.dart';

enum _AccountAction { signOut, signOutAll }

/// Authenticated application shell shared by mobile, web, and desktop.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.routerState, required this.child});

  final GoRouterState routerState;
  final Widget child;

  static const _destinationPaths = [
    AppRoutes.home,
    AppRoutes.board,
    AppRoutes.tasks,
  ];

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
    AdaptiveDestination(
      icon: Icons.checklist_outlined,
      selectedIcon: Icons.checklist,
      label: 'Tasks',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).userOrNull;
    final selectedIndex = _selectedIndex(routerState.matchedLocation);

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

  static int _selectedIndex(String location) {
    if (location == AppRoutes.board) return 1;
    if (location == AppRoutes.tasks ||
        location.startsWith('${AppRoutes.tasks}/')) {
      return 2;
    }
    return 0;
  }
}
