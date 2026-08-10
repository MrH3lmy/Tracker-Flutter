import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/network_providers.dart';
import '../../../core/error/app_failure.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/pagination/paginated_result.dart';
import '../../../core/result/result.dart';
import '../domain/task.dart';
import '../domain/task_write_input.dart';

class TaskCreateOutcome {
  const TaskCreateOutcome({
    required this.task,
    required this.projectAssignmentFailure,
  });

  final Task task;

  /// A task can be successfully created even if the follow-up project
  /// assignment fails, because Tracker-BE's CreateTaskRequest has no
  /// projectId. Treating that second failure as a failed POST would invite a
  /// duplicate task when the user retries.
  final AppFailure? projectAssignmentFailure;
}

abstract interface class TasksRepository {
  Future<Result<PaginatedResult<Task>>> fetchTasks({
    required int page,
    required int size,
    int? projectId,
    List<TaskStatus> statuses = activeTaskStatuses,
  });

  Future<Result<Task>> fetchTask(int id);

  Future<Result<TaskCreateOutcome>> createTask(
    TaskWriteInput input, {
    int? projectId,
  });

  Future<Result<Task>> updateTask(int id, TaskWriteInput input);
}

class ApiTasksRepository implements TasksRepository {
  ApiTasksRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<PaginatedResult<Task>>> fetchTasks({
    required int page,
    required int size,
    int? projectId,
    List<TaskStatus> statuses = activeTaskStatuses,
  }) {
    return _client.getPaginated<Task>(
      '/api/v1/tasks',
      queryParameters: {
        'page': page,
        'size': size,
        'projectId': ?projectId,
        if (statuses.isNotEmpty)
          'status': statuses.map(taskStatusApiValue).toList(growable: false),
      },
      decodeItem: (item) => Task.fromJson(item as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<Task>> fetchTask(int id) {
    return _client.get<Task>(
      '/api/v1/tasks/$id',
      decode: _decodeTask,
    );
  }

  @override
  Future<Result<TaskCreateOutcome>> createTask(
    TaskWriteInput input, {
    int? projectId,
  }) async {
    final createdResult = await _client.post<Task>(
      '/api/v1/tasks',
      data: input.toRequestJson(),
      decode: _decodeTask,
    );
    final created = createdResult.valueOrNull;
    if (created == null) {
      return Result.failure(createdResult.failureOrNull!);
    }

    if (projectId == null) {
      return Result.success(
        TaskCreateOutcome(task: created, projectAssignmentFailure: null),
      );
    }

    final projectResult = await _client.patch<Task>(
      '/api/v1/tasks/${created.id}/project',
      data: {'projectId': projectId},
      decode: _decodeTask,
    );

    final assigned = projectResult.valueOrNull;
    if (assigned != null) {
      return Result.success(
        TaskCreateOutcome(task: assigned, projectAssignmentFailure: null),
      );
    }

    return Result.success(
      TaskCreateOutcome(
        task: created,
        projectAssignmentFailure: projectResult.failureOrNull,
      ),
    );
  }

  @override
  Future<Result<Task>> updateTask(int id, TaskWriteInput input) {
    return _client.put<Task>(
      '/api/v1/tasks/$id',
      data: input.toRequestJson(),
      decode: _decodeTask,
    );
  }

  static Task _decodeTask(dynamic data) =>
      Task.fromJson(data as Map<String, dynamic>);
}

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => ApiTasksRepository(ref.watch(apiClientProvider)),
);
