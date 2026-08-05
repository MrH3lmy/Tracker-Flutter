import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tracker_flutter/core/router/app_router.dart';
import 'package:tracker_flutter/core/router/session_status.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'router instance stays stable when session state is invalidated',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final router = container.read(routerProvider);

      container.invalidate(sessionStatusProvider);
      await Future<void>.delayed(Duration.zero);

      expect(identical(container.read(routerProvider), router), isTrue);
    },
  );
}
