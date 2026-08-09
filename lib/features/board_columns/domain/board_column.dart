/// Mirrors Tracker-BE's `Status` enum (`com.taskpriority.model.Status`).
/// [unknown] is a forward-compatibility fallback for a status value this
/// build doesn't recognize yet — see [BoardColumn.fromJson].
enum ColumnStatus {
  backlog,
  notStarted,
  inProgress,
  waiting,
  blocked,
  done,
  cancelled,
  unknown,
}

/// Mirrors Tracker-BE's `BoardColumnResponse` (`GET /api/v1/board-columns`)
/// field-for-field.
///
/// There is no `boardId` here on purpose: Tracker-BE provisions exactly one
/// board per user with no REST resource of its own (see
/// `BoardProvisioningService`) — a column belongs to *the* user, not to a
/// board the client ever sees or picks between. [position] is Tracker-BE's
/// own ordering key (the backend query is
/// `findAllByUserIdOrderByPositionAsc`); it's kept here so client code can
/// re-assert that order defensively rather than trusting on-the-wire
/// ordering to survive unchanged.
class BoardColumn {
  const BoardColumn({
    required this.id,
    required this.name,
    required this.status,
    required this.position,
  });

  factory BoardColumn.fromJson(Map<String, dynamic> json) {
    return BoardColumn(
      id: json['id'] as int,
      name: json['name'] as String,
      status: _statusFromJson(json['status'] as String?),
      position: json['position'] as int,
    );
  }

  final int id;
  final String name;
  final ColumnStatus status;
  final int position;

  static ColumnStatus _statusFromJson(String? raw) => switch (raw) {
    'BACKLOG' => ColumnStatus.backlog,
    'NOT_STARTED' => ColumnStatus.notStarted,
    'IN_PROGRESS' => ColumnStatus.inProgress,
    'WAITING' => ColumnStatus.waiting,
    'BLOCKED' => ColumnStatus.blocked,
    'DONE' => ColumnStatus.done,
    'CANCELLED' => ColumnStatus.cancelled,
    _ => ColumnStatus.unknown,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoardColumn &&
          other.id == id &&
          other.name == name &&
          other.status == status &&
          other.position == position);

  @override
  int get hashCode => Object.hash(id, name, status, position);

  @override
  String toString() =>
      'BoardColumn(id: $id, name: $name, status: $status, position: $position)';
}
