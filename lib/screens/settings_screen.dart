import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../services/date_helpers.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final name = context.watch<AppController>().teacherName;
    if (_nameController.text != name) _nameController.text = name;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = AppStrings(controller.languageCode);
    final theme = Theme.of(context);
    const weekStartOptions = [
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SettingsSection(
          title: strings.account,
          child: Column(
            children: [
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: strings.teacherName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                onSubmitted: controller.saveTeacherName,
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () =>
                      controller.saveTeacherName(_nameController.text),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(strings.saveName),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: strings.preferences,
          child: ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(strings.language),
            subtitle: Text(
              controller.languageCode == 'en'
                  ? strings.english
                  : strings.arabic,
            ),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => _chooseLanguage(context, controller),
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: strings.weekSettings,
          child: Column(
            children: [
              DropdownButtonFormField<int>(
                initialValue: controller.weekStartDay,
                decoration: InputDecoration(
                  labelText: strings.weekStart,
                  prefixIcon: const Icon(Icons.calendar_view_week_outlined),
                ),
                items: weekStartOptions
                    .map(
                      (day) => DropdownMenuItem(
                        value: day,
                        child: Text(
                          localizedDayName(day, controller.languageCode),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) controller.setWeekStartDay(value);
                },
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                secondary: const Icon(Icons.weekend_outlined),
                title: Text(strings.showWeekends),
                subtitle: Text(strings.showWeekendsHelp),
                value: controller.showWeekends,
                onChanged: controller.setShowWeekends,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: strings.notifications,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: Text(strings.enableClassReminders),
                subtitle: Text(strings.remindersHelp),
                value: controller.notificationsEnabled,
                onChanged: (value) =>
                    _toggleNotifications(context, controller, value),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: controller.reminderMinutes,
                decoration: InputDecoration(
                  labelText: strings.reminderTime,
                  prefixIcon: const Icon(Icons.timer_outlined),
                ),
                items: [
                  DropdownMenuItem(value: 5, child: Text(strings.minutes(5))),
                  DropdownMenuItem(value: 10, child: Text(strings.minutes(10))),
                  DropdownMenuItem(value: 15, child: Text(strings.minutes(15))),
                  DropdownMenuItem(value: 30, child: Text(strings.minutes(30))),
                ],
                onChanged: (value) {
                  if (value != null) controller.setReminderMinutes(value);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: strings.data,
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: controller.addDemoData,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(strings.addDemoData),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                  ),
                  onPressed: () => _confirmClear(context, controller),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(strings.clearLocalData),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SettingsSection(
          title: strings.openDeveloperSite,
          child: ListTile(
            leading: const Icon(Icons.code_outlined),
            title: Text(strings.developedBy),
            subtitle: const Text('haf-dev.com'),
            trailing: const Icon(Icons.open_in_new_outlined),
            onTap: () => _openDeveloperSite(context),
          ),
        ),
      ],
    );
  }

  Future<void> _openDeveloperSite(BuildContext context) async {
    final uri = Uri.parse('https://haf-dev.com');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('haf-dev.com')),
      );
    }
  }

  Future<void> _toggleNotifications(
    BuildContext context,
    AppController controller,
    bool enabled,
  ) async {
    final granted = await controller.setNotificationsEnabled(enabled);
    if (!context.mounted) return;
    if (enabled && !granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppStrings(controller.languageCode).notificationsDenied),
        ),
      );
    }
  }

  Future<void> _chooseLanguage(
    BuildContext context,
    AppController controller,
  ) async {
    final strings = AppStrings(controller.languageCode);
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.chooseLanguage,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.translate_outlined),
                title: Text(strings.arabic),
                trailing: controller.languageCode == 'ar'
                    ? const Icon(Icons.check_circle)
                    : null,
                onTap: () => Navigator.pop(context, 'ar'),
              ),
              ListTile(
                leading: const Icon(Icons.language_outlined),
                title: Text(strings.english),
                trailing: controller.languageCode == 'en'
                    ? const Icon(Icons.check_circle)
                    : null,
                onTap: () => Navigator.pop(context, 'en'),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) {
      await controller.saveLanguageCode(selected);
    }
  }

  Future<void> _confirmClear(
    BuildContext context,
    AppController controller,
  ) async {
    final strings = AppStrings(controller.languageCode);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.clearDataTitle),
        content: Text(strings.clearDataMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.clear),
          ),
        ],
      ),
    );
    if (confirmed == true) controller.clearAllData();
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
