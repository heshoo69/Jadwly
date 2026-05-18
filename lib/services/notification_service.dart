import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/lesson_record.dart';
import '../models/lesson_status.dart';
import '../models/schedule_item.dart';
import '../models/session_type.dart';
import '../models/teacher_class.dart';
import 'time_helpers.dart';

class NotificationService {
  NotificationService._();

  static const channelId = 'class_reminders';
  static const channelName = 'تنبيهات الحصص';
  static const channelDescription = 'تنبيهات قبل الحصة مع ملخص آخر درس';
  static const deletionReminderChannelId = 'cloud_deletion_reminders';
  static const deletionReminderChannelName = 'تنبيهات استعادة البيانات';
  static const deletionReminderChannelDescription =
      'تذكيرات قبل حذف بيانات السيرفر المؤجل';
  static const _cloudDeletion48HoursNotificationId = 900001;
  static const _cloudDeletionLastDayNotificationId = 900002;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      ),
    );
  }

  static Future<bool> requestPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted = await android?.requestNotificationsPermission();
    if (androidGranted != null) return androidGranted;

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosGranted != null) return iosGranted;

    final mac = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    final macGranted = await mac?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    return macGranted ?? true;
  }

  static Future<void> cancelAllClassReminders() => _plugin.cancelAll();

  static Future<void> cancelCloudDeletionReminders() async {
    await _plugin.cancel(_cloudDeletion48HoursNotificationId);
    await _plugin.cancel(_cloudDeletionLastDayNotificationId);
  }

  static Future<void> scheduleCloudDeletionRestoreReminders({
    required DateTime scheduledFor,
    required String languageCode,
  }) async {
    final granted = await requestPermission();
    if (!granted) return;

    await cancelCloudDeletionReminders();

    await _scheduleCloudDeletionReminder(
      id: _cloudDeletion48HoursNotificationId,
      scheduledAt: scheduledFor.subtract(const Duration(hours: 48)),
      title: languageCode == 'en'
          ? 'Restore your cloud data'
          : 'استعادة بيانات السيرفر',
      body: languageCode == 'en'
          ? 'Your cloud data will be deleted in 48 hours unless you restore it.'
          : 'سيتم حذف بيانات السيرفر بعد ٤٨ ساعة إذا لم تستعدها.',
    );

    await _scheduleCloudDeletionReminder(
      id: _cloudDeletionLastDayNotificationId,
      scheduledAt: scheduledFor.subtract(const Duration(days: 1)),
      title: languageCode == 'en'
          ? 'Last day to restore data'
          : 'آخر يوم لاستعادة البيانات',
      body: languageCode == 'en'
          ? 'This is the last day to restore your cloud data before deletion.'
          : 'هذا آخر يوم لاستعادة بيانات السيرفر قبل حذفها.',
    );
  }

  static Future<void> rescheduleWeeklyClassReminders({
    required List<ScheduleItem> schedule,
    required List<TeacherClass> classes,
    required List<LessonRecord> lessons,
    required int reminderMinutes,
    required String languageCode,
  }) async {
    await cancelAllClassReminders();

    for (final item in schedule) {
      final reminderTime = _nextReminderDate(item, reminderMinutes);
      if (reminderTime == null) continue;

      final teacherClass = _classById(classes, item.classId);
      final latestLesson = _latestLessonForClass(lessons, item.classId);
      final title = languageCode == 'en'
          ? 'Next class: ${item.subject}'
          : 'الحصة القادمة: ${item.subject}';
      final body = _buildReminderBody(teacherClass, latestLesson, languageCode);

      await _plugin.zonedSchedule(
        _notificationIdFor(item.id),
        title,
        body,
        reminderTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            channelDescription: channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        payload: item.id,
      );
    }
  }

  static Future<void> _configureLocalTimeZone() async {
    try {
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.UTC);
    }
  }

  static Future<void> _scheduleCloudDeletionReminder({
    required int id,
    required DateTime scheduledAt,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    if (!scheduledAt.isAfter(now)) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(scheduledAt, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          deletionReminderChannelId,
          deletionReminderChannelName,
          channelDescription: deletionReminderChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'cloud_deletion_restore',
    );
  }

  static tz.TZDateTime? _nextReminderDate(
    ScheduleItem item,
    int reminderMinutes,
  ) {
    final parsed = parseClockTime(item.startTime);
    if (parsed == null) return null;

    final now = tz.TZDateTime.now(tz.local);
    var daysUntilClass = item.dayOfWeek - now.weekday;
    if (daysUntilClass < 0) daysUntilClass += 7;

    final classDate = now.add(Duration(days: daysUntilClass));
    var reminderDate = tz.TZDateTime(
      tz.local,
      classDate.year,
      classDate.month,
      classDate.day,
      parsed.hour,
      parsed.minute,
    ).subtract(Duration(minutes: reminderMinutes));

    if (!reminderDate.isAfter(now)) {
      reminderDate = reminderDate.add(const Duration(days: 7));
    }

    return reminderDate;
  }

  static String _buildReminderBody(
    TeacherClass? teacherClass,
    LessonRecord? latestLesson,
    String languageCode,
  ) {
    final className = teacherClass?.className ??
        (languageCode == 'en' ? 'Unknown class' : 'فصل غير معروف');
    if (latestLesson == null) {
      return languageCode == 'en'
          ? '$className - No lesson recorded yet'
          : '$className - لا يوجد درس مسجل بعد';
    }
    return languageCode == 'en'
        ? '$className - Last lesson: ${latestLesson.lessonTitle} - '
            '${latestLesson.sessionType.label(languageCode)} - ${latestLesson.status.label(languageCode)}'
        : '$className - آخر درس: ${latestLesson.lessonTitle} - '
            '${latestLesson.sessionType.label(languageCode)} - ${latestLesson.status.label(languageCode)}';
  }

  static TeacherClass? _classById(List<TeacherClass> classes, String id) {
    for (final item in classes) {
      if (item.id == id) return item;
    }
    return null;
  }

  static LessonRecord? _latestLessonForClass(
    List<LessonRecord> lessons,
    String classId,
  ) {
    final records = lessons
        .where((lesson) => lesson.classId == classId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return records.isEmpty ? null : records.first;
  }

  static int _notificationIdFor(String id) {
    var hash = 0;
    for (final codeUnit in id.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
