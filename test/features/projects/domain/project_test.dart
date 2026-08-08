import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_flutter/features/projects/domain/project.dart';

Map<String, dynamic> _json({
  Object? id = 1,
  String name = 'Website relaunch',
  String? description = 'Ship the new site',
  String? status = 'ACTIVE',
  String? startDate = '2026-01-01',
  String? targetDate = '2026-06-01',
  String? area = 'WORK',
  String? goal = 'Ship it',
  Object? ownerUserId = 7,
  String createdDate = '2026-01-01T10:15:30',
}) => {
  'id': id,
  'name': name,
  'description': description,
  'status': status,
  'startDate': startDate,
  'targetDate': targetDate,
  'area': area,
  'goal': goal,
  'ownerUserId': ownerUserId,
  'createdDate': createdDate,
};

void main() {
  group('Project.fromJson', () {
    test('parses a full response', () {
      final project = Project.fromJson(_json());

      expect(project.id, 1);
      expect(project.name, 'Website relaunch');
      expect(project.description, 'Ship the new site');
      expect(project.status, ProjectStatus.active);
      expect(project.startDate, DateTime.parse('2026-01-01'));
      expect(project.targetDate, DateTime.parse('2026-06-01'));
      expect(project.area, ProjectArea.work);
      expect(project.goal, 'Ship it');
      expect(project.ownerUserId, 7);
      expect(project.createdDate, DateTime.parse('2026-01-01T10:15:30'));
    });

    test('parses every backend status value', () {
      const mapping = {
        'PLANNING': ProjectStatus.planning,
        'ACTIVE': ProjectStatus.active,
        'AT_RISK': ProjectStatus.atRisk,
        'ON_HOLD': ProjectStatus.onHold,
        'DONE': ProjectStatus.done,
        'ARCHIVED': ProjectStatus.archived,
      };

      for (final entry in mapping.entries) {
        final project = Project.fromJson(_json(status: entry.key));
        expect(project.status, entry.value, reason: entry.key);
      }
    });

    test('an unrecognized status degrades to unknown instead of throwing', () {
      final project = Project.fromJson(_json(status: 'SOMETHING_NEW'));
      expect(project.status, ProjectStatus.unknown);
    });

    test('a missing status degrades to unknown', () {
      final project = Project.fromJson(_json(status: null));
      expect(project.status, ProjectStatus.unknown);
    });

    test('an unrecognized area degrades to null instead of throwing', () {
      final project = Project.fromJson(_json(area: 'SOMETHERE_NEW'));
      expect(project.area, isNull);
    });

    test('nullable fields are genuinely optional', () {
      final project = Project.fromJson(
        _json(
          description: null,
          startDate: null,
          targetDate: null,
          area: null,
          goal: null,
        ),
      );

      expect(project.description, isNull);
      expect(project.startDate, isNull);
      expect(project.targetDate, isNull);
      expect(project.area, isNull);
      expect(project.goal, isNull);
    });

    test('throws on a missing required field', () {
      final json = _json()..remove('name');
      expect(() => Project.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('equality and hashCode are value-based', () {
      final a = Project.fromJson(_json());
      final b = Project.fromJson(_json());
      final c = Project.fromJson(_json(name: 'Different'));

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
