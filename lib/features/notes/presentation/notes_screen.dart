import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_state_view.dart';
import '../data/notes_controller.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';

class NotesScreen extends ConsumerWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = notesControllerProvider;
    return AsyncStateView<NotesState>(
      value: ref.watch(provider),
      onRetry: () => ref.read(provider.notifier).refresh(),
      data: (context, state) => RefreshIndicator(
        onRefresh: () => ref.read(provider.notifier).refresh(),
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: state.notes.length + 2,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Row(
                children: [
                  Expanded(
                    child: Text('Notes', style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.go('/notes/new'),
                    icon: const Icon(Icons.add),
                    label: const Text('New note'),
                  ),
                ],
              );
            }
            if (index == state.notes.length + 1) {
              if (state.isLoadingMore) {
                return const Center(child: CircularProgressIndicator());
              }
              if (state.failure != null) {
                return Center(
                  child: OutlinedButton(
                    onPressed: () => ref.read(provider.notifier).loadMore(),
                    child: const Text('Try again'),
                  ),
                );
              }
              return state.hasNext
                  ? Center(
                      child: FilledButton.tonal(
                        onPressed: () => ref.read(provider.notifier).loadMore(),
                        child: const Text('Load more'),
                      ),
                    )
                  : const SizedBox(height: AppSpacing.md);
            }
            final note = state.notes[index - 1];
            return Card(
              child: ListTile(
                title: Text(note.title),
                subtitle: Text(
                  note.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: note.attachments.isEmpty
                    ? const Icon(Icons.chevron_right)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.attachment, size: 18),
                          Text('${note.attachments.length}'),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                onTap: () => context.push('/notes/${note.id}'),
              ),
            );
          },
        ),
      ),
    );
  }
}

class NoteDetailScreen extends ConsumerWidget {
  const NoteDetailScreen({super.key, required this.noteId});
  final int noteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = noteDetailControllerProvider(noteId);
    return AsyncStateView<Note>(
      value: ref.watch(provider),
      onRetry: () => ref.read(provider.notifier).refresh(),
      data: (context, note) => ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back to notes',
                onPressed: () => context.go('/notes'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(note.title, style: Theme.of(context).textTheme.headlineSmall),
              ),
              IconButton(
                tooltip: 'Edit note',
                onPressed: () => context.go('/notes/${note.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete note',
                onPressed: () async {
                  final result = await ref.read(notesRepositoryProvider).deleteNote(note.id);
                  if (context.mounted && result.valueOrNull == true) {
                    ref.invalidate(notesControllerProvider);
                    context.go('/notes');
                  }
                },
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SelectableText(note.body),
          if (note.tags.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(spacing: AppSpacing.xs, children: [for (final tag in note.tags) Chip(label: Text(tag))]),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text('Attachments', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: () => _pickAndUpload(context, ref, note),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Add image'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final attachment in note.attachments)
            Card(
              child: ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(attachment.fileName),
                subtitle: Text(attachment.caption ?? attachment.contentType),
                onTap: () => _preview(context, ref, note.id, attachment),
                trailing: IconButton(
                  tooltip: 'Delete attachment',
                  onPressed: () async {
                    final result = await ref
                        .read(notesRepositoryProvider)
                        .deleteScreenshot(note.id, attachment.id);
                    if (result.valueOrNull == true) {
                      ref.invalidate(provider);
                      ref.invalidate(notesControllerProvider);
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickAndUpload(BuildContext context, WidgetRef ref, Note note) async {
    final picked = await FilePicker.pickFiles(type: FileType.image, withData: true);
    final file = picked?.files.singleOrNull;
    if (file?.bytes == null) return;
    final result = await ref.read(notesRepositoryProvider).uploadScreenshot(
      note.id,
      fileName: file!.name,
      bytes: file.bytes!,
    );
    if (context.mounted && result.valueOrNull != null) {
      ref.invalidate(noteDetailControllerProvider(note.id));
      ref.invalidate(notesControllerProvider);
    }
  }

  Future<void> _preview(
    BuildContext context,
    WidgetRef ref,
    int noteId,
    NoteAttachment attachment,
  ) async {
    final result = await ref
        .read(notesRepositoryProvider)
        .downloadScreenshot(noteId, attachment.id);
    final bytes = result.valueOrNull;
    if (!context.mounted || bytes == null) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.memory(bytes, semanticLabel: attachment.fileName),
        ),
      ),
    );
  }
}

class NoteFormScreen extends ConsumerStatefulWidget {
  const NoteFormScreen({super.key, this.noteId});
  final int? noteId;

  @override
  ConsumerState<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends ConsumerState<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _tags = TextEditingController();
  NoteContentType _type = NoteContentType.plainText;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.noteId;
    if (id != null) {
      final detail = ref.watch(noteDetailControllerProvider(id));
      if (detail.isLoading) return const Center(child: CircularProgressIndicator());
      final note = detail.value;
      if (note == null) return const Center(child: Text('Could not load note.'));
      if (!_initialized) {
        _initialized = true;
        _title.text = note.title;
        _body.text = note.body;
        _tags.text = note.tags.join(', ');
        _type = note.contentType == NoteContentType.unknown ? NoteContentType.plainText : note.contentType;
      }
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _saving ? null : () => context.go(id == null ? '/notes' : '/notes/$id'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(id == null ? 'New note' : 'Edit note', style: Theme.of(context).textTheme.headlineSmall),
              ),
            ],
          ),
          TextFormField(
            controller: _title,
            maxLength: 255,
            decoration: const InputDecoration(labelText: 'Title'),
            validator: (value) => value == null || value.trim().isEmpty ? 'Title is required' : null,
          ),
          TextFormField(
            controller: _body,
            minLines: 8,
            maxLines: 20,
            decoration: const InputDecoration(labelText: 'Body'),
            validator: (value) => value == null || value.trim().isEmpty ? 'Body is required' : null,
          ),
          DropdownButtonFormField<NoteContentType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Content type'),
            items: [
              for (final type in NoteContentType.values.where((type) => type != NoteContentType.unknown))
                DropdownMenuItem(value: type, child: Text(noteContentTypeApiValue(type))),
            ],
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
          TextFormField(
            controller: _tags,
            decoration: const InputDecoration(labelText: 'Tags', hintText: 'backend, urgent, idea'),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(id == null ? 'Create note' : 'Save changes'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final input = NoteWriteInput(
      title: _title.text,
      body: _body.text,
      contentType: _type,
      tags: _tags.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).take(20).toList(),
    );
    final repository = ref.read(notesRepositoryProvider);
    final result = widget.noteId == null
        ? await repository.createNote(input)
        : await repository.updateNote(widget.noteId!, input);
    if (!mounted) return;
    setState(() => _saving = false);
    final note = result.valueOrNull;
    if (note != null) {
      ref.invalidate(notesControllerProvider);
      ref.read(noteDetailControllerProvider(note.id).notifier).replace(note);
      context.go('/notes/${note.id}');
    }
  }
}
