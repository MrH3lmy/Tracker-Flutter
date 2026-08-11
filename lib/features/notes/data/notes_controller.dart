import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/app_failure.dart';
import '../domain/note.dart';
import 'notes_repository.dart';

class NotesState {
  const NotesState({
    required this.notes,
    this.page = 0,
    this.hasNext = false,
    this.isLoadingMore = false,
    this.failure,
  });

  final List<Note> notes;
  final int page;
  final bool hasNext;
  final bool isLoadingMore;
  final AppFailure? failure;
}

class NotesController extends AsyncNotifier<NotesState> {
  static const pageSize = 50;

  @override
  Future<NotesState> build() => _load(0);

  Future<NotesState> _load(int page) async {
    final result = await ref.watch(notesRepositoryProvider).fetchNotes(
      page: page,
      size: pageSize,
    );
    return result.when(
      success: (notes) => NotesState(
        notes: List.unmodifiable(notes),
        page: page,
        hasNext: notes.length == pageSize,
      ),
      failure: (failure) => throw failure,
    );
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _load(0));
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasNext || current.isLoadingMore) return;
    state = AsyncValue.data(
      NotesState(
        notes: current.notes,
        page: current.page,
        hasNext: current.hasNext,
        isLoadingMore: true,
      ),
    );
    final result = await ref.read(notesRepositoryProvider).fetchNotes(
      page: current.page + 1,
      size: pageSize,
    );
    result.when(
      success: (notes) => state = AsyncValue.data(
        NotesState(
          notes: List.unmodifiable([...current.notes, ...notes]),
          page: current.page + 1,
          hasNext: notes.length == pageSize,
        ),
      ),
      failure: (failure) => state = AsyncValue.data(
        NotesState(
          notes: current.notes,
          page: current.page,
          hasNext: current.hasNext,
          failure: failure,
        ),
      ),
    );
  }
}

final notesControllerProvider = AsyncNotifierProvider.autoDispose<NotesController, NotesState>(
  NotesController.new,
  retry: (retryCount, error) => null,
);

class NoteDetailController extends AsyncNotifier<Note> {
  NoteDetailController(this.id);
  final int id;

  @override
  Future<Note> build() async {
    final result = await ref.read(notesRepositoryProvider).fetchNote(id);
    return result.when(success: (note) => note, failure: (failure) => throw failure);
  }

  void replace(Note note) => state = AsyncValue.data(note);
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(build);
  }
}

final noteDetailControllerProvider = AsyncNotifierProvider.family
    .autoDispose<NoteDetailController, Note, int>(
      NoteDetailController.new,
      retry: (retryCount, error) => null,
    );
