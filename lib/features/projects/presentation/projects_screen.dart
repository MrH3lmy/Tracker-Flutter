import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/async_state_view.dart';
import '../../auth/data/auth_repository.dart';
import '../data/projects_controller.dart';
import '../data/selected_project_controller.dart';
import '../domain/project.dart';

class ProjectsScreen extends ConsumerWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(
      authRepositoryProvider.select((session) => session.userOrNull?.id),
    );

    // The router normally prevents this screen from existing without an
    // authenticated user. Keep a defensive loading boundary here too: it
    // avoids ever binding the UI to an account-less/global project cache
    // during restoration or a logout transition.
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final projectsProvider = projectsControllerProvider(userId);
    final projectsAsync = ref.watch(projectsProvider);
    final selectedId = ref.watch(selectedProjectControllerProvider);

    // Once the accessible project list is known, drop a selection that no
    // longer resolves against it (deletion, lost access, or a stale id
    // restored from a previous session) — a side effect, so it belongs in
    // ref.listen rather than in the build method below.
    //
    // Both the project list (a network fetch) and the selection (a
    // SharedPreferences read via SelectedProjectController's restoration)
    // load asynchronously and independently, so either can settle first:
    // listening only to the project list would miss pruning a selection
    // that gets restored *after* the list already loaded.
    void pruneAgainstCurrentList() {
      final projects = ref.read(projectsProvider).value;
      if (projects == null) return;
      ref
          .read(selectedProjectControllerProvider.notifier)
          .pruneIfMissing(projects.map((Project p) => p.id).toSet());
    }

    ref.listen<AsyncValue<List<Project>>>(
      projectsProvider,
      (previous, next) => pruneAgainstCurrentList(),
    );
    ref.listen<int?>(
      selectedProjectControllerProvider,
      (previous, next) => pruneAgainstCurrentList(),
    );

    return AsyncStateView<List<Project>>(
      value: projectsAsync,
      onRetry: () => ref.read(projectsProvider.notifier).refresh(),
      isEmpty: (projects) => projects.isEmpty,
      emptyBuilder: (context) => _RefreshableEmptyState(
        onRefresh: () => ref.read(projectsProvider.notifier).refresh(),
      ),
      data: (context, projects) => _ProjectList(
        projects: projects,
        selectedId: selectedId,
        onRefresh: () => ref.read(projectsProvider.notifier).refresh(),
        onSelect: (project) {
          ref
              .read(selectedProjectControllerProvider.notifier)
              .select(project.id);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text('${project.name} selected')));
        },
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({
    required this.projects,
    required this.selectedId,
    required this.onRefresh,
    required this.onSelect,
  });

  final List<Project> projects;
  final int? selectedId;
  final Future<void> Function() onRefresh;
  final ValueChanged<Project> onSelect;

  @override
  Widget build(BuildContext context) {
    // Tracker-BE doesn't guarantee an ordering for this endpoint (see
    // ProjectsRepository's doc comment), so this is a client-side choice
    // for a stable, predictable list rather than following a backend
    // contract that doesn't exist. Sort keys are computed once per project
    // rather than inside the comparator, which sort() calls O(n log n)
    // times.
    final sorted =
        [
          for (final project in projects)
            (key: project.name.toLowerCase(), project: project),
        ]..sort(
          (a, b) => a.key == b.key
              ? a.project.id.compareTo(b.project.id)
              : a.key.compareTo(b.key),
        );

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            itemCount: sorted.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) {
              final project = sorted[index].project;
              return _ProjectTile(
                project: project,
                selected: project.id == selectedId,
                onTap: () => onSelect(project),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProjectTile extends StatelessWidget {
  const _ProjectTile({
    required this.project,
    required this.selected,
    required this.onTap,
  });

  final Project project;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitleParts = <String>[
      _statusLabel(project.status),
      if (project.targetDate != null)
        'Target ${_formatDate(project.targetDate!)}',
    ];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(AppRadius.md),
        side: selected
            ? BorderSide(color: theme.colorScheme.primary, width: 2)
            : BorderSide.none,
      ),
      child: ListTile(
        selected: selected,
        title: Text(project.name),
        subtitle: Text(subtitleParts.join(' • ')),
        trailing: selected
            ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
            : null,
        onTap: onTap,
      ),
    );
  }

  static String _statusLabel(ProjectStatus status) => switch (status) {
    ProjectStatus.planning => 'Planning',
    ProjectStatus.active => 'Active',
    ProjectStatus.atRisk => 'At risk',
    ProjectStatus.onHold => 'On hold',
    ProjectStatus.done => 'Done',
    ProjectStatus.archived => 'Archived',
    ProjectStatus.unknown => 'Unknown status',
  };

  static String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

/// The empty state still needs to be scrollable (not just centered) for
/// [RefreshIndicator] to recognize a pull-to-refresh gesture with nothing
/// on screen to drag.
class _RefreshableEmptyState extends StatelessWidget {
  const _RefreshableEmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.folder_open_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.outline,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'No projects yet',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Projects you create in Tracker will show up here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
