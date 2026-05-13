import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jadwly/models/lesson_record.dart';
import 'package:jadwly/models/lesson_status.dart';
import 'package:jadwly/models/schedule_item.dart';
import 'package:jadwly/models/session_type.dart';
import 'package:jadwly/models/teacher_class.dart';
import 'package:jadwly/services/backup_service.dart';
import 'package:jadwly/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late Directory backupDir;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('jadwly_hive_');
    backupDir = await Directory.systemTemp.createTemp('jadwly_backups_');
    BackupService.setTestBackupDirectory(backupDir);
    await StorageService.init(testPath: hiveDir.path);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
    await backupDir.delete(recursive: true);
    BackupService.setTestBackupDirectory(null);
  });

  test('createBackupJson includes required top-level fields and arrays',
      () async {
    await _seedData();

    final backup = await BackupService.createBackupJson();

    expect(backup['appName'], 'Jadwly');
    expect(backup['backupVersion'], 1);
    expect(backup['createdAt'], isA<String>());
    expect(backup['backupType'], 'automatic');
    expect(backup['platform'], isA<String>());
    expect(backup['classes'], isA<List>());
    expect(backup['scheduleItems'], isA<List>());
    expect(backup['lessonRecords'], isA<List>());
    expect(backup['settings'], isA<Map>());
  });

  test('createAutomaticBackup writes a file and keeps latest five', () async {
    await _seedData();

    for (var index = 0; index < 7; index++) {
      await BackupService.createAutomaticBackup();
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    final backups = await BackupService.getAutomaticBackups();
    expect(backups, hasLength(5));
    expect(BackupService.getLastBackupDate(), isNotNull);
    expect(BackupService.automaticBackupFailed, isFalse);
  });

  test('getLatestAutomaticBackupOrCreate returns existing latest backup',
      () async {
    await _seedData();
    final existing = await BackupService.createAutomaticBackup();

    final selected = await BackupService.getLatestAutomaticBackupOrCreate();
    final backups = await BackupService.getAutomaticBackups();

    expect(existing, isNotNull);
    expect(selected?.path, existing?.path);
    expect(backups, hasLength(1));
  });

  test('getLatestAutomaticBackupOrCreate creates backup when none exists',
      () async {
    await _seedData();

    final selected = await BackupService.getLatestAutomaticBackupOrCreate();
    final backups = await BackupService.getAutomaticBackups();

    expect(selected, isNotNull);
    expect(backups, hasLength(1));
    expect(backups.single.path, selected?.path);
  });

  test('exportFileNameForBackup includes app name and backup timestamp',
      () async {
    await _seedData();
    final backup = await BackupService.createAutomaticBackup();

    final fileName = await BackupService.exportFileNameForBackup(backup!);

    expect(fileName, startsWith('Jadwly_backup_'));
    expect(fileName, endsWith('.json'));
    expect(
      fileName,
      matches(RegExp(r'^Jadwly_backup_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}\.json$')),
    );
  });

  test('validateBackupJson rejects invalid files', () {
    expect(
      () => BackupService.validateBackupJson({
        'appName': 'Other',
        'backupVersion': 1,
        'classes': [],
        'scheduleItems': [],
        'lessonRecords': [],
        'settings': {},
      }),
      throwsA(isA<BackupValidationException>()),
    );

    expect(
      () => BackupService.validateBackupJson({
        'appName': 'Jadwly',
        'backupVersion': 999,
        'classes': [],
        'scheduleItems': [],
        'lessonRecords': [],
        'settings': {},
      }),
      throwsA(isA<BackupValidationException>()),
    );

    expect(
      () => BackupService.validateBackupJson({
        'appName': 'Jadwly',
        'backupVersion': 1,
        'classes': {},
        'scheduleItems': [],
        'lessonRecords': [],
        'settings': {},
      }),
      throwsA(isA<BackupValidationException>()),
    );
  });

  test('applyBackupToLocalStorage restores records and settings', () async {
    await _seedData();
    final backup = await BackupService.createBackupJson();

    await StorageService.clearAll();
    await BackupService.applyBackupToLocalStorage(
      jsonDecode(jsonEncode(backup)) as Map<String, dynamic>,
    );

    expect(StorageService.classesBox.length, 1);
    expect(StorageService.scheduleBox.length, 1);
    expect(StorageService.lessonsBox.length, 1);
    expect(StorageService.settingsBox.get('languageCode'), 'en');
  });
}

Future<void> _seedData() async {
  final now = DateTime(2026, 5, 12, 8, 30);
  await StorageService.settingsBox.putAll({
    'teacherName': 'Teacher',
    'languageCode': 'en',
    'notificationsEnabled': false,
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
      dayOfWeek: DateTime.tuesday,
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
}
