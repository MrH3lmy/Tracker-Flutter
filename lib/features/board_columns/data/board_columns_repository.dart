import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/network_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/board_column.dart';

/// `GET /api/v1/board-columns` returns the authenticated user's global
/// board-column layout — Tracker-BE provisions exactly one board per user
/// with no REST resource for the board itself (see
/// `BoardProvisioningService`), so there is no board id to pass and no
/// per-project scoping to apply here. The endpoint is not paginated and the
/// backend already orders the response by `position` ascending
/// (`findAllByUserIdOrderByPositionAsc`); this repository re-asserts that
/// order defensively rather than inventing a different one.
abstract interface class BoardColumnsRepository {
  Future<Result<List<BoardColumn>>> fetchColumns();
}

class ApiBoardColumnsRepository implements BoardColumnsRepository {
  ApiBoardColumnsRepository(this._client);

  final ApiClient _client;

  @override
  Future<Result<List<BoardColumn>>> fetchColumns() {
    return _client.get<List<BoardColumn>>(
      '/api/v1/board-columns',
      decode: (data) {
        if (data is! List) {
          throw FormatException(
            'Expected a JSON array of board columns, received ${data.runtimeType}.',
          );
        }
        final columns = data
            .map((item) => BoardColumn.fromJson(item as Map<String, dynamic>))
            .toList();
        columns.sort((a, b) => a.position.compareTo(b.position));
        return columns;
      },
    );
  }
}

final boardColumnsRepositoryProvider = Provider<BoardColumnsRepository>(
  (ref) => ApiBoardColumnsRepository(ref.watch(apiClientProvider)),
);
