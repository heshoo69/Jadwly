import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../models/lesson_record.dart';
import '../models/lesson_status.dart';
import '../models/session_type.dart';
import '../models/teacher_class.dart';
import '../services/date_helpers.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_chip.dart';
import '../widgets/lesson_summary.dart';
import 'add_lesson_record_screen.dart';

const double _newLessonFabHeight = 56;
const double _newLessonFabBottomMargin = 16;
const double _newLessonListGap = 20;

class ClassDetailsScreen extends StatelessWidget {
  const ClassDetailsScreen({super.key, required this.teacherClass});

  final TeacherClass teacherClass;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    final lessons = controller.lessonsForClass(teacherClass.id);
    final latest = lessons.isEmpty ? null : lessons.first;
    final bottomListPadding = mediaPadding.bottom +
        _newLessonFabHeight +
        _newLessonFabBottomMargin +
        _newLessonListGap;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + mediaPadding.top),
        child: SafeArea(
          bottom: false,
          child: AppBar(
            primary: false,
            title: Text(teacherClass.className),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: EdgeInsetsDirectional.fromSTEB(
            16,
            16,
            16,
            bottomListPadding,
          ),
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
                              label:
                                  strings.room(teacherClass.roomNumber ?? ''),
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
              for (var index = 0; index < lessons.length; index++)
                _LessonHistoryItem(
                  lesson: lessons[index],
                  languageCode: controller.languageCode,
                  isFirst: index == 0,
                  isLast: index == lessons.length - 1,
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddLessonRecordScreen(
                        initialClassId: teacherClass.id,
                        lessonRecord: lessons[index],
                      ),
                    ),
                  ),
                  onDelete: () async {
                    final lesson = lessons[index];
                    final confirmed = await _confirmDeleteLesson(
                      context,
                      lesson.lessonTitle,
                    );
                    if (confirmed && context.mounted) {
                      await controller.deleteLesson(lesson.id);
                    }
                  },
                ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteLesson(
    BuildContext context,
    String lessonTitle,
  ) async {
    final strings = AppStrings.read(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.deleteLessonTitle),
        content: Text(strings.deleteLessonMessage(lessonTitle)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _LessonHistoryItem extends StatelessWidget {
  const _LessonHistoryItem({
    required this.lesson,
    required this.languageCode,
    required this.isFirst,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
  });

  final LessonRecord lesson;
  final String languageCode;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final timelineAccent = theme.colorScheme.primary.withValues(alpha: 0.9);
    final timelineTrack = theme.colorScheme.outlineVariant.withValues(
      alpha: 0.45,
    );
    final card = Expanded(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.lessonTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            formatLocalizedDate(lesson.date, languageCode),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      foregroundColor: theme.colorScheme.onSecondaryContainer,
                      child: const Icon(Icons.history_edu_outlined),
                    ),
                    PopupMenuButton<String>(
                      tooltip:
                          MaterialLocalizations.of(context).showMenuTooltip,
                      onSelected: (value) {
                        if (value == 'edit') {
                          onEdit();
                        } else if (value == 'delete') {
                          onDelete();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Text(AppStrings.read(context).editLesson),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(AppStrings.read(context).deleteLesson),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    InfoChip(
                      label: lesson.sessionType.label(languageCode),
                      icon: Icons.category_outlined,
                    ),
                    InfoChip(
                      label: lesson.status.label(languageCode),
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                ),
                if (lesson.notes.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    lesson.notes,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.55,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    final rail = SizedBox(
      width: 26,
      child: Padding(
        padding: EdgeInsets.only(bottom: isLast ? 14 : 0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: isFirst
                    ? const SizedBox(width: 3)
                    : Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: timelineTrack,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surface,
                border: Border.all(color: timelineAccent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: timelineAccent.withValues(alpha: 0.22),
                    blurRadius: 12,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: isLast
                    ? const SizedBox(width: 3)
                    : Container(
                        width: 3,
                        decoration: BoxDecoration(
                          color: timelineTrack,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
    final details = <Widget>[card, const SizedBox(width: 10), rail];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: isRtl ? details.reversed.toList() : details,
      ),
    );
  }
}
