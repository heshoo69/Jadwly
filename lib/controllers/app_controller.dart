import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lesson_record.dart';
import '../models/lesson_status.dart';
import '../models/schedule_item.dart';
import '../models/session_type.dart';
import '../models/teacher_class.dart';
import '../l10n/app_strings.dart';
import '../services/app_feedback_service.dart';
import '../services/date_helpers.dart';
import '../services/notification_service.dart';
import '../services/supabase_database_service.dart';
import '../services/storage_service.dart';
import '../services/time_helpers.dart';

class AppController extends ChangeNotifier {
  AppController() {
    _load();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.session == null) {
        _clearUserScopedLocalData();
      } else {
        _safeLoadUserData();
      }
    });
    if (Supabase.instance.client.auth.currentUser != null) {
      _safeLoadUserData();
    }
  }

  StreamSubscription<AuthState>? _authSubscription;

  List<TeacherClass> classes = [];
  List<ScheduleItem> schedule = [];
  List<LessonRecord> lessons = [];
  String teacherName = '';
  String languageCode = 'ar';
  bool notificationsEnabled = false;
  int reminderMinutes = 10;
  int weekStartDay = DateTime.sunday;
  bool showWeekends = false;
  String scheduleViewMode = 'weeklyGrid';

  void _load() {
    classes = StorageService.classesBox.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    schedule = StorageService.scheduleBox.values.toList()
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) return day;
        if (a.periodNumber > 0 && b.periodNumber > 0) {
          return a.periodNumber.compareTo(b.periodNumber);
        }
        return minutesSinceMidnight(a.startTime)
            .compareTo(minutesSinceMidnight(b.startTime));
      });
    lessons = StorageService.lessonsBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    teacherName = StorageService.settingsBox
        .get('teacherName', defaultValue: '') as String;
    languageCode = StorageService.settingsBox
        .get('languageCode', defaultValue: 'ar') as String;
    notificationsEnabled = StorageService.settingsBox
        .get('notificationsEnabled', defaultValue: false) as bool;
    reminderMinutes = StorageService.settingsBox
        .get('reminderMinutes', defaultValue: 10) as int;
    weekStartDay = StorageService.settingsBox
        .get('weekStartDay', defaultValue: DateTime.sunday) as int;
    showWeekends = StorageService.settingsBox
        .get('showWeekends', defaultValue: false) as bool;
    scheduleViewMode = StorageService.settingsBox
        .get('scheduleViewMode', defaultValue: 'weeklyGrid') as String;
  }

  TeacherClass? classById(String id) {
    for (final item in classes) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<ScheduleItem> scheduleForDay(int dayOfWeek) {
    return schedule.where((item) => item.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) {
        if (a.periodNumber > 0 && b.periodNumber > 0) {
          return a.periodNumber.compareTo(b.periodNumber);
        }
        return minutesSinceMidnight(a.startTime)
            .compareTo(minutesSinceMidnight(b.startTime));
      });
  }

  List<int> get visibleWeekDays {
    final ordered = <int>[];
    for (var offset = 0; offset < 7; offset++) {
      final day = ((weekStartDay - 1 + offset) % 7) + 1;
      if (!showWeekends &&
          (day == DateTime.friday || day == DateTime.saturday)) {
        continue;
      }
      ordered.add(day);
    }
    return ordered;
  }

  List<LessonRecord> lessonsForClass(String classId) {
    return lessons.where((lesson) => lesson.classId == classId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  LessonRecord? latestLessonForClass(String classId) {
    final records = lessonsForClass(classId);
    return records.isEmpty ? null : records.first;
  }

  Future<void> saveTeacherClass(TeacherClass item) async {
    await StorageService.classesBox.put(item.id, item);
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> deleteTeacherClass(String id) async {
    for (final item
        in schedule.where((entry) => entry.classId == id).toList()) {
      await SupabaseDatabaseService.deleteScheduleItem(item.id);
    }
    for (final item in lessons.where((entry) => entry.classId == id).toList()) {
      await SupabaseDatabaseService.deleteLessonRecord(item.id);
    }
    await StorageService.classesBox.delete(id);
    for (final item
        in schedule.where((entry) => entry.classId == id).toList()) {
      await StorageService.scheduleBox.delete(item.id);
    }
    for (final item in lessons.where((entry) => entry.classId == id).toList()) {
      await StorageService.lessonsBox.delete(item.id);
    }
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> saveScheduleItem(
    ScheduleItem item, {
    bool isNew = false,
  }) async {
    final userId = SupabaseDatabaseService.currentUserId;
    final remoteIsNew = isNew || !isUuid(item.id);
    final scopedItem = item.copyWith(
      id: isUuid(item.id) ? item.id : newId(),
      teacherId: userId,
    );
    final className = classById(scopedItem.classId)?.className;
    await StorageService.scheduleBox.put(scopedItem.id, scopedItem);
    if (scopedItem.id != item.id) {
      await StorageService.scheduleBox.delete(item.id);
    }
    _load();
    notifyListeners();

    unawaited(_syncClassReminders());
    unawaited(_syncRemoteScheduleItem(
      scopedItem,
      className: className,
      isNew: remoteIsNew,
    ));
  }

  Future<void> deleteScheduleItem(String id) async {
    await SupabaseDatabaseService.deleteScheduleItem(id);
    await StorageService.scheduleBox.delete(id);
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> addLesson(LessonRecord record) async {
    final userId = SupabaseDatabaseService.currentUserIdOrNull;
    final scopedRecord = record.copyWith(
      id: isUuid(record.id) ? record.id : newId(),
      teacherId: userId,
    );
    final teacherClass = classById(scopedRecord.classId);
    final className = teacherClass?.className ?? scopedRecord.classId;
    final subject = teacherClass?.subject ?? '';
    await StorageService.lessonsBox.put(scopedRecord.id, scopedRecord);
    if (scopedRecord.id != record.id) {
      await StorageService.lessonsBox.delete(record.id);
    }
    _load();
    notifyListeners();

    unawaited(_syncClassReminders());
    unawaited(_syncRemoteLessonRecord(
      scopedRecord,
      className: className,
      subject: subject,
      successMessage: AppStrings(languageCode).lessonSavedAndSynced,
    ));
  }

  Future<void> updateLesson(LessonRecord record) async {
    final userId = SupabaseDatabaseService.currentUserIdOrNull;
    final scopedRecord = record.copyWith(
      id: isUuid(record.id) ? record.id : newId(),
      teacherId: userId,
    );
    final teacherClass = classById(scopedRecord.classId);
    final className = teacherClass?.className ?? scopedRecord.classId;
    final subject = teacherClass?.subject ?? '';
    await StorageService.lessonsBox.put(scopedRecord.id, scopedRecord);
    if (scopedRecord.id != record.id) {
      await StorageService.lessonsBox.delete(record.id);
    }
    _load();
    notifyListeners();

    unawaited(_syncClassReminders());
    unawaited(_syncRemoteLessonRecord(
      scopedRecord,
      className: className,
      subject: subject,
      successMessage: AppStrings(languageCode).lessonUpdatedAndSynced,
    ));
  }

  Future<void> deleteLesson(String id) async {
    await SupabaseDatabaseService.deleteLessonRecord(id);
    await StorageService.lessonsBox.delete(id);
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> saveTeacherName(String name) async {
    final trimmedName = name.trim();
    if (Supabase.instance.client.auth.currentUser != null) {
      await SupabaseDatabaseService.saveProfileName(trimmedName);
    }
    await StorageService.settingsBox.put('teacherName', trimmedName);
    _load();
    notifyListeners();
  }

  Future<void> saveLanguageCode(String code) async {
    await StorageService.settingsBox.put('languageCode', code);
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> clearAllData() async {
    if (Supabase.instance.client.auth.currentUser != null) {
      for (final item in schedule) {
        await SupabaseDatabaseService.deleteScheduleItem(item.id);
      }
      for (final lesson in lessons) {
        await SupabaseDatabaseService.deleteLessonRecord(lesson.id);
      }
    }
    await NotificationService.cancelAllClassReminders();
    await StorageService.clearAll();
    _load();
    notifyListeners();
  }

  Future<bool> setNotificationsEnabled(bool enabled) async {
    if (!enabled) {
      await StorageService.settingsBox.put('notificationsEnabled', false);
      await _saveReminderSettingsIfSignedIn(
        notificationsEnabledOverride: false,
      );
      await NotificationService.cancelAllClassReminders();
      _load();
      notifyListeners();
      return true;
    }

    final granted = await NotificationService.requestPermission();
    await StorageService.settingsBox.put('notificationsEnabled', granted);
    await _saveReminderSettingsIfSignedIn(
      notificationsEnabledOverride: granted,
    );
    _load();
    if (granted) {
      await _syncClassReminders();
    } else {
      await NotificationService.cancelAllClassReminders();
    }
    notifyListeners();
    return granted;
  }

  Future<void> setReminderMinutes(int minutes) async {
    await StorageService.settingsBox.put('reminderMinutes', minutes);
    await _saveReminderSettingsIfSignedIn(reminderMinutesOverride: minutes);
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> setWeekStartDay(int day) async {
    await StorageService.settingsBox.put('weekStartDay', day);
    await _saveReminderSettingsIfSignedIn(weekStartDayOverride: day);
    _load();
    notifyListeners();
  }

  Future<void> setShowWeekends(bool value) async {
    await StorageService.settingsBox.put('showWeekends', value);
    await _saveReminderSettingsIfSignedIn(showWeekendsOverride: value);
    _load();
    notifyListeners();
  }

  Future<void> setScheduleViewMode(String mode) async {
    await StorageService.settingsBox.put('scheduleViewMode', mode);
    await _saveReminderSettingsIfSignedIn(scheduleViewModeOverride: mode);
    _load();
    notifyListeners();
  }

  Future<void> addDemoData() async {
    if (classes.isNotEmpty || schedule.isNotEmpty || lessons.isNotEmpty) return;

    final now = DateTime.now();
    final teacherId = SupabaseDatabaseService.currentUserId;
    final classOneId = newId();
    final classTwoId = newId();
    final scheduleOneId = newId();
    final scheduleTwoId = newId();
    final lessonId = newId();
    final classOne = TeacherClass(
      id: classOneId,
      className: 'أول متوسط / 1',
      subject: 'المهارات الرقمية',
      roomNumber: '201',
      createdAt: now,
    );
    final classTwo = TeacherClass(
      id: classTwoId,
      className: 'أول متوسط / 2',
      subject: 'المهارات الرقمية',
      roomNumber: '202',
      createdAt: now,
    );
    await StorageService.classesBox.put(classOne.id, classOne);
    await StorageService.classesBox.put(classTwo.id, classTwo);
    final scheduleOne = ScheduleItem(
      id: scheduleOneId,
      dayOfWeek: now.weekday,
      periodNumber: 1,
      startTime: '07:30 AM',
      endTime: '08:15 AM',
      subject: classOne.subject,
      classId: classOne.id,
      roomNumber: classOne.roomNumber,
      teacherId: teacherId,
    );
    final scheduleTwo = ScheduleItem(
      id: scheduleTwoId,
      dayOfWeek: now.weekday,
      periodNumber: 2,
      startTime: '08:20 AM',
      endTime: '09:05 AM',
      subject: classTwo.subject,
      classId: classTwo.id,
      roomNumber: classTwo.roomNumber,
      teacherId: teacherId,
    );
    final lesson = LessonRecord(
      id: lessonId,
      classId: classOne.id,
      lessonTitle: 'التعامل مع الملفات',
      sessionType: SessionType.practical,
      notes: 'تطبيق عملي على إنشاء المجلدات وتنظيم الملفات.',
      status: LessonStatus.needsContinuation,
      date: now.subtract(const Duration(days: 1)),
      createdAt: now,
      teacherId: teacherId,
    );
    final savedScheduleOne = await SupabaseDatabaseService.upsertScheduleItem(
      scheduleOne,
      className: classOne.className,
      isNew: true,
    );
    final savedScheduleTwo = await SupabaseDatabaseService.upsertScheduleItem(
      scheduleTwo,
      className: classTwo.className,
      isNew: true,
    );
    await SupabaseDatabaseService.upsertLessonRecord(
      lesson,
      className: classOne.className,
      subject: classOne.subject,
    );
    await StorageService.scheduleBox.put(
      savedScheduleOne.id,
      savedScheduleOne.copyWith(classId: scheduleOne.classId),
    );
    await StorageService.scheduleBox.put(
      savedScheduleTwo.id,
      savedScheduleTwo.copyWith(classId: scheduleTwo.classId),
    );
    await StorageService.lessonsBox.put(lesson.id, lesson);
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> loadUserData() async {
    final remoteSchedule = await SupabaseDatabaseService.fetchWeeklySchedule();
    final remoteLessons = await SupabaseDatabaseService.fetchLessonRecords();
    final remoteReminderSettings =
        await SupabaseDatabaseService.fetchReminderSettings();
    final matchedSchedule = remoteSchedule.map(_matchRemoteScheduleClass);
    final matchedLessons = remoteLessons.map(_matchRemoteLessonClass);
    await _replaceUserScopedLocalData(
      scheduleItems: matchedSchedule.toList(),
      lessonRecords: matchedLessons.toList(),
    );
    if (remoteReminderSettings != null) {
      await _saveRemoteReminderSettings(remoteReminderSettings);
    }
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> _safeLoadUserData() async {
    try {
      await loadUserData();
    } catch (error) {
      debugPrint('Failed to load Supabase user data: $error');
    }
  }

  ScheduleItem _matchRemoteScheduleClass(ScheduleItem item) {
    for (final teacherClass in classes) {
      if (teacherClass.className == item.classId) {
        return item.copyWith(
          classId: teacherClass.id,
          subject: item.subject.isEmpty ? teacherClass.subject : item.subject,
          roomNumber: item.roomNumber ?? teacherClass.roomNumber,
        );
      }
    }
    return item;
  }

  LessonRecord _matchRemoteLessonClass(LessonRecord lesson) {
    for (final teacherClass in classes) {
      if (teacherClass.className == lesson.classId) {
        return lesson.copyWith(classId: teacherClass.id);
      }
    }
    return lesson;
  }

  Future<void> _replaceUserScopedLocalData({
    required List<ScheduleItem> scheduleItems,
    required List<LessonRecord> lessonRecords,
  }) async {
    await StorageService.scheduleBox.clear();
    await StorageService.lessonsBox.clear();
    await StorageService.scheduleBox.putAll({
      for (final item in scheduleItems) item.id: item,
    });
    await StorageService.lessonsBox.putAll({
      for (final record in lessonRecords) record.id: record,
    });
  }

  Future<void> _clearUserScopedLocalData() async {
    await StorageService.scheduleBox.clear();
    await StorageService.lessonsBox.clear();
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> _saveReminderSettingsIfSignedIn({
    bool? notificationsEnabledOverride,
    int? reminderMinutesOverride,
    int? weekStartDayOverride,
    bool? showWeekendsOverride,
    String? scheduleViewModeOverride,
  }) async {
    if (Supabase.instance.client.auth.currentUser == null) return;
    try {
      await SupabaseDatabaseService.saveReminderSettings(
        notificationsEnabled:
            notificationsEnabledOverride ?? notificationsEnabled,
        reminderMinutes: reminderMinutesOverride ?? reminderMinutes,
        weekStartDay: weekStartDayOverride ?? weekStartDay,
        showWeekends: showWeekendsOverride ?? showWeekends,
        scheduleViewMode: scheduleViewModeOverride ?? scheduleViewMode,
      );
    } catch (error) {
      debugPrint('Failed to save Supabase reminder settings: $error');
    }
  }

  Future<void> _saveRemoteReminderSettings(Map<String, dynamic> row) async {
    await StorageService.settingsBox.put(
      'notificationsEnabled',
      row['is_enabled'] as bool? ?? notificationsEnabled,
    );
    await StorageService.settingsBox.put(
      'reminderMinutes',
      row['minutes_offset'] as int? ?? reminderMinutes,
    );
  }

  Future<void> _syncClassReminders() async {
    if (!notificationsEnabled) return;
    try {
      await NotificationService.rescheduleWeeklyClassReminders(
        schedule: schedule,
        classes: classes,
        lessons: lessons,
        reminderMinutes: reminderMinutes,
        languageCode: languageCode,
      ).timeout(const Duration(seconds: 8));
    } catch (error) {
      debugPrint('Failed to sync class reminders: $error');
    }
  }

  Future<void> _syncRemoteScheduleItem(
    ScheduleItem item, {
    required String? className,
    required bool isNew,
  }) async {
    try {
      debugPrint('Sync weekly_schedule start: ${item.id}');
      await SupabaseDatabaseService.upsertScheduleItem(
        item,
        className: className,
        isNew: isNew,
      );
      debugPrint('Sync weekly_schedule success: ${item.id}');
    } catch (error) {
      debugPrint('Sync weekly_schedule failed: ${item.id} $error');
    }
  }

  Future<void> _syncRemoteLessonRecord(
    LessonRecord record, {
    required String className,
    required String subject,
    required String successMessage,
  }) async {
    try {
      debugPrint('Sync lesson_records start: ${record.id}');
      await SupabaseDatabaseService.upsertLessonRecord(
        record,
        className: className,
        subject: subject,
      );
      debugPrint('Sync lesson_records success: ${record.id}');
      AppFeedbackService.showSnackBar(successMessage);
    } catch (error) {
      debugPrint('Sync lesson_records failed: ${record.id} $error');
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).lessonSavedLocallySyncFailed,
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
