import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../models/lesson_status.dart';
import '../models/session_type.dart';
import '../models/teacher_class.dart';
import '../services/date_helpers.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_chip.dart';
import '../widgets/lesson_summary.dart';
import 'add_lesson_record_screen.dart';

class ClassDetailsScreen extends StatelessWidget {
  const ClassDetailsScreen({super.key, required this.teacherClass});

  final TeacherClass teacherClass;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final lessons = controller.lessonsForClass(teacherClass.id);
    final latest = lessons.isEmpty ? null : lessons.first;

    return Scaffold(
      appBar: AppBar(title: Text(teacherClass.className)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                AddLessonRecordScreen(initialClassId: teacherClass.id),
          ),
        ),
        icon: const Icon(Icons.add),
        label: Text(strings.newLesson),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.school_outlined,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              teacherClass.subject,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              teacherClass.className,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      InfoChip(
                          label: teacherClass.className,
                          icon: Icons.groups_outlined),
                      if ((teacherClass.roomNumber ?? '').isNotEmpty)
                        InfoChip(
                            label: strings.room(teacherClass.roomNumber ?? ''),
                            icon: Icons.meeting_room_outlined),
                    ],
                  ),
                  const Divider(height: 28),
                  Text(
                    strings.lastLesson,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LessonSummary(lesson: latest),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            strings.lessonHistory,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          if (lessons.isEmpty)
            SizedBox(
              height: 260,
              child: EmptyState(
                icon: Icons.history_edu_outlined,
                title: strings.noLessons,
                message: strings.noLessonsMessage,
              ),
            )
          else
            ...lessons.map(
              (lesson) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    foregroundColor: theme.colorScheme.onSecondaryContainer,
                    child: const Icon(Icons.history_edu_outlined),
                  ),
                  title: Text(
                    lesson.lessonTitle,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                      '${formatLocalizedDate(lesson.date, controller.languageCode)}\n${lesson.notes}'),
                  isThreeLine: lesson.notes.isNotEmpty,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(lesson.sessionType.label(controller.languageCode)),
                      Text(
                        lesson.status.label(controller.languageCode),
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
