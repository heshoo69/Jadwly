import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../models/schedule_item.dart';
import '../services/date_helpers.dart';
import '../widgets/bottom_navigation_clearance.dart';
import '../widgets/empty_state.dart';
import 'schedule_form_screen.dart';

class WeeklyScheduleScreen extends StatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  int _selectedDay = DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = AppStrings.of(context);
    final isWeeklyGrid = controller.scheduleViewMode == 'weeklyGrid';
    final fabOffset = BottomNavigationClearance.forFab(context);

    return Scaffold(
      body: Column(
        children: [
          _ScheduleHeader(
            title:
                isWeeklyGrid ? strings.weeklySchedule : strings.dailySchedule,
            subtitle: isWeeklyGrid
                ? strings.appName
                : localizedDayName(_selectedDay, controller.languageCode),
            isWeeklyGrid: isWeeklyGrid,
            onToggle: () => controller.setScheduleViewMode(
              isWeeklyGrid ? 'dailyList' : 'weeklyGrid',
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: isWeeklyGrid
                  ? const _WeeklyGridView(key: ValueKey('grid'))
                  : _DailyListView(
                      key: const ValueKey('daily'),
                      selectedDay: _selectedDay,
                      onDayChanged: (day) => setState(() => _selectedDay = day),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: fabOffset),
        child: FloatingActionButton(
          tooltip: strings.addScheduleItem,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ScheduleFormScreen(
                initialDay:
                    isWeeklyGrid ? DateTime.now().weekday : _selectedDay,
              ),
            ),
          ),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class _ScheduleHeader extends StatelessWidget {
  const _ScheduleHeader({
    required this.title,
    required this.subtitle,
    required this.isWeeklyGrid,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final bool isWeeklyGrid;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.22),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Tooltip(
              message:
                  isWeeklyGrid ? strings.switchToDaily : strings.switchToWeekly,
              child: IconButton.filled(
                onPressed: onToggle,
                icon: Icon(isWeeklyGrid
                    ? Icons.view_agenda_outlined
                    : Icons.grid_view_outlined),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyGridView extends StatelessWidget {
  const _WeeklyGridView({super.key});

  static const _periodColumns = [1, 2, 3, 4, 5, 6, 7];

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final days = controller.visibleWeekDays;
    final bottomClearance = BottomNavigationClearance.of(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 16 + bottomClearance),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 104),
                    ..._periodColumns.map(
                      (period) => _GridHeaderCell(period: period),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...days.map(
                  (day) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        _DayCell(day: day),
                        ..._periodColumns.map((period) {
                          final item = _itemFor(controller, day, period);
                          return _ScheduleGridCell(
                            item: item,
                            onTap: item == null
                                ? null
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ScheduleFormScreen(
                                          scheduleItem: item,
                                        ),
                                      ),
                                    ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          strings.emptyGridNote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  ScheduleItem? _itemFor(AppController controller, int day, int period) {
    for (final item in controller.scheduleForDay(day)) {
      if (item.periodNumber == period) return item;
    }
    return null;
  }
}

class _GridHeaderCell extends StatelessWidget {
  const _GridHeaderCell({required this.period});

  final int period;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 132,
      height: 74,
      margin: const EdgeInsetsDirectional.only(start: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.28)),
      ),
      child: Center(
        child: Text(
          period.toString(),
          style: theme.textTheme.headlineSmall?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({required this.day});

  final int day;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final theme = Theme.of(context);
    return Container(
      width: 104,
      height: 132,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.25)),
      ),
      child: Center(
        child: Text(
          localizedDayName(day, controller.languageCode),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ScheduleGridCell extends StatelessWidget {
  const _ScheduleGridCell({
    required this.item,
    required this.onTap,
  });

  final ScheduleItem? item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final theme = Theme.of(context);
    final itemValue = item;
    final teacherClass =
        itemValue == null ? null : controller.classById(itemValue.classId);
    final hasItem = itemValue != null;

    final content = Ink(
      width: 132,
      height: 132,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: hasItem
            ? LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.22),
                  theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.76),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              )
            : null,
        color:
            hasItem ? null : theme.colorScheme.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasItem
              ? theme.colorScheme.primary.withValues(alpha: 0.48)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.22),
        ),
        boxShadow: hasItem
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                )
              ]
            : null,
      ),
      child: hasItem
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 106,
                      child: Text(
                        itemValue.subject,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  flex: 2,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 106,
                      child: Text(
                        teacherClass?.className ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${itemValue.startTime} - ${itemValue.endTime}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Icon(
                  Icons.edit_outlined,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
              ],
            )
          : const SizedBox.shrink(),
    );

    return Container(
      margin: const EdgeInsetsDirectional.only(start: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Tooltip(
          message: hasItem ? AppStrings.of(context).editPeriod : '',
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: content,
          ),
        ),
      ),
    );
  }
}

class _DailyListView extends StatelessWidget {
  const _DailyListView({
    super.key,
    required this.selectedDay,
    required this.onDayChanged,
  });

  final int selectedDay;
  final ValueChanged<int> onDayChanged;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final days = controller.visibleWeekDays;
    final effectiveDay =
        days.contains(selectedDay) || days.isEmpty ? selectedDay : days.first;
    final items = controller.scheduleForDay(effectiveDay);
    final bottomClearance = BottomNavigationClearance.of(context);

    return Column(
      children: [
        SizedBox(
          height: 66,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final day = days[index];
              return ChoiceChip(
                label: Text(localizedDayName(day, controller.languageCode)),
                selected: effectiveDay == day,
                showCheckmark: false,
                onSelected: (_) => onDayChanged(day),
              );
            },
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Padding(
                  padding: EdgeInsets.only(bottom: bottomClearance),
                  child: EmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: strings.noPeriods,
                    message: strings.noPeriodsForDay(
                      localizedDayName(effectiveDay, controller.languageCode),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    16 + bottomClearance,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final teacherClass = controller.classById(item.classId);
                    return _ScheduleListCard(
                      item: item,
                      className:
                          teacherClass?.className ?? strings.deletedClass,
                      theme: theme,
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _ScheduleListCard extends StatelessWidget {
  const _ScheduleListCard({
    required this.item,
    required this.className,
    required this.theme,
  });

  final ScheduleItem item;
  final String className;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 74,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  item.periodNumber > 0
                      ? strings.periodNumber(item.periodNumber)
                      : strings.period,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Icon(
                  Icons.schedule_outlined,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.subject,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  className,
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.startTime} - ${item.endTime}'
                  '${(item.roomNumber ?? '').isEmpty ? '' : ' | ${strings.room(item.roomNumber ?? '')}'}',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
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
                    builder: (_) => ScheduleFormScreen(scheduleItem: item),
                  ),
                );
              } else if (value == 'delete') {
                final confirmed = await _confirmDeleteScheduleItem(
                  context,
                  item.periodNumber > 0
                      ? strings.periodNumber(item.periodNumber)
                      : strings.thisPeriod,
                );
                if (confirmed && context.mounted) {
                  context.read<AppController>().deleteScheduleItem(item.id);
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(value: 'edit', child: Text(strings.edit)),
              PopupMenuItem(value: 'delete', child: Text(strings.delete)),
            ],
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDeleteScheduleItem(
    BuildContext context,
    String itemLabel,
  ) async {
    final strings = AppStrings.read(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.confirmDelete),
        content: Text(strings.deletePeriodMessage(itemLabel)),
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
