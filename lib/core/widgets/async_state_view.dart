import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/app_failure.dart';
import '../theme/app_tokens.dart';

/// Renders an [AsyncValue] through the loading / empty / error / data states
/// every feature screen needs, so those states are drawn consistently
/// instead of being reimplemented per screen.
///
/// [isEmpty] is optional — most lists want an empty state distinct from a
/// bare loading spinner; screens that render a single resource can omit it.
class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    super.key,
    required this.value,
    required this.data,
    this.isEmpty,
    this.emptyBuilder,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(BuildContext context, T data) data;
  final bool Function(T data)? isEmpty;
  final WidgetBuilder? emptyBuilder;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => _ErrorState(error: error, onRetry: onRetry),
      data: (value) {
        if (isEmpty != null && isEmpty!(value)) {
          return emptyBuilder?.call(context) ?? const _EmptyState();
        }
        return data(context, value);
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Nothing here yet.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = error is AppFailure ? error as AppFailure : null;
    final isOffline = failure is OfflineFailure;
    final isUnauthorized = failure is UnauthorizedFailure;

    final message = switch (failure) {
      OfflineFailure() =>
        "You're offline. Check your connection and try again.",
      UnauthorizedFailure() =>
        'Your session has expired. Please sign in again.',
      AppFailure(message: final m?) => m,
      _ => 'Something went wrong. Please try again.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOffline
                  ? Icons.wifi_off
                  : isUnauthorized
                  ? Icons.lock_outline
                  : Icons.error_outline,
              size: 40,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null && !isUnauthorized) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
