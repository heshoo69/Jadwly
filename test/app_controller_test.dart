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
import 'package:jadwly/services/backup_service.dart';
import 'package:jadwly/services/storage_service.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    FlutterLocalNotificationsPlatform.instance = _FakeNotificationsPlatform();
  });

  test('clearAllData clears records and preserves preferences', () async {
    final tempDir = await Directory.systemTemp.createTemp('jadwly_controller_');
    final backupDir =
        await Directory.systemTemp.createTemp('jadwly_controller_backups_');
    BackupService.setTestBackupDirectory(backupDir);
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
    await BackupService.createAutomaticBackup();
    final lastBackupDateBeforeClear = controller.lastBackupDate;
    final backupsBeforeClear = await BackupService.getAutomaticBackups();
    await controller.clearAllData();
    final backupsAfterClear = await BackupService.getAutomaticBackups();

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
    expect(backupsBeforeClear, hasLength(1));
    expect(backupsAfterClear, hasLength(1));
    expect(backupsAfterClear.single.path, backupsBeforeClear.single.path);
    expect(lastBackupDateBeforeClear, isNotNull);
    expect(controller.lastBackupDate, lastBackupDateBeforeClear);
    expect(controller.automaticBackupFailed, isFalse);

    await Hive.close();
    await tempDir.delete(recursive: true);
    await backupDir.delete(recursive: true);
    BackupService.setTestBackupDirectory(null);
  });

  test('backup date remains after restore then clearing data again', () async {
    final tempDir = await Directory.systemTemp.createTemp('jadwly_controller_');
    final backupDir =
        await Directory.systemTemp.createTemp('jadwly_controller_backups_');
    BackupService.setTestBackupDirectory(backupDir);
    await StorageService.init(testPath: tempDir.path);

    final controller = AppController();
    await controller.saveTeacherClass(
      TeacherClass(
        id: 'class-1',
        className: 'Class 1',
        subject: 'Digital Skills',
        createdAt: DateTime(2026, 5, 13),
      ),
    );
    final originalBackupDate = controller.lastBackupDate;
    final backupsBeforeClear = await BackupService.getAutomaticBackups();

    await controller.clearAllData();
    await controller.restoreLatestAutomaticBackup();
    await controller.clearAllData();
    final backupsAfterSecondClear = await BackupService.getAutomaticBackups();

    expect(originalBackupDate, isNotNull);
    expect(controller.lastBackupDate, originalBackupDate);
    expect(controller.automaticBackupFailed, isFalse);
    expect(backupsAfterSecondClear, hasLength(1));
    expect(backupsAfterSecondClear.single.path, backupsBeforeClear.single.path);

    await Hive.close();
    await tempDir.delete(recursive: true);
    await backupDir.delete(recursive: true);
    BackupService.setTestBackupDirectory(null);
  });

  test('saveTeacherClass creates an automatic backup', () async {
    final tempDir = await Directory.systemTemp.createTemp('jadwly_controller_');
    final backupDir =
        await Directory.systemTemp.createTemp('jadwly_controller_backups_');
    BackupService.setTestBackupDirectory(backupDir);
    await StorageService.init(testPath: tempDir.path);

    final controller = AppController();
    await controller.saveTeacherClass(
      TeacherClass(
        id: 'class-1',
        className: 'Class 1',
        subject: 'Digital Skills',
        createdAt: DateTime(2026, 5, 12),
      ),
    );

    final backups = await BackupService.getAutomaticBackups();
    expect(backups, hasLength(1));
    expect(controller.lastBackupDate, isNotNull);
    expect(controller.automaticBackupFailed, isFalse);

    await Hive.close();
    await tempDir.delete(recursive: true);
    await backupDir.delete(recursive: true);
    BackupService.setTestBackupDirectory(null);
  });
}

class _FakeNotificationsPlatform extends FlutterLocalNotificationsPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<void> cancelAll() async {}
}
