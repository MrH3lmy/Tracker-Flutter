import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../projects/data/selected_project_controller.dart';
import '../../tasks/presentation/task_form_screen.dart';
import '../../tasks/presentation/tasks_screen.dart';

/// Cross-feature composition belongs in the authenticated shell rather than
/// making the Tasks feature depend directly on Projects.
class TasksDestination extends ConsumerWidget {
  const TasksDestination({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      TasksScreen(projectId: ref.watch(selectedProjectControllerProvider));
}

class TaskCreateDestination extends ConsumerWidget {
  const TaskCreateDestination({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: Colors.transparent,
    child: TaskCreateScreen(
      projectId: ref.watch(selectedProjectControllerProvider),
    ),
  );
}
