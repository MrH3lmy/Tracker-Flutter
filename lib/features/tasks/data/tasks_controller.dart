import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/network/pagination/page_meta.dart';
import '../domain/task.dart';
import 'tasks_repository.dart';

typedef TaskListKey = ({int userId, int? projectId});
typedef TaskDetailKey = ({int userId, int taskId});

class TaskListState {
  const TaskListState({
    required this.tasks,
    required this.meta,
    this.isLoadingMore = false,
    this.loadMoreFailure,
  });

  final List<Task> tasks;
  final PageMeta meta;
  final bool isLoadingMore;
  final AppFailure? loadMoreFailure;

  bool get hasNext => meta.hasNext;
}

class TaskListController extends AsyncNotifier<TaskListState> {
  TaskListController(this.key);

  static const pageSize = 50;

  final TaskListKey key;
  int _requestId = 0;

  @override
  Future<TaskListState> build() => _loadFirstPage();

  Future<TaskListState> _loadFirstPage() async {
    final repository = ref.watch(tasksRepositoryProvider);
    final result = await repository.fetchTasks(
      page: 0,
      size: pageSize,
      projectId: key.projectId,
    );
    return result.when(
      success: (page) => TaskListState(
        tasks: List<Task>.unmodifiable(page.items),
        meta: page.meta,
      ),
      failure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    final requestId = ++_requestId;
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    final result = await AsyncValue.guard(_loadFirstPage);
    if (requestId == _requestId) {
      state = result;
    }
  }

  Future<void> loadNextPage() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.isLoadingMore) return;

    final requestId = ++_requestId;
    state = AsyncValue.data(
      TaskListState(
        tasks: current.tasks,
        meta: current.meta,
        isLoadingMore: true,
      ),
    );

    final repository = ref.read(tasksRepositoryProvider);
    final result = await repository.fetchTasks(
      page: current.meta.page + 1,
      size: pageSize,
      projectId: key.projectId,
    );

    if (requestId != _requestId) return;

    result.when(
      success: (page) {
        final byId = <int, Task>{
          for (final task in current.tasks) task.id: task,
        };
        for (final task in page.items) {
          byId[task.id] = task;
        }
        state = AsyncValue.data(
          TaskListState(
            tasks: List<Task>.unmodifiable(byId.values),
            meta: page.meta,
          ),
        );
      },
      failure: (failure) {
        state = AsyncValue.data(
          TaskListState(
            tasks: current.tasks,
            meta: current.meta,
            loadMoreFailure: failure,
          ),
        );
      },
    );
  }
}

final taskListControllerProvider = AsyncNotifierProvider.family
    .autoDispose<TaskListController, TaskListState, TaskListKey>(
      TaskListController.new,
      retry: (retryCount, error) => null,
    );

class TaskDetailController extends AsyncNotifier<Task> {
  TaskDetailController(this.key);

  final TaskDetailKey key;

  @override
  Future<Task> build() => _load();

  Future<Task> _load() async {
    final result = await ref.read(tasksRepositoryProvider).fetchTask(key.taskId);
    return result.when(
      success: (task) => task,
      failure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_load);
  }
}

final taskDetailControllerProvider = AsyncNotifierProvider.family
    .autoDispose<TaskDetailController, Task, TaskDetailKey>(
      TaskDetailController.new,
      retry: (retryCount, error) => null,
    );
