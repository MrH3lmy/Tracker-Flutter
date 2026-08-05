import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_state_view.dart';
import 'home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greeting = ref.watch(greetingProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: AsyncStateView<String>(
        value: greeting,
        onRetry: () => ref.invalidate(greetingProvider),
        data: (context, value) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tracker', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
