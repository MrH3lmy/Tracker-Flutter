import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/network_providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/result/result.dart';
import '../domain/note.dart';

abstract interface class NotesRepository {
  Future<Result<List<Note>>> fetchNotes({required int page, required int size});
  Future<Result<Note>> fetchNote(int id);
  Future<Result<Note>> createNote(NoteWriteInput input);
  Future<Result<Note>> updateNote(int id, NoteWriteInput input);
  Future<Result<bool>> deleteNote(int id);
  Future<Result<NoteAttachment>> uploadScreenshot(
    int noteId, {
    required String fileName,
    required Uint8List bytes,
    String? caption,
  });
  Future<Result<Uint8List>> downloadScreenshot(int noteId, int attachmentId);
  Future<Result<bool>> deleteScreenshot(int noteId, int attachmentId);
}

class ApiNotesRepository implements NotesRepository {
  ApiNotesRepository(this._client);
  final ApiClient _client;

  @override
  Future<Result<List<Note>>> fetchNotes({required int page, required int size}) {
    return _client.get<List<Note>>(
      '/api/v1/notes',
      queryParameters: {'page': page, 'size': size, 'sortBy': 'updatedAt', 'sortDirection': 'desc'},
      decode: (data) => (data as List)
          .map((item) => Note.fromJson(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  @override
  Future<Result<Note>> fetchNote(int id) => _client.get<Note>(
    '/api/v1/notes/$id',
    decode: (data) => Note.fromJson(data as Map<String, dynamic>),
  );

  @override
  Future<Result<Note>> createNote(NoteWriteInput input) => _client.post<Note>(
    '/api/v1/notes',
    data: input.toJson(),
    decode: (data) => Note.fromJson(data as Map<String, dynamic>),
  );

  @override
  Future<Result<Note>> updateNote(int id, NoteWriteInput input) => _client.put<Note>(
    '/api/v1/notes/$id',
    data: input.toJson(),
    decode: (data) => Note.fromJson(data as Map<String, dynamic>),
  );

  @override
  Future<Result<bool>> deleteNote(int id) => _client.delete<bool>(
    '/api/v1/notes/$id',
    decode: (_) => true,
  );

  @override
  Future<Result<NoteAttachment>> uploadScreenshot(
    int noteId, {
    required String fileName,
    required Uint8List bytes,
    String? caption,
  }) {
    final extension = fileName.toLowerCase();
    final contentType = extension.endsWith('.png')
        ? DioMediaType('image', 'png')
        : extension.endsWith('.webp')
        ? DioMediaType('image', 'webp')
        : DioMediaType('image', 'jpeg');
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName, contentType: contentType),
      if (caption?.trim().isNotEmpty == true) 'caption': caption!.trim(),
      'source': 'tracker-flutter',
    });
    return _client.post<NoteAttachment>(
      '/api/v1/notes/$noteId/tools/screenshot',
      data: form,
      decode: (data) => NoteAttachment.fromJson(data as Map<String, dynamic>),
    );
  }

  @override
  Future<Result<Uint8List>> downloadScreenshot(int noteId, int attachmentId) async {
    final result = await _client.getBytes('/api/v1/notes/$noteId/screenshots/$attachmentId');
    return result.map((bytes) => Uint8List.fromList(bytes));
  }

  @override
  Future<Result<bool>> deleteScreenshot(int noteId, int attachmentId) =>
      _client.delete<bool>(
        '/api/v1/notes/$noteId/screenshots/$attachmentId',
        decode: (_) => true,
      );
}

final notesRepositoryProvider = Provider<NotesRepository>(
  (ref) => ApiNotesRepository(ref.watch(apiClientProvider)),
);
