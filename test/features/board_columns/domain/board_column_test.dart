import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/features/board_columns/domain/board_column.dart';

Map<String, dynamic> _json({
  Object? id = 1,
  String name = 'Backlog',
  String? status = 'BACKLOG',
  Object? position = 1000,
}) => {'id': id, 'name': name, 'status': status, 'position': position};

void main() {
  group('BoardColumn.fromJson', () {
    test('parses a full response', () {
      final column = BoardColumn.fromJson(_json());

      expect(column.id, 1);
      expect(column.name, 'Backlog');
      expect(column.status, ColumnStatus.backlog);
      expect(column.position, 1000);
    });

    test('parses every backend status value', () {
      const mapping = {
        'BACKLOG': ColumnStatus.backlog,
        'NOT_STARTED': ColumnStatus.notStarted,
        'IN_PROGRESS': ColumnStatus.inProgress,
        'WAITING': ColumnStatus.waiting,
        'BLOCKED': ColumnStatus.blocked,
        'DONE': ColumnStatus.done,
        'CANCELLED': ColumnStatus.cancelled,
      };

      for (final entry in mapping.entries) {
        final column = BoardColumn.fromJson(_json(status: entry.key));
        expect(column.status, entry.value, reason: entry.key);
      }
    });

    test('an unrecognized status degrades to unknown instead of throwing', () {
      final column = BoardColumn.fromJson(_json(status: 'SOMETHING_NEW'));
      expect(column.status, ColumnStatus.unknown);
    });

    test('a missing status degrades to unknown', () {
      final column = BoardColumn.fromJson(_json(status: null));
      expect(column.status, ColumnStatus.unknown);
    });

    test('throws on a missing required field', () {
      final json = _json()..remove('name');
      expect(() => BoardColumn.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('equality and hashCode are value-based', () {
      final a = BoardColumn.fromJson(_json());
      final b = BoardColumn.fromJson(_json());
      final c = BoardColumn.fromJson(_json(name: 'Different'));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
