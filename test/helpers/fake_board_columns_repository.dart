import 'package:tracker_flutter/core/result/result.dart';
import 'package:tracker_flutter/features/board_columns/data/board_columns_repository.dart';
import 'package:tracker_flutter/features/board_columns/domain/board_column.dart';

class FakeBoardColumnsRepository implements BoardColumnsRepository {
  Result<List<BoardColumn>>? fetchResult;

  /// Set instead of [fetchResult] to control exactly when a call resolves
  /// (e.g. to inspect state while a refresh is still in flight).
  Future<Result<List<BoardColumn>>>? fetchResultFuture;

  int fetchCalls = 0;

  @override
  Future<Result<List<BoardColumn>>> fetchColumns() async {
    fetchCalls++;
    if (fetchResultFuture != null) return fetchResultFuture!;
    return fetchResult!;
  }
}
