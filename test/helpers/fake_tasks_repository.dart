import 'package:tracker_flutter/core/network/pagination/paginated_result.dart';
import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/tasks/data/tasks_repository.dart';
import 'package:tracker_flutter/features/tasks/domain/task.dart';
import 'package:tracker_flutter/features/tasks/domain/task_write_input.dart';

typedef FetchTasksHandler =
    Future<Result<PaginatedResult<Task>>> Function({
      required int page,
      required int size,
      int? projectId,
      required List<TaskStatus> statuses,
    });

class FakeTasksRepository implements TasksRepository {
  FetchTasksHandler? fetchTasksHandler;
  Future<Result<Task>> Function(int id)? fetchTaskHandler;
  Future<Result<TaskCreateOutcome>> Function(
    TaskWriteInput input,
    int? projectId,
  )?
  createTaskHandler;
  Future<Result<Task>> Function(int id, TaskWriteInput input)?
  updateTaskHandler;

  int fetchTasksCalls = 0;
  int fetchTaskCalls = 0;
  int createTaskCalls = 0;
  int updateTaskCalls = 0;
  int? lastProjectId;
  int? lastPage;
  int? lastSize;
  TaskWriteInput? lastWriteInput;

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

  @override
  Future<Result<TaskCreateOutcome>> createTask(
    TaskWriteInput input, {
    int? projectId,
  }) {
    createTaskCalls++;
    lastWriteInput = input;
    lastProjectId = projectId;
    return createTaskHandler!(input, projectId);
  }

  @override
  Future<Result<Task>> updateTask(int id, TaskWriteInput input) {
    updateTaskCalls++;
    lastWriteInput = input;
    return updateTaskHandler!(id, input);
  }
}
