enum NoteContentType { plainText, markdown, shellCommands, xml, json, unknown }

class NoteAttachment {
  const NoteAttachment({
    required this.id,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.downloadUrl,
    this.caption,
  });

  factory NoteAttachment.fromJson(Map<String, dynamic> json) => NoteAttachment(
    id: (json['id'] as num).toInt(),
    fileName: json['fileName'] as String,
    contentType: json['contentType'] as String,
    sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
    downloadUrl: json['downloadUrl'] as String? ?? '',
    caption: json['caption'] as String?,
  );

  final int id;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String downloadUrl;
  final String? caption;
}

class Note {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.contentType,
    required this.tags,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
    this.taskId,
  });

  factory Note.fromJson(Map<String, dynamic> json) => Note(
    id: (json['id'] as num).toInt(),
    title: json['title'] as String,
    body: json['body'] as String,
    contentType: noteContentTypeFromApi(json['contentType'] as String?),
    taskId: (json['taskId'] as num?)?.toInt(),
    tags: ((json['tags'] as List?) ?? const []).whereType<String>().toList(),
    attachments: ((json['attachments'] as List?) ?? const [])
        .map((item) => NoteAttachment.fromJson(item as Map<String, dynamic>))
        .toList(),
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  final int id;
  final String title;
  final String body;
  final NoteContentType contentType;
  final int? taskId;
  final List<String> tags;
  final List<NoteAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class NoteWriteInput {
  const NoteWriteInput({
    required this.title,
    required this.body,
    required this.contentType,
    this.taskId,
    this.tags = const [],
  });

  final String title;
  final String body;
  final NoteContentType contentType;
  final int? taskId;
  final List<String> tags;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'body': body.trim(),
    'contentType': noteContentTypeApiValue(contentType),
    'taskId': taskId,
    'tags': tags,
  };
}

NoteContentType noteContentTypeFromApi(String? value) => switch (value) {
  'PLAIN_TEXT' => NoteContentType.plainText,
  'MARKDOWN' => NoteContentType.markdown,
  'SHELL_COMMANDS' => NoteContentType.shellCommands,
  'XML' => NoteContentType.xml,
  'JSON' => NoteContentType.json,
  _ => NoteContentType.unknown,
};

String noteContentTypeApiValue(NoteContentType value) => switch (value) {
  NoteContentType.plainText => 'PLAIN_TEXT',
  NoteContentType.markdown => 'MARKDOWN',
  NoteContentType.shellCommands => 'SHELL_COMMANDS',
  NoteContentType.xml => 'XML',
  NoteContentType.json => 'JSON',
  NoteContentType.unknown => 'PLAIN_TEXT',
};
