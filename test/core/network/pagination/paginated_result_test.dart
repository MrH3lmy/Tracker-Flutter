import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/network/pagination/page_meta.dart';
import 'package:tracker_flutter/core/network/pagination/paginated_result.dart';

void main() {
  const meta = PageMeta(
    page: 0,
    pageSize: 20,
    totalCount: 0,
    totalPages: 0,
    hasNext: false,
  );

  test('isEmpty reflects an empty items list', () {
    const result = PaginatedResult<String>(items: [], meta: meta);
    expect(result.isEmpty, isTrue);
  });

  test('isEmpty is false when items are present', () {
    const result = PaginatedResult<String>(items: ['a'], meta: meta);
    expect(result.isEmpty, isFalse);
  });
}
