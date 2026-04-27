import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../widgets/empty_state.dart';
import '../widgets/lesson_summary.dart';
import 'class_details_screen.dart';
import 'class_form_screen.dart';

class ClassesScreen extends StatelessWidget {
  const ClassesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: controller.classes.isEmpty
          ? EmptyState(
              icon: Icons.groups_outlined,
              title: strings.noClasses,
              message: strings.noClassesMessage,
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: controller.classes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = controller.classes[index];
                final latest = controller.latestLessonForClass(item.id);
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ClassDetailsScreen(teacherClass: item)),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.groups_outlined,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.className,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w900),
                                  ),
                                  Text(
                                    item.subject,
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) async {
                                if (value == 'edit') {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => ClassFormScreen(
                                            teacherClass: item)),
                                  );
                                } else if (value == 'delete') {
                                  final confirmed = await _confirmDeleteClass(
                                    context,
                                    item.className,
                                  );
                                  if (confirmed && context.mounted) {
                                    controller.deleteTeacherClass(item.id);
                                  }
                                }
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'edit', child: Text(strings.edit)),
                                PopupMenuItem(
                                    value: 'delete',
                                    child: Text(strings.delete)),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 28),
                        LessonSummary(lesson: latest),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ClassFormScreen()),
        ),
        icon: const Icon(Icons.add),
        label: Text(strings.addClass),
      ),
    );
  }

  Future<bool> _confirmDeleteClass(
    BuildContext context,
    String className,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.of(context).confirmDelete),
        content: Text(
          AppStrings.of(context).deleteClassMessage(className),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.of(context).cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.of(context).delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
