import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/board_columns/data/board_columns_controller.dart';
import 'package:tracker_flutter/features/board_columns/data/board_columns_repository.dart';
import 'package:tracker_flutter/features/board_columns/domain/board_column.dart';

import '../../../helpers/fake_board_columns_repository.dart';

BoardColumn _column(
  int id, {
  String name = 'Backlog',
  ColumnStatus status = ColumnStatus.backlog,
  int position = 1000,
}) => BoardColumn(id: id, name: name, status: status, position: position);

void main() {
  ({ProviderContainer container, FakeBoardColumnsRepository repo}) build() {
    final repo = FakeBoardColumnsRepository();
    final container = ProviderContainer(
      overrides: [boardColumnsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo);
  }

  final provider = boardColumnsControllerProvider(7);

  ProviderSubscription<AsyncValue<List<BoardColumn>>> keepAlive(
    ProviderContainer container, [
    int userId = 7,
  ]) {
    final subscription = container.listen(
      boardColumnsControllerProvider(userId),
      (previous, next) {},
    );
    addTearDown(subscription.close);
    return subscription;
  }

  test('starts in AsyncLoading before the fetch resolves', () {
    final built = build();
    built.repo.fetchResult = const Result.success([]);
    keepAlive(built.container);

    expect(
      built.container.read(provider),
      isA<AsyncLoading<List<BoardColumn>>>(),
    );
  });

  test('a successful load exposes the columns as AsyncData', () async {
    final built = build();
    built.repo.fetchResult = Result.success([_column(1), _column(2)]);
    keepAlive(built.container);

    final columns = await built.container.read(provider.future);

    expect(columns, hasLength(2));
    expect(built.container.read(provider), isA<AsyncData<List<BoardColumn>>>());
  });

  test('an empty backend list surfaces as an empty AsyncData', () async {
    final built = build();
    built.repo.fetchResult = const Result.success([]);
    keepAlive(built.container);

    final columns = await built.container.read(provider.future);

    expect(columns, isEmpty);
  });

  test(
    'a repository failure surfaces as AsyncError carrying the AppFailure',
    () async {
      final built = build();
      built.repo.fetchResult = const Result.failure(
        ServerFailure(statusCode: 500),
      );
      keepAlive(built.container);

      await expectLater(
        built.container.read(provider.future),
        throwsA(isA<ServerFailure>()),
      );
      final state = built.container.read(provider);
      expect(state, isA<AsyncError<List<BoardColumn>>>());
      expect(
        (state as AsyncError<List<BoardColumn>>).error,
        isA<ServerFailure>(),
      );
    },
  );

  test(
    'the default build-retry policy is disabled (an AppFailure never triggers Riverpod\'s silent retry)',
    () async {
      final built = build();
      built.repo.fetchResult = const Result.failure(UnauthorizedFailure());
      keepAlive(built.container);

      // Would hang for ~40s (10 retries, exponential backoff) if retry
      // were still enabled for this provider — see the doc comment on
      // boardColumnsControllerProvider.
      await expectLater(
        built.container.read(provider.future),
        throwsA(isA<UnauthorizedFailure>()),
      );
      expect(built.repo.fetchCalls, 1);
    },
  );

  test('refresh() re-fetches and replaces the list on success', () async {
    final built = build();
    built.repo.fetchResult = Result.success([_column(1)]);
    keepAlive(built.container);
    await built.container.read(provider.future);

    built.repo.fetchResult = Result.success([_column(1), _column(2)]);
    await built.container.read(provider.notifier).refresh();

    final state = built.container.read(provider);
    expect(state.value, hasLength(2));
    expect(built.repo.fetchCalls, 2);
  });

  test(
    'refresh() (retry) recovers from an error into AsyncData on success',
    () async {
      final built = build();
      built.repo.fetchResult = const Result.failure(UnauthorizedFailure());
      keepAlive(built.container);
      await expectLater(
        built.container.read(provider.future),
        throwsA(isA<UnauthorizedFailure>()),
      );

      built.repo.fetchResult = Result.success([_column(1)]);
      await built.container.read(provider.notifier).refresh();

      final state = built.container.read(provider);
      expect(state, isA<AsyncData<List<BoardColumn>>>());
      expect(state.value, hasLength(1));
    },
  );

  test('refresh() keeps the previous list visible while re-fetching', () async {
    final built = build();
    built.repo.fetchResult = Result.success([_column(1)]);
    keepAlive(built.container);
    await built.container.read(provider.future);

    final refreshCompleter = Completer<Result<List<BoardColumn>>>();
    built.repo.fetchResult = null;
    final controller = built.container.read(provider.notifier);
    built.repo.fetchResultFuture = refreshCompleter.future;
    final refreshFuture = controller.refresh();

    // Still showing the previous data while the new request is pending.
    final duringRefresh = built.container.read(provider);
    expect(duringRefresh.value, hasLength(1));

    refreshCompleter.complete(Result.success([_column(1), _column(2)]));
    await refreshFuture;

    expect(built.container.read(provider).value, hasLength(2));
  });

  test(
    "an older in-flight refresh() does not clobber a newer one's result",
    () async {
      final built = build();
      built.repo.fetchResult = Result.success([_column(1)]);
      keepAlive(built.container);
      await built.container.read(provider.future);
      final controller = built.container.read(provider.notifier);

      final firstCompleter = Completer<Result<List<BoardColumn>>>();
      built.repo.fetchResultFuture = firstCompleter.future;
      final firstRefresh = controller.refresh();

      final secondCompleter = Completer<Result<List<BoardColumn>>>();
      built.repo.fetchResultFuture = secondCompleter.future;
      final secondRefresh = controller.refresh();

      // The second (newer) request resolves first...
      secondCompleter.complete(Result.success([_column(1), _column(2)]));
      await secondRefresh;
      expect(built.container.read(provider).value, hasLength(2));

      // ...and the first (older, slower) request resolving afterwards must
      // not overwrite it with stale data.
      firstCompleter.complete(Result.success([_column(1)]));
      await firstRefresh;
      expect(built.container.read(provider).value, hasLength(2));
    },
  );

  test("different user ids never share a cached column list", () async {
    final built = build();
    built.repo.fetchResult = Result.success([_column(1, name: 'User A col')]);
    keepAlive(built.container, 7);
    await built.container.read(boardColumnsControllerProvider(7).future);

    built.repo.fetchResult = Result.success([_column(2, name: 'User B col')]);
    keepAlive(built.container, 8);
    await built.container.read(boardColumnsControllerProvider(8).future);

    expect(
      built.container
          .read(boardColumnsControllerProvider(7))
          .value
          ?.single
          .name,
      'User A col',
    );
    expect(
      built.container
          .read(boardColumnsControllerProvider(8))
          .value
          ?.single
          .name,
      'User B col',
    );
    expect(built.repo.fetchCalls, 2);
  });

  test(
    'is autoDispose: the cached list is dropped once the last listener goes away, '
    'so the next account never reads a leftover value',
    () async {
      final built = build();
      built.repo.fetchResult = Result.success([_column(1, name: 'User A col')]);
      final subscription = keepAlive(built.container, 7);
      await built.container.read(boardColumnsControllerProvider(7).future);
      expect(built.container.exists(boardColumnsControllerProvider(7)), isTrue);

      subscription.close();
      // Riverpod schedules autoDispose disposal via a real Timer.zero (see
      // ProviderScheduler), not synchronously — it deliberately waits a
      // tick so a transient rebuild that drops and immediately re-adds a
      // listener doesn't churn the provider. Flush that timer.
      await Future<void>.delayed(Duration.zero);
      expect(
        built.container.exists(boardColumnsControllerProvider(7)),
        isFalse,
      );

      // Re-subscribing (e.g. the same device signing in as a different
      // account that happens to reuse this provider family instance)
      // starts a fresh load rather than reading anything cached.
      built.repo.fetchResult = Result.success([_column(2, name: 'User B col')]);
      keepAlive(built.container, 7);
      final columns = await built.container.read(
        boardColumnsControllerProvider(7).future,
      );
      expect(columns.single.name, 'User B col');
      expect(built.repo.fetchCalls, 2);
    },
  );
}
