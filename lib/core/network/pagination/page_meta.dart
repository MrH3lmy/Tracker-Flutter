import 'package:dio/dio.dart' show Headers;
import 'package:freezed_annotation/freezed_annotation.dart';

part 'page_meta.freezed.dart';

/// Parsed from Tracker-BE's pagination response headers
/// (`X-Total-Count`, `X-Total-Pages`, `X-Page`, `X-Page-Size`,
/// `X-Has-Next`), so feature code never reads raw headers itself.
@freezed
abstract class PageMeta with _$PageMeta {
  const factory PageMeta({
    required int page,
    required int pageSize,
    required int totalCount,
    required int totalPages,
    required bool hasNext,
  }) = _PageMeta;

  factory PageMeta.fromHeaders(Headers headers) {
    final totalCount = _int(headers, 'x-total-count', 0);
    final pageSize = _int(headers, 'x-page-size', 0);
    final page = _int(headers, 'x-page', 0);
    final totalPages = _int(
      headers,
      'x-total-pages',
      pageSize > 0 ? (totalCount / pageSize).ceil() : 0,
    );
    final hasNext = _bool(headers, 'x-has-next', page + 1 < totalPages);

    return PageMeta(
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
      totalPages: totalPages,
      hasNext: hasNext,
    );
  }

  static int _int(Headers headers, String key, int fallback) {
    final raw = headers.value(key);
    if (raw == null) return fallback;
    return int.tryParse(raw.trim()) ?? fallback;
  }

  static bool _bool(Headers headers, String key, bool fallback) {
    final raw = headers.value(key)?.trim().toLowerCase();
    return switch (raw) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => fallback,
    };
  }
}
