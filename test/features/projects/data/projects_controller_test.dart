import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/error/app_failure.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/projects/data/projects_controller.dart';
import 'package:tracker_flutter/features/projects/data/projects_repository.dart';
import 'package:tracker_flutter/features/projects/domain/project.dart';

import '../../../helpers/fake_projects_repository.dart';

Project _project(int id, {String name = 'Website relaunch'}) => Project(
  id: id,
  name: name,
  description: null,
  status: ProjectStatus.active,
  startDate: null,
  targetDate: null,
  area: null,
  goal: null,
  ownerUserId: 7,
  createdDate: DateTime.parse('2026-01-01T10:15:30'),
);

void main() {
  ({ProviderContainer container, FakeProjectsRepository repo}) build() {
    final repo = FakeProjectsRepository();
    final container = ProviderContainer(
      overrides: [projectsRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    return (container: container, repo: repo);
  }

  test('starts in AsyncLoading before the fetch resolves', () {
    final built = build();
    built.repo.fetchResult = const Result.success([]);

    expect(
      built.container.read(projectsControllerProvider),
      isA<AsyncLoading<List<Project>>>(),
    );
  });

  test('a successful load exposes the projects as AsyncData', () async {
    final built = build();
    built.repo.fetchResult = Result.success([_project(1), _project(2)]);

    final projects = await built.container.read(
      projectsControllerProvider.future,
    );

    expect(projects, hasLength(2));
    expect(
      built.container.read(projectsControllerProvider),
      isA<AsyncData<List<Project>>>(),
    );
  });

  test('an empty backend list surfaces as an empty AsyncData', () async {
    final built = build();
    built.repo.fetchResult = const Result.success([]);

    final projects = await built.container.read(
      projectsControllerProvider.future,
    );

    expect(projects, isEmpty);
  });

  test(
    'a repository failure surfaces as AsyncError carrying the AppFailure',
    () async {
      final built = build();
      built.repo.fetchResult = const Result.failure(
        ServerFailure(statusCode: 500),
      );

      await expectLater(
        built.container.read(projectsControllerProvider.future),
        throwsA(isA<ServerFailure>()),
      );
      final state = built.container.read(projectsControllerProvider);
      expect(state, isA<AsyncError<List<Project>>>());
      expect((state as AsyncError<List<Project>>).error, isA<ServerFailure>());
    },
  );

  test('refresh() re-fetches and replaces the list on success', () async {
    final built = build();
    built.repo.fetchResult = Result.success([_project(1)]);
    await built.container.read(projectsControllerProvider.future);

    built.repo.fetchResult = Result.success([_project(1), _project(2)]);
    await built.container.read(projectsControllerProvider.notifier).refresh();

    final state = built.container.read(projectsControllerProvider);
    expect(state.value, hasLength(2));
    expect(built.repo.fetchCalls, 2);
  });

  test(
    'refresh() (retry) recovers from an error into AsyncData on success',
    () async {
      final built = build();
      built.repo.fetchResult = const Result.failure(UnauthorizedFailure());
      await expectLater(
        built.container.read(projectsControllerProvider.future),
        throwsA(isA<UnauthorizedFailure>()),
      );

      built.repo.fetchResult = Result.success([_project(1)]);
      await built.container.read(projectsControllerProvider.notifier).refresh();

      final state = built.container.read(projectsControllerProvider);
      expect(state, isA<AsyncData<List<Project>>>());
      expect(state.value, hasLength(1));
    },
  );

  test('refresh() keeps the previous list visible while re-fetching', () async {
    final built = build();
    built.repo.fetchResult = Result.success([_project(1)]);
    await built.container.read(projectsControllerProvider.future);

    final refreshCompleter = Completer<Result<List<Project>>>();
    built.repo.fetchResult = null;
    // Swap in a repository whose fetch call blocks so state can be
    // inspected mid-refresh.
    final controller = built.container.read(
      projectsControllerProvider.notifier,
    );
    built.repo.fetchResultFuture = refreshCompleter.future;
    final refreshFuture = controller.refresh();

    // Still showing the previous data while the new request is pending.
    final duringRefresh = built.container.read(projectsControllerProvider);
    expect(duringRefresh.value, hasLength(1));

    refreshCompleter.complete(Result.success([_project(1), _project(2)]));
    await refreshFuture;

    expect(
      built.container.read(projectsControllerProvider).value,
      hasLength(2),
    );
  });

  test(
    "an older in-flight refresh() does not clobber a newer one's result",
    () async {
      final built = build();
      built.repo.fetchResult = Result.success([_project(1)]);
      await built.container.read(projectsControllerProvider.future);
      final controller = built.container.read(
        projectsControllerProvider.notifier,
      );

      final firstCompleter = Completer<Result<List<Project>>>();
      built.repo.fetchResultFuture = firstCompleter.future;
      final firstRefresh = controller.refresh();

      final secondCompleter = Completer<Result<List<Project>>>();
      built.repo.fetchResultFuture = secondCompleter.future;
      final secondRefresh = controller.refresh();

      // The second (newer) request resolves first...
      secondCompleter.complete(Result.success([_project(1), _project(2)]));
      await secondRefresh;
      expect(
        built.container.read(projectsControllerProvider).value,
        hasLength(2),
      );

      // ...and the first (older, slower) request resolving afterwards must
      // not overwrite it with stale data.
      firstCompleter.complete(Result.success([_project(1)]));
      await firstRefresh;
      expect(
        built.container.read(projectsControllerProvider).value,
        hasLength(2),
      );
    },
  );
}
