import 'package:tracker_flutter/core/network/pagination/paginated_result.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';

typedef FetchTasksHandler = Future<Result<PaginatedResult<Task>>> Function({
  required int page,
  required int size,
  int? projectId,
  required List<TaskStatus> statuses,
});

class FakeTasksRepository implements TasksRepository {
  FetchTasksHandler? fetchTasksHandler;
  Future<Result<Task>> Function(int id)? fetchTaskHandler;

  int fetchTasksCalls = 0;
  int fetchTaskCalls = 0;
  int? lastProjectId;
  int? lastPage;
  int? lastSize;

  @override
  Future<Result<PaginatedResult<Task>>> fetchTasks({
    required int page,
    required int size,
    int? projectId,
    List<TaskStatus> statuses = activeTaskStatuses,
  }) {
    fetchTasksCalls++;
    lastProjectId = projectId;
    lastPage = page;
    lastSize = size;
    return fetchTasksHandler!(
      page: page,
      size: size,
      projectId: projectId,
      statuses: statuses,
    );
  }

  @override
  Future<Result<Task>> fetchTask(int id) {
    fetchTaskCalls++;
    return fetchTaskHandler!(id);
  }
}
