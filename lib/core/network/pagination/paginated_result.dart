import 'package:freezed_annotation/freezed_annotation.dart';

import 'page_meta.dart';

part 'paginated_result.freezed.dart';

/// A page of items plus the metadata needed to fetch the next one —
/// screens consume this instead of loading an entire collection at once.
@freezed
abstract class PaginatedResult<T> with _$PaginatedResult<T> {
  const PaginatedResult._();

  const factory PaginatedResult({
    required List<T> items,
    required PageMeta meta,
  }) = _PaginatedResult<T>;

  bool get isEmpty => items.isEmpty;
}
