import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../models/lesson_record.dart';
import '../models/lesson_status.dart';
import '../models/session_type.dart';
import '../services/date_helpers.dart';
import '../widgets/app_text_field.dart';

class AddLessonRecordScreen extends StatefulWidget {
  const AddLessonRecordScreen({super.key, this.initialClassId});

  final String? initialClassId;

  @override
  State<AddLessonRecordScreen> createState() => _AddLessonRecordScreenState();
}

class _AddLessonRecordScreenState extends State<AddLessonRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  String? _classId;
  SessionType _sessionType = SessionType.theoretical;
  LessonStatus _status = LessonStatus.completed;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _classId = widget.initialClassId;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = AppStrings.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.recordLesson)),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              initialValue: _classId,
              decoration: InputDecoration(
                labelText: strings.classLabel,
                border: const OutlineInputBorder(),
              ),
              items: controller.classes
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text('${item.className} - ${item.subject}'),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _classId = value),
              validator: (value) => value == null ? strings.selectClass : null,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _titleController,
              label: strings.lessonTitle,
              validator: (value) => value == null || value.trim().isEmpty
                  ? strings.lessonTitleRequired
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<SessionType>(
              initialValue: _sessionType,
              decoration: InputDecoration(
                labelText: strings.sessionType,
                border: const OutlineInputBorder(),
              ),
              items: SessionType.values
                  .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.label(controller.languageCode))))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _sessionType = value ?? _sessionType),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LessonStatus>(
              initialValue: _status,
              decoration: InputDecoration(
                labelText: strings.completionStatus,
                border: const OutlineInputBorder(),
              ),
              items: LessonStatus.values
                  .map((status) => DropdownMenuItem(
                      value: status,
                      child: Text(status.label(controller.languageCode))))
                  .toList(),
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 12),
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).colorScheme.outline),
              ),
              title: Text(strings.date),
              subtitle:
                  Text(formatLocalizedDate(_date, controller.languageCode)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDate,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _notesController,
              label: strings.notes,
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _save(controller),
              icon: const Icon(Icons.save_outlined),
              label: Text(strings.saveLesson),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save(AppController controller) async {
    if (!_formKey.currentState!.validate()) return;
    await controller.addLesson(
      LessonRecord(
        id: newId(),
        classId: _classId!,
        lessonTitle: _titleController.text.trim(),
        sessionType: _sessionType,
        notes: _notesController.text.trim(),
        status: _status,
        date: _date,
        createdAt: DateTime.now(),
      ),
    );
    if (mounted) Navigator.pop(context);
  }
}
