/// Mirrors Tracker-BE's `ProjectStatus` enum. [unknown] is a forward-
/// compatibility fallback for a status value the backend has added but this
/// build doesn't recognize yet — see [Project.fromJson].
enum ProjectStatus { planning, active, atRisk, onHold, done, archived, unknown }

/// Mirrors Tracker-BE's `Area` enum. Unrecognized values degrade to `null`
/// (see [Project.fromJson]) rather than needing an `unknown` case, since the
/// field is already optional both in the backend model and here.
enum ProjectArea { work, study, personal, health, family }

/// Mirrors Tracker-BE's `ProjectResponse` (`GET /api/v1/projects`,
/// `GET /api/v1/projects/{id}`). The backend scopes every project to the
/// authenticated user server-side — there is no client-visible ownership or
/// sharing model yet, so `ownerUserId` here is informational only.
class Project {
  const Project({
    required this.id,
    required this.name,
    required this.description,
    required this.status,
    required this.startDate,
    required this.targetDate,
    required this.area,
    required this.goal,
    required this.ownerUserId,
    required this.createdDate,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      status: _statusFromJson(json['status'] as String?),
      startDate: _dateFromJson(json['startDate'] as String?),
      targetDate: _dateFromJson(json['targetDate'] as String?),
      area: _areaFromJson(json['area'] as String?),
      goal: json['goal'] as String?,
      ownerUserId: json['ownerUserId'] as int,
      createdDate: DateTime.parse(json['createdDate'] as String),
    );
  }

  final int id;
  final String name;
  final String? description;
  final ProjectStatus status;
  final DateTime? startDate;
  final DateTime? targetDate;
  final ProjectArea? area;
  final String? goal;
  final int ownerUserId;
  final DateTime createdDate;

  static ProjectStatus _statusFromJson(String? raw) => switch (raw) {
    'PLANNING' => ProjectStatus.planning,
    'ACTIVE' => ProjectStatus.active,
    'AT_RISK' => ProjectStatus.atRisk,
    'ON_HOLD' => ProjectStatus.onHold,
    'DONE' => ProjectStatus.done,
    'ARCHIVED' => ProjectStatus.archived,
    _ => ProjectStatus.unknown,
  };

  static ProjectArea? _areaFromJson(String? raw) => switch (raw) {
    'WORK' => ProjectArea.work,
    'STUDY' => ProjectArea.study,
    'PERSONAL' => ProjectArea.personal,
    'HEALTH' => ProjectArea.health,
    'FAMILY' => ProjectArea.family,
    _ => null,
  };

  static DateTime? _dateFromJson(String? raw) =>
      raw == null ? null : DateTime.parse(raw);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Project &&
          other.id == id &&
          other.name == name &&
          other.description == description &&
          other.status == status &&
          other.startDate == startDate &&
          other.targetDate == targetDate &&
          other.area == area &&
          other.goal == goal &&
          other.ownerUserId == ownerUserId &&
          other.createdDate == createdDate);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    description,
    status,
    startDate,
    targetDate,
    area,
    goal,
    ownerUserId,
    createdDate,
  );

  @override
  String toString() => 'Project(id: $id, name: $name, status: $status)';
}
