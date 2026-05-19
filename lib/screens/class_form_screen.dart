import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../models/teacher_class.dart';
import '../services/analytics_service.dart';
import '../services/date_helpers.dart';
import '../widgets/app_text_field.dart';

class ClassFormScreen extends StatefulWidget {
  const ClassFormScreen({super.key, this.teacherClass});

  final TeacherClass? teacherClass;

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _classNameController;
  late final TextEditingController _subjectController;
  late final TextEditingController _roomController;

  @override
  void initState() {
    super.initState();
    _classNameController =
        TextEditingController(text: widget.teacherClass?.className ?? '');
    _subjectController =
        TextEditingController(text: widget.teacherClass?.subject ?? '');
    _roomController =
        TextEditingController(text: widget.teacherClass?.roomNumber ?? '');
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _subjectController.dispose();
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final mediaPadding = MediaQuery.paddingOf(context);
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(kToolbarHeight + mediaPadding.top),
        child: SafeArea(
          bottom: false,
          child: AppBar(
            primary: false,
            title: Text(widget.teacherClass == null
                ? strings.addClassTitle
                : strings.editClassTitle),
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
              AppTextField(
                controller: _classNameController,
                label: strings.className,
                validator: (value) => value == null || value.trim().isEmpty
                    ? strings.classNameRequired
                    : null,
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
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
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
    AnalyticsService.logUiAction(screen: 'class_form', action: 'submit');
    final existing = widget.teacherClass;
    final item = TeacherClass(
      id: existing?.id ?? newId(),
      className: _classNameController.text.trim(),
      subject: _subjectController.text.trim(),
      roomNumber: _roomController.text.trim().isEmpty
          ? null
          : _roomController.text.trim(),
      createdAt: existing?.createdAt ?? DateTime.now(),
    );
    await context.read<AppController>().saveTeacherClass(item);
    if (mounted) Navigator.pop(context);
  }
}
