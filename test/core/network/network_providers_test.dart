import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/config/app_config.dart';
import 'package:tracker_flutter/core/config/app_environment.dart';
import 'package:tracker_flutter/core/di/app_providers.dart';
import 'package:tracker_flutter/core/di/network_providers.dart';
import 'package:tracker_flutter/core/network/interceptors/redacting_log_interceptor.dart';

void main() {
  test('the redacting logger is the final Dio interceptor', () {
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            environment: AppEnvironment.local,
            apiBaseUrl: 'http://localhost:8080',
            enableVerboseLogging: true,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final dio = container.read(dioProvider);

    expect(dio.interceptors.last, isA<RedactingLogInterceptor>());
  });
}
