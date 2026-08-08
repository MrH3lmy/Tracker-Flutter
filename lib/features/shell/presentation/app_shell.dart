import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/adaptive_scaffold.dart';
import '../../auth/data/auth_repository.dart';

enum _AccountAction { signOut, signOutAll }

/// Authenticated application shell.
///
/// Holds the single set of navigation destinations shared by every
/// platform; the destination list grows as feature epics land (boards,
/// archive, settings, ...). Only Projects exists today (epic #4 slice 1).
///
/// The account menu lives here rather than on individual screens so
/// sign-out stays available regardless of which destination is active.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static const destinations = [
    AdaptiveDestination(
      icon: Icons.folder_outlined,
      selectedIcon: Icons.folder,
      label: 'Projects',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authRepositoryProvider).userOrNull;

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
      selectedIndex: 0,
      onDestinationSelected: (_) {},
      body: child,
    );
  }
}
