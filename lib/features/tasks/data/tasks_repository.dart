import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/network_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/pagination/paginated_result.dart';
import '../../../core/result/result.dart';
import '../domain/task.dart';

abstract interface class TasksRepository {
  Future<Result<PaginatedResult<Task>>> fetchTasks({
    required int page,
    required int size,
    int? projectId,
    List<TaskStatus> statuses = activeTaskStatuses,
  });

  Future<Result<Task>> fetchTask(int id);
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
      decode: (data) => Task.fromJson(data as Map<String, dynamic>),
    );
  }
}

final tasksRepositoryProvider = Provider<TasksRepository>(
  (ref) => ApiTasksRepository(ref.watch(apiClientProvider)),
);
