import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../models/schedule_item.dart';
import '../services/analytics_service.dart';
import '../services/date_helpers.dart';
import '../services/time_helpers.dart';
import '../widgets/app_text_field.dart';

class ScheduleFormScreen extends StatefulWidget {
  const ScheduleFormScreen({super.key, this.scheduleItem, this.initialDay});

  final ScheduleItem? scheduleItem;
  final int? initialDay;

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late int _dayOfWeek;
  String? _classId;
  late final TextEditingController _periodController;
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  late final TextEditingController _subjectController;
  late final TextEditingController _roomController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.scheduleItem;
    _dayOfWeek = item?.dayOfWeek ?? widget.initialDay ?? DateTime.now().weekday;
    _classId = item?.classId;
    _periodController = TextEditingController(
      text: (item?.periodNumber ?? 0) > 0 ? item!.periodNumber.toString() : '',
    );
    _startController = TextEditingController(
      text: item == null ? '' : normalizeClockTimeAmPm(item.startTime),
    );
    _endController = TextEditingController(
      text: item == null ? '' : normalizeClockTimeAmPm(item.endTime),
    );
    _subjectController = TextEditingController(text: item?.subject ?? '');
    _roomController = TextEditingController(text: item?.roomNumber ?? '');
  }

  @override
  void dispose() {
    _periodController.dispose();
    _startController.dispose();
    _endController.dispose();
    _subjectController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = AppStrings.of(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + mediaPadding.top),
        child: SafeArea(
          bottom: false,
          child: AppBar(
            primary: false,
            title: Text(widget.scheduleItem == null
                ? strings.addPeriod
                : strings.editPeriod),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              DropdownButtonFormField<int>(
                initialValue: _dayOfWeek,
                decoration: InputDecoration(
                    labelText: strings.day, border: const OutlineInputBorder()),
                items: orderedWeekDays
                    .map((day) => DropdownMenuItem(
                        value: day,
                        child: Text(
                            localizedDayName(day, controller.languageCode))))
                    .toList(),
                onChanged: (value) {
                  AnalyticsService.logFormFieldChanged(
                    form: 'schedule',
                    field: 'day',
                  );
                  setState(() => _dayOfWeek = value ?? _dayOfWeek);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _classId,
                decoration: InputDecoration(
                    labelText: strings.classLabel,
                    border: const OutlineInputBorder()),
                items: controller.classes
                    .map((item) => DropdownMenuItem(
                        value: item.id,
                        child: Text('${item.className} - ${item.subject}')))
                    .toList(),
                onChanged: (value) {
                  AnalyticsService.logFormFieldChanged(
                    form: 'schedule',
                    field: 'class',
                  );
                  final selected = controller.classById(value ?? '');
                  setState(() {
                    _classId = value;
                    if (selected != null) {
                      _subjectController.text = selected.subject;
                      _roomController.text = selected.roomNumber ?? '';
                    }
                  });
                },
                validator: (value) =>
                    value == null ? strings.selectClass : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _periodController,
                label: strings.periodNumberRequiredLabel,
                keyboardType: TextInputType.number,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) return strings.periodNumberRequired;
                  final periodNumber = int.tryParse(text);
                  if (periodNumber == null) return strings.invalidNumber;
                  if (periodNumber < 1 || periodNumber > 7) {
                    return strings.periodNumberOutOfRange;
                  }
                  final hasConflict = controller.hasSchedulePeriodConflict(
                    dayOfWeek: _dayOfWeek,
                    periodNumber: periodNumber,
                    excludeId: widget.scheduleItem?.id,
                  );
                  if (hasConflict) return strings.periodNumberAlreadyUsed;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _startController,
                readOnly: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: strings.startTime,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.schedule_outlined),
                ),
                onTap: () => _pickTime(
                  _startController,
                  field: 'start_time',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? strings.startTimeRequired
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _endController,
                readOnly: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: strings.endTime,
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.schedule_outlined),
                ),
                onTap: () => _pickTime(
                  _endController,
                  field: 'end_time',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return strings.endTimeRequired;
                  }
                  return _isEndTimeAfterStart()
                      ? null
                      : strings.endTimeMustBeAfterStartTime;
                },
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _subjectController,
                label: strings.subject,
                validator: (value) => value == null || value.trim().isEmpty
                    ? strings.subjectRequired
                    : null,
              ),
              const SizedBox(height: 12),
              AppTextField(
                  controller: _roomController, label: strings.roomOptional),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(strings.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    AnalyticsService.logUiAction(
      screen: 'schedule_form',
      action: 'submit',
    );
    setState(() => _isSaving = true);
    final existing = widget.scheduleItem;
    final periodText = _periodController.text.trim();
    final item = ScheduleItem(
      id: existing?.id ?? newId(),
      dayOfWeek: _dayOfWeek,
      periodNumber: int.parse(periodText),
      startTime: _startController.text.trim(),
      endTime: _endController.text.trim(),
      subject: _subjectController.text.trim(),
      classId: _classId!,
      roomNumber: _roomController.text.trim().isEmpty
          ? null
          : _roomController.text.trim(),
    );
    try {
      await context.read<AppController>().saveScheduleItem(item);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.read(context).savePeriodFailed)),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickTime(
    TextEditingController targetController, {
    required String field,
  }) async {
    AnalyticsService.logFormFieldChanged(
      form: 'schedule',
      field: field,
    );
    final parsed = parseClockTime(targetController.text);
    final initialTime = parsed == null
        ? TimeOfDay.now()
        : TimeOfDay(hour: parsed.hour, minute: parsed.minute);
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return Localizations.override(
          context: context,
          locale: const Locale('en'),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
    if (picked == null) return;
    targetController.text = formatClockTimeAmPm(picked.hour, picked.minute);
  }

  bool _isEndTimeAfterStart() {
    final start = parseClockTime(_startController.text);
    final end = parseClockTime(_endController.text);
    if (start == null || end == null) return true;

    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return endMinutes > startMinutes;
  }
}
