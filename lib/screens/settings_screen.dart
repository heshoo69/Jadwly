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
                Icons.chevron_left_rounded,
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
