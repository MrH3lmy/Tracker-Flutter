import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/core/network/pagination/page_meta.dart';

void main() {
  group('PageMeta.fromHeaders', () {
    test('parses all pagination headers', () {
      final headers = Headers.fromMap({
        'x-total-count': ['42'],
        'x-total-pages': ['5'],
        'x-page': ['1'],
        'x-page-size': ['10'],
        'x-has-next': ['true'],
      });

      final meta = PageMeta.fromHeaders(headers);

      expect(meta.totalCount, 42);
      expect(meta.totalPages, 5);
      expect(meta.page, 1);
      expect(meta.pageSize, 10);
      expect(meta.hasNext, isTrue);
    });

    test('derives totalPages and hasNext when the backend omits them', () {
      final headers = Headers.fromMap({
        'x-total-count': ['25'],
        'x-page-size': ['10'],
        'x-page': ['0'],
      });

      final meta = PageMeta.fromHeaders(headers);

      expect(meta.totalPages, 3);
      expect(meta.hasNext, isTrue);
    });

    test('falls back to zeroed metadata when headers are entirely missing', () {
      final meta = PageMeta.fromHeaders(Headers());

      expect(meta.totalCount, 0);
      expect(meta.totalPages, 0);
      expect(meta.hasNext, isFalse);
    });

    test('is resilient to non-numeric header values', () {
      final headers = Headers.fromMap({
        'x-total-count': ['not-a-number'],
      });

      final meta = PageMeta.fromHeaders(headers);

      expect(meta.totalCount, 0);
    });

    test('derives hasNext when its header is malformed', () {
      final headers = Headers.fromMap({
        'x-total-count': ['25'],
        'x-page-size': ['10'],
        'x-page': ['0'],
        'x-has-next': ['not-a-boolean'],
      });

      final meta = PageMeta.fromHeaders(headers);

      expect(meta.hasNext, isTrue);
    });
  });
}
