import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../auth/data/auth_repository.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greeting = ref.watch(greetingProvider);
    final session = ref.watch(authRepositoryProvider);
    final user = session.userOrNull;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tracker', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.sm),
          if (user != null) ...[
            Text(
              'Signed in as ${user.email}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              children: [
                OutlinedButton(
                  onPressed: () =>
                      ref.read(authRepositoryProvider.notifier).logout(),
                  child: const Text('Sign out'),
                ),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(authRepositoryProvider.notifier).logoutAll(),
                  child: const Text('Sign out everywhere'),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: AsyncStateView<String>(
              value: greeting,
              onRetry: () => ref.invalidate(greetingProvider),
              data: (context, value) =>
                  Text(value, style: Theme.of(context).textTheme.bodyLarge),
            ),
          ),
        ],
      ),
    );
  }
}
