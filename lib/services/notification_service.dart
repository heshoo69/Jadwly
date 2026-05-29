import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../firebase_options.dart';
import '../models/lesson_record.dart';
import '../models/lesson_status.dart';
import '../models/schedule_item.dart';
import '../models/session_type.dart';
import '../models/teacher_class.dart';
import 'cloud_sync_service.dart';
import 'time_helpers.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);
  }
}

class NotificationService {
  NotificationService._();

  static const channelId = 'class_reminders';
  static const channelName = 'تنبيهات الحصص';
  static const channelDescription = 'تنبيهات قبل الحصة مع ملخص آخر درس';
  static const firebaseChannelId = 'firebase_messages';
  static const firebaseChannelName = 'إشعارات جدولي';
  static const firebaseChannelDescription = 'إشعارات مرسلة من Jadwly';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  static Future<void> init() async {
    tz_data.initializeTimeZones();
    await _configureLocalTimeZone();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

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
    await _createAndroidNotificationChannels();
    await _configureFirebaseForegroundPresentation();
    _listenForForegroundFirebaseMessages();
    _listenForFirebaseTokenRefresh();
  }

  static Future<bool> requestPermission() async {
    var localGranted = true;
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted = await android?.requestNotificationsPermission();
    if (androidGranted != null) localGranted = androidGranted;

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final iosGranted = await ios?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (iosGranted != null) localGranted = iosGranted;

    final mac = _plugin.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    final macGranted = await mac?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    if (macGranted != null) localGranted = macGranted;
    final firebaseGranted = await requestFirebasePermission();
    return localGranted && firebaseGranted;
  }

  static Future<bool> requestFirebasePermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<void> registerCurrentDeviceToken() async {
    if (kIsWeb) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await CloudSyncService().saveFcmToken(
      token: token,
      platform: _platformName(),
    );
  }

  static Future<void> deleteCurrentDeviceToken() async {
    if (kIsWeb) return;
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    await CloudSyncService().deleteFcmToken(token);
  }

  static Future<void> _createAndroidNotificationChannels() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        channelName,
        description: channelDescription,
        importance: Importance.high,
      ),
    );
    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        firebaseChannelId,
        firebaseChannelName,
        description: firebaseChannelDescription,
        importance: Importance.high,
      ),
    );
  }

  static Future<void> _configureFirebaseForegroundPresentation() {
    return FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static void _listenForFirebaseTokenRefresh() {
    _tokenRefreshSubscription?.cancel();
    _tokenRefreshSubscription =
        FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) {
        if (token.isEmpty) return;
        unawaited(_saveRefreshedToken(token));
      },
    );
  }

  static Future<void> _saveRefreshedToken(String token) async {
    try {
      await CloudSyncService().saveFcmToken(
        token: token,
        platform: _platformName(),
      );
    } catch (_) {
      // Token refresh can happen before sign-in; the controller saves it later.
    }
  }

  static void _listenForForegroundFirebaseMessages() {
    _foregroundMessageSubscription?.cancel();
    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      (message) {
        unawaited(_showForegroundFirebaseMessage(message));
      },
    );
  }

  static Future<void> _showForegroundFirebaseMessage(
    RemoteMessage message,
  ) async {
    final notification = message.notification;
    final title = notification?.title ?? message.data['title']?.toString();
    final body = notification?.body ?? message.data['body']?.toString();
    if ((title == null || title.isEmpty) && (body == null || body.isEmpty)) {
      return;
    }

    await _plugin.show(
      _firebaseNotificationIdFor(message),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          firebaseChannelId,
          firebaseChannelName,
          channelDescription: firebaseChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      payload: message.messageId,
    );
  }

  static Future<void> cancelAllClassReminders() => _plugin.cancelAll();

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

  static int _firebaseNotificationIdFor(RemoteMessage message) {
    final id =
        message.messageId ?? DateTime.now().microsecondsSinceEpoch.toString();
    return _notificationIdFor('firebase_$id');
  }

  static String _platformName() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      default:
        return defaultTargetPlatform.name;
    }
  }
}
