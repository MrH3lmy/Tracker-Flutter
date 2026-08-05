import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/app_providers.dart';

/// Stands in for a real repository call so [HomeScreen] can demonstrate the
/// loading/data/error flow through [AsyncStateView] end to end. Replace with
/// an actual feature provider once there is a backend-backed screen to show
/// here (projects, per the release-strategy epic).
final greetingProvider = FutureProvider.autoDispose<String>((ref) async {
  final config = ref.watch(appConfigProvider);
  await Future<void>.delayed(const Duration(milliseconds: 300));
  return 'Connected to ${config.environment.name} environment.';
});
