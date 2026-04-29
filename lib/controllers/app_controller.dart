import 'package:flutter/material.dart';

import '../models/lesson_record.dart';
import '../models/lesson_status.dart';
import '../models/schedule_item.dart';
import '../models/session_type.dart';
import '../models/teacher_class.dart';
import '../services/date_helpers.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/time_helpers.dart';

class AppController extends ChangeNotifier {
  AppController() {
    _load();
  }

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

  Future<void> saveScheduleItem(ScheduleItem item) async {
    await StorageService.scheduleBox.put(item.id, item);
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> deleteScheduleItem(String id) async {
    await StorageService.scheduleBox.delete(id);
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> addLesson(LessonRecord record) async {
    await StorageService.lessonsBox.put(record.id, record);
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> updateLesson(LessonRecord record) async {
    await StorageService.lessonsBox.put(record.id, record);
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> deleteLesson(String id) async {
    await StorageService.lessonsBox.delete(id);
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> saveTeacherName(String name) async {
    await StorageService.settingsBox.put('teacherName', name.trim());
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
    await NotificationService.cancelAllClassReminders();
    await StorageService.clearAll();
    _load();
    notifyListeners();
  }

  Future<bool> setNotificationsEnabled(bool enabled) async {
    if (!enabled) {
      await StorageService.settingsBox.put('notificationsEnabled', false);
      await NotificationService.cancelAllClassReminders();
      _load();
      notifyListeners();
      return true;
    }

    final granted = await NotificationService.requestPermission();
    await StorageService.settingsBox.put('notificationsEnabled', granted);
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
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> setWeekStartDay(int day) async {
    await StorageService.settingsBox.put('weekStartDay', day);
    _load();
    notifyListeners();
  }

  Future<void> setShowWeekends(bool value) async {
    await StorageService.settingsBox.put('showWeekends', value);
    _load();
    notifyListeners();
  }

  Future<void> setScheduleViewMode(String mode) async {
    await StorageService.settingsBox.put('scheduleViewMode', mode);
    _load();
    notifyListeners();
  }

  Future<void> addDemoData() async {
    if (classes.isNotEmpty || schedule.isNotEmpty || lessons.isNotEmpty) return;

    final now = DateTime.now();
    final classOneId = newId();
    final classTwoId = '${classOneId}_2';
    final scheduleOneId = '${classOneId}_schedule_1';
    final scheduleTwoId = '${classOneId}_schedule_2';
    final lessonId = '${classOneId}_lesson_1';
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
    await StorageService.scheduleBox.put(
      scheduleOneId,
      ScheduleItem(
        id: scheduleOneId,
        dayOfWeek: now.weekday,
        periodNumber: 1,
        startTime: '07:30 AM',
        endTime: '08:15 AM',
        subject: classOne.subject,
        classId: classOne.id,
        roomNumber: classOne.roomNumber,
      ),
    );
    await StorageService.scheduleBox.put(
      scheduleTwoId,
      ScheduleItem(
        id: scheduleTwoId,
        dayOfWeek: now.weekday,
        periodNumber: 2,
        startTime: '08:20 AM',
        endTime: '09:05 AM',
        subject: classTwo.subject,
        classId: classTwo.id,
        roomNumber: classTwo.roomNumber,
      ),
    );
    await StorageService.lessonsBox.put(
      lessonId,
      LessonRecord(
        id: lessonId,
        classId: classOne.id,
        lessonTitle: 'التعامل مع الملفات',
        sessionType: SessionType.practical,
        notes: 'تطبيق عملي على إنشاء المجلدات وتنظيم الملفات.',
        status: LessonStatus.needsContinuation,
        date: now.subtract(const Duration(days: 1)),
        createdAt: now,
      ),
    );
    _load();
    await _syncClassReminders();
    notifyListeners();
  }

  Future<void> _syncClassReminders() async {
    if (!notificationsEnabled) return;
    await NotificationService.rescheduleWeeklyClassReminders(
      schedule: schedule,
      classes: classes,
      lessons: lessons,
      reminderMinutes: reminderMinutes,
      languageCode: languageCode,
    );
  }
}
