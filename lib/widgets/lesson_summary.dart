import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../models/lesson_record.dart';
import '../models/lesson_status.dart';
import '../models/session_type.dart';
import '../services/date_helpers.dart';
import 'info_chip.dart';

class LessonSummary extends StatelessWidget {
  const LessonSummary({
    super.key,
    required this.lesson,
  });

  final LessonRecord? lesson;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = AppStrings.of(context);
    if (lesson == null) {
      final theme = Theme.of(context);
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Text(
          strings.noLessonRecorded,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lesson!.lessonTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            InfoChip(
                label: lesson!.sessionType.label(controller.languageCode),
                icon: Icons.category_outlined),
            InfoChip(
                label: lesson!.status.label(controller.languageCode),
                icon: Icons.check_circle_outline),
            InfoChip(
                label:
                    formatLocalizedDate(lesson!.date, controller.languageCode),
                icon: Icons.event_outlined),
          ],
        ),
      ],
    );
  }
}
