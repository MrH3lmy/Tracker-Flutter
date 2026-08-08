import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/network_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/project.dart';

/// `GET /api/v1/projects` returns every project owned by the authenticated
/// user as a plain JSON array — Tracker-BE does not paginate, filter
/// archived projects, or guarantee an ordering for this endpoint (see
/// `ProjectService.findAll` / `ProjectRepository.findByUserId`), so this
/// repository doesn't invent any of those on the client side either.
abstract interface class ProjectsRepository {
  Future<Result<List<Project>>> fetchProjects();
}

class ApiProjectsRepository implements ProjectsRepository {
  ApiProjectsRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<Project>>> fetchProjects() {
    return _client.get<List<Project>>(
      '/api/v1/projects',
      decode: (data) {
        if (data is! List) {
          throw FormatException(
            'Expected a JSON array of projects, received ${data.runtimeType}.',
          );
        }
        return data
            .map((item) => Project.fromJson(item as Map<String, dynamic>))
            .toList(growable: false);
      },
    );
  }
}

final projectsRepositoryProvider = Provider<ProjectsRepository>(
  (ref) => ApiProjectsRepository(ref.watch(apiClientProvider)),
);
