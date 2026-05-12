import 'dart:io';

import 'package:flutter_local_notifications_platform_interface/flutter_local_notifications_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jadwly/controllers/app_controller.dart';
import 'package:jadwly/models/lesson_record.dart';
import 'package:jadwly/models/lesson_status.dart';
import 'package:jadwly/models/schedule_item.dart';
import 'package:jadwly/models/session_type.dart';
import 'package:jadwly/models/teacher_class.dart';
import 'package:jadwly/services/storage_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
  });

  test('clearAllData clears records and preserves preferences', () async {
    final tempDir = await Directory.systemTemp.createTemp('jadwly_controller_');
    await StorageService.init(testPath: tempDir.path);

    final now = DateTime(2026, 5, 12);
    await StorageService.settingsBox.putAll({
      'teacherName': 'Teacher',
      'languageCode': 'en',
      'notificationsEnabled': true,
      'reminderMinutes': 30,
      'weekStartDay': DateTime.monday,
      'showWeekends': true,
      'scheduleViewMode': 'dailyList',
    });
    await StorageService.classesBox.put(
      'class-1',
      TeacherClass(
        id: 'class-1',
        className: 'Class 1',
        subject: 'Digital Skills',
        createdAt: now,
      ),
    );
    await StorageService.scheduleBox.put(
      'schedule-1',
      const ScheduleItem(
        id: 'schedule-1',
        dayOfWeek: DateTime.monday,
        periodNumber: 1,
        startTime: '07:30 AM',
        endTime: '08:15 AM',
        subject: 'Digital Skills',
        classId: 'class-1',
      ),
    );
    await StorageService.lessonsBox.put(
      'lesson-1',
      LessonRecord(
        id: 'lesson-1',
        classId: 'class-1',
        lessonTitle: 'Intro',
        sessionType: SessionType.theoretical,
        notes: '',
        status: LessonStatus.completed,
        date: now,
        createdAt: now,
      ),
    );

    final controller = AppController();
    await controller.clearAllData();

    expect(controller.classes, isEmpty);
    expect(controller.schedule, isEmpty);
    expect(controller.lessons, isEmpty);
    expect(controller.teacherName, isEmpty);
    expect(controller.languageCode, 'en');
    expect(controller.notificationsEnabled, isTrue);
    expect(controller.reminderMinutes, 30);
    expect(controller.weekStartDay, DateTime.monday);
    expect(controller.showWeekends, isTrue);
    expect(controller.scheduleViewMode, 'dailyList');

    await Hive.close();
    await tempDir.delete(recursive: true);
  });
}

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancelAll() async {}
}
