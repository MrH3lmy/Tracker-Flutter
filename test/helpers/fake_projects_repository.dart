import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/projects/data/projects_repository.dart';
import 'package:tracker_flutter/features/projects/domain/project.dart';

class FakeProjectsRepository implements ProjectsRepository {
  Result<List<Project>>? fetchResult;

  /// Set instead of [fetchResult] to control exactly when a call resolves
  /// (e.g. to inspect state while a refresh is still in flight).
  Future<Result<List<Project>>>? fetchResultFuture;

  int fetchCalls = 0;

  @override
  Future<Result<List<Project>>> fetchProjects() async {
    fetchCalls++;
    if (fetchResultFuture != null) return fetchResultFuture!;
    return fetchResult!;
  }
}
