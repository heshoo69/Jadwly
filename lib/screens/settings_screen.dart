import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../controllers/app_controller.dart';
import '../l10n/app_strings.dart';
import '../services/date_helpers.dart';
import '../widgets/bottom_navigation_clearance.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static final Uri _developerWebsiteUri = Uri.parse('https://haf-dev.com');
  static final Uri _whatsAppSupportUri =
      Uri.parse('https://wa.me/966533801169');

  late final TextEditingController _nameController;
  String _appVersion = '...';

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _loadAppVersion();
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

  Future<void> _loadAppVersion() async {
    try {
      // Reads the version from the installed app bundle, so pubspec changes
      // appear here only after rebuilding/reinstalling the app.
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = packageInfo.version);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() => _appVersion = '-');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = AppStrings(controller.languageCode);
    final theme = Theme.of(context);
    final bottomClearance = BottomNavigationClearance.of(context);
    const weekStartOptions = [
      DateTime.sunday,
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          sliver: SliverList.list(
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
                        prefixIcon: const Icon(
                          Icons.calendar_view_week_outlined,
                        ),
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
                      secondary:
                          const Icon(Icons.notifications_active_outlined),
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
                        DropdownMenuItem(
                          value: 5,
                          child: Text(strings.minutes(5)),
                        ),
                        DropdownMenuItem(
                          value: 10,
                          child: Text(strings.minutes(10)),
                        ),
                        DropdownMenuItem(
                          value: 15,
                          child: Text(strings.minutes(15)),
                        ),
                        DropdownMenuItem(
                          value: 30,
                          child: Text(strings.minutes(30)),
                        ),
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
                        onPressed: () => _addDemoData(context, controller),
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
                title: strings.backup,
                child: _BackupSettings(
                  controller: controller,
                  lastBackupText: _formatBackupDate(
                    controller.lastBackupDate,
                    controller.languageCode,
                  ),
                  onRetry: () => _retryBackup(context, controller),
                  onRestoreLatest: () =>
                      _confirmRestoreLatestBackup(context, controller),
                  onRestoreFromFile: () =>
                      _confirmRestoreFromFile(context, controller),
                  onExportBackup: () => _exportBackup(context, controller),
                  onSaveBackupToFiles: () =>
                      _saveBackupToFiles(context, controller),
                ),
              ),
              const SizedBox(height: 16),
              _SettingsSection(
                title: strings.supportAndContact,
                accent: true,
                child: Column(
                  children: [
                    _SupportActionTile(
                      icon: Icons.chat_bubble_rounded,
                      accentColor: const Color(0xFF25D366),
                      title: strings.whatsappSupport,
                      subtitle: '+966533801169',
                      onTap: () => _openExternalLink(
                        context,
                        _whatsAppSupportUri,
                        fallbackMessage: '+966533801169',
                      ),
                    ),
                    _SupportDivider(color: theme.colorScheme.outlineVariant),
                    _SupportActionTile(
                      icon: Icons.alternate_email_rounded,
                      title: strings.supportEmail,
                      subtitle: 'support@haf-dev.com',
                      onTap: () => _openMailApp(
                        context,
                        email: 'support@haf-dev.com',
                        fallbackMessage: 'support@haf-dev.com',
                      ),
                    ),
                    _SupportDivider(color: theme.colorScheme.outlineVariant),
                    _SupportActionTile(
                      icon: Icons.link_rounded,
                      title: strings.website,
                      subtitle: 'haf-dev.com',
                      onTap: () => _openExternalLink(
                        context,
                        _developerWebsiteUri,
                        fallbackMessage: 'haf-dev.com',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: false,
          fillOverscroll: false,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                24,
                16,
                20 + bottomClearance,
              ),
              child: _SettingsFooter(
                version: _appVersion,
                copyright: strings.settingsFooterCopyright,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openExternalLink(
    BuildContext context,
    Uri uri, {
    required String fallbackMessage,
  }) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fallbackMessage)),
      );
    }
  }

  Future<void> _openMailApp(
    BuildContext context, {
    required String email,
    String? subject,
    required String fallbackMessage,
  }) async {
    final mailSubject = subject ?? 'الدعم والاقتراحات - جدولي';
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {'subject': mailSubject},
    );
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(fallbackMessage)),
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

  Future<void> _addDemoData(
    BuildContext context,
    AppController controller,
  ) async {
    final added = await controller.addDemoData();
    if (!context.mounted || !added) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppStrings(controller.languageCode).demoDataAdded)),
    );
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

  String _formatBackupDate(DateTime? date, String languageCode) {
    final strings = AppStrings(languageCode);
    if (date == null) return strings.noBackupYet;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '${formatLocalizedDate(date, languageCode)} $hour:$minute';
  }

  Future<void> _retryBackup(
    BuildContext context,
    AppController controller,
  ) async {
    final strings = AppStrings(controller.languageCode);
    final saved = await controller.retryAutomaticBackup();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(saved ? strings.backupSaved : strings.automaticBackupFailed),
      ),
    );
  }

  Future<void> _confirmRestoreLatestBackup(
    BuildContext context,
    AppController controller,
  ) async {
    final confirmed = await _confirmRestore(context, controller);
    if (confirmed != true) return;
    final strings = AppStrings(controller.languageCode);
    try {
      await controller.restoreLatestAutomaticBackup();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.backupRestored)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_restoreErrorMessage(strings, error))),
      );
    }
  }

  Future<void> _confirmRestoreFromFile(
    BuildContext context,
    AppController controller,
  ) async {
    final confirmed = await _confirmRestore(context, controller);
    if (confirmed != true) return;
    final strings = AppStrings(controller.languageCode);
    try {
      final restored = await controller.restoreBackupFromFile();
      if (!context.mounted || !restored) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.backupRestored)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_restoreErrorMessage(strings, error))),
      );
    }
  }

  Future<void> _exportBackup(
    BuildContext context,
    AppController controller,
  ) async {
    final strings = AppStrings(controller.languageCode);
    try {
      final exported = await controller.exportLatestAutomaticBackup();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            exported ? strings.backupFileReady : strings.exportBackupFailed,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.exportBackupFailed)),
      );
    }
  }

  Future<void> _saveBackupToFiles(
    BuildContext context,
    AppController controller,
  ) async {
    final strings = AppStrings(controller.languageCode);
    try {
      final saved = await controller.saveLatestAutomaticBackupToFiles();
      if (!context.mounted || saved == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? strings.backupFileSaved : strings.saveBackupFileFailed,
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.saveBackupFileFailed)),
      );
    }
  }

  Future<bool?> _confirmRestore(
    BuildContext context,
    AppController controller,
  ) {
    final strings = AppStrings(controller.languageCode);
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.restoreBackupTitle),
        content: Text(strings.restoreBackupMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.restore),
          ),
        ],
      ),
    );
  }

  String _restoreErrorMessage(AppStrings strings, Object error) {
    final message = error.toString();
    if (message.contains('إصدار النسخة الاحتياطية غير مدعوم')) {
      return strings.unsupportedBackupVersion;
    }
    if (message.contains('ملف النسخة الاحتياطية غير صالح')) {
      return strings.invalidBackupFile;
    }
    return strings.restoreBackupFailed;
  }
}

class _BackupSettings extends StatelessWidget {
  const _BackupSettings({
    required this.controller,
    required this.lastBackupText,
    required this.onRetry,
    required this.onRestoreLatest,
    required this.onRestoreFromFile,
    required this.onExportBackup,
    required this.onSaveBackupToFiles,
  });

  final AppController controller;
  final String lastBackupText;
  final VoidCallback onRetry;
  final VoidCallback onRestoreLatest;
  final VoidCallback onRestoreFromFile;
  final VoidCallback onExportBackup;
  final VoidCallback onSaveBackupToFiles;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings(controller.languageCode);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.backupDescription,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.backup_outlined),
          title: Text(strings.lastBackup),
          subtitle: Text(lastBackupText),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_done_outlined),
          title: Text(controller.getBackupStatusLabel()),
        ),
        if (controller.automaticBackupFailed) ...[
          const SizedBox(height: 8),
          Text(
            strings.automaticBackupFailed,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.save_outlined),
              label: Text(strings.saveBackupNow),
            ),
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onRestoreLatest,
            icon: const Icon(Icons.restore_outlined),
            label: Text(strings.restoreLatestAutomaticBackup),
          ),
        ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          leading: const Icon(Icons.tune_outlined),
          title: Text(strings.advancedOptions),
          children: [
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onSaveBackupToFiles,
                icon: const Icon(Icons.folder_copy_outlined),
                label: Text(strings.saveBackupToFiles),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onExportBackup,
                icon: const Icon(Icons.ios_share_outlined),
                label: Text(strings.exportBackupFile),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onRestoreFromFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(strings.restoreFromFile),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.child,
    this.accent = false,
  });

  final String title;
  final Widget child;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = theme.colorScheme.outlineVariant.withValues(
      alpha: accent ? 0.46 : 0.35,
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
        boxShadow: accent
            ? [
                BoxShadow(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: accent
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SupportActionTile extends StatelessWidget {
  const _SupportActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = accentColor ?? theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.north_west_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportDivider extends StatelessWidget {
  const _SupportDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: color.withValues(alpha: 0.18),
    );
  }
}

class _SettingsFooter extends StatelessWidget {
  const _SettingsFooter({
    required this.version,
    required this.copyright,
  });

  final String version;
  final String copyright;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'v$version',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          copyright,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
