import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:jadwly/models/lesson_record.dart';
import 'package:jadwly/models/lesson_status.dart';
import 'package:jadwly/models/schedule_item.dart';
import 'package:jadwly/models/session_type.dart';
import 'package:jadwly/models/teacher_class.dart';
import 'package:jadwly/services/cloud_sync_service.dart';
import 'package:jadwly/services/storage_service.dart';
import 'package:jadwly/services/supabase_database_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDir;
  late _FakeCloudDatabase database;
  late CloudSyncService syncService;

  setUp(() async {
    hiveDir = await Directory.systemTemp.createTemp('jadwly_cloud_sync_');
    await StorageService.init(testPath: hiveDir.path);
    database = _FakeCloudDatabase();
    syncService = CloudSyncService(database: database);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDir.delete(recursive: true);
  });

  test('uploadLocalData creates stable UUID mappings for local ids', () async {
    final now = DateTime(2026, 5, 18);
    await StorageService.classesBox.put(
      'class-local',
      TeacherClass(
        id: 'class-local',
        className: 'Class 1',
        subject: 'Digital Skills',
        createdAt: now,
      ),
    );
    await StorageService.scheduleBox.put(
      'schedule-local',
      const ScheduleItem(
        id: 'schedule-local',
        dayOfWeek: DateTime.monday,
        periodNumber: 1,
        startTime: '07:30 AM',
        endTime: '08:15 AM',
        subject: 'Digital Skills',
        classId: 'class-local',
      ),
    );
    await StorageService.lessonsBox.put(
      'lesson-local',
      LessonRecord(
        id: 'lesson-local',
        classId: 'class-local',
        lessonTitle: 'Intro',
        sessionType: SessionType.theoretical,
        notes: '',
        status: LessonStatus.completed,
        date: now,
        createdAt: now,
      ),
    );

    final firstSummary = await syncService.uploadLocalData();
    final firstClassId = database.teacherClassIds.single;
    final firstScheduleId = database.scheduleIds.single;
    final firstLessonId = database.lessonIds.single;

    database.clear();
    final secondSummary = await syncService.uploadLocalData();

    expect(firstSummary.total, 3);
    expect(secondSummary.total, 3);
    expect(CloudSyncService.isUuid(firstClassId), isTrue);
    expect(CloudSyncService.isUuid(firstScheduleId), isTrue);
    expect(CloudSyncService.isUuid(firstLessonId), isTrue);
    expect(database.teacherClassIds.single, firstClassId);
    expect(database.scheduleIds.single, firstScheduleId);
    expect(database.lessonIds.single, firstLessonId);
  });

  test('delete uses stored cloud id mapping for local ids', () async {
    final item = TeacherClass(
      id: 'class-local',
      className: 'Class 1',
      subject: 'Digital Skills',
      createdAt: DateTime(2026, 5, 18),
    );
    await StorageService.classesBox.put(item.id, item);
    await syncService.uploadTeacherClass(item);
    final cloudId = database.teacherClassIds.single;

    await syncService.deleteTeacherClass(item.id);
    await syncService.deleteTeacherClass(item.id);

    expect(database.deletedTeacherClassIds, [cloudId]);
  });

  test('restoreCloudDataReplaceLocal replaces local boxes with remote data',
      () async {
    final now = DateTime(2026, 5, 18);
    await StorageService.classesBox.put(
      'old-class',
      TeacherClass(
        id: 'old-class',
        className: 'Old Class',
        subject: 'Old Subject',
        createdAt: now,
      ),
    );
    database.remoteClasses = [
      TeacherClass(
        id: '11111111-1111-4111-8111-111111111111',
        className: 'Remote Class',
        subject: 'Digital Skills',
        createdAt: now,
      ),
    ];
    database.remoteSchedule = [
      const ScheduleItem(
        id: '22222222-2222-4222-8222-222222222222',
        dayOfWeek: DateTime.monday,
        periodNumber: 1,
        startTime: '07:30 AM',
        endTime: '08:15 AM',
        subject: 'Digital Skills',
        classId: 'Remote Class',
      ),
    ];
    database.remoteLessons = [
      LessonRecord(
        id: '33333333-3333-4333-8333-333333333333',
        classId: 'Remote Class',
        lessonTitle: 'Remote Lesson',
        sessionType: SessionType.theoretical,
        notes: '',
        status: LessonStatus.completed,
        date: now,
        createdAt: now,
      ),
    ];
    database.remoteReminderSettings = {
      'is_enabled': true,
      'minutes_offset': 15,
    };

    final summary = await syncService.restoreCloudDataReplaceLocal();

    expect(summary.total, 3);
    expect(database.cancelDeletionCalls, 1);
    expect(StorageService.classesBox.keys, [
      '11111111-1111-4111-8111-111111111111',
    ]);
    expect(StorageService.scheduleBox.values.single.classId,
        '11111111-1111-4111-8111-111111111111');
    expect(StorageService.lessonsBox.values.single.classId,
        '11111111-1111-4111-8111-111111111111');
    expect(StorageService.settingsBox.get('notificationsEnabled'), isTrue);
    expect(StorageService.settingsBox.get('reminderMinutes'), 15);
  });

  test('scheduleCloudDataDeletion delegates to database', () async {
    final scheduledFor = await syncService.scheduleCloudDataDeletion();

    expect(database.scheduleDeletionCalls, 1);
    expect(scheduledFor, database.scheduledFor);
  });

  test('replaceCloudWithLocalData clears cloud then uploads local data',
      () async {
    final now = DateTime(2026, 5, 18);
    await StorageService.classesBox.put(
      'class-local',
      TeacherClass(
        id: 'class-local',
        className: 'Class 1',
        subject: 'Digital Skills',
        createdAt: now,
      ),
    );
    await StorageService.scheduleBox.put(
      'schedule-local',
      const ScheduleItem(
        id: 'schedule-local',
        dayOfWeek: DateTime.monday,
        periodNumber: 1,
        startTime: '07:30 AM',
        endTime: '08:15 AM',
        subject: 'Digital Skills',
        classId: 'class-local',
      ),
    );
    await StorageService.lessonsBox.put(
      'lesson-local',
      LessonRecord(
        id: 'lesson-local',
        classId: 'class-local',
        lessonTitle: 'Intro',
        sessionType: SessionType.theoretical,
        notes: '',
        status: LessonStatus.completed,
        date: now,
        createdAt: now,
      ),
    );

    final summary = await syncService.replaceCloudWithLocalData();

    expect(summary.total, 3);
    expect(database.cancelDeletionCalls, 1);
    expect(database.deleteCloudDataCalls, 1);
    expect(database.teacherClassIds, hasLength(1));
    expect(database.scheduleIds, hasLength(1));
    expect(database.lessonIds, hasLength(1));
  });

  test('uploadLocalData normalizes legacy noon end time before upload',
      () async {
    await StorageService.scheduleBox.put(
      'schedule-legacy',
      const ScheduleItem(
        id: 'schedule-legacy',
        dayOfWeek: DateTime.monday,
        periodNumber: 7,
        startTime: '11:55 AM',
        endTime: '12:40 AM',
        subject: 'Digital Skills',
        classId: 'class-local',
      ),
    );

    await syncService.uploadLocalData();

    expect(database.uploadedScheduleItems.single.startTime, '11:55 AM');
    expect(database.uploadedScheduleItems.single.endTime, '12:40 PM');
  });
}

class _FakeCloudDatabase implements CloudDatabase {
  final teacherClassIds = <String>[];
  final scheduleIds = <String>[];
  final lessonIds = <String>[];
  final deletedTeacherClassIds = <String>[];
  final uploadedScheduleItems = <ScheduleItem>[];
  List<TeacherClass> remoteClasses = [];
  List<ScheduleItem> remoteSchedule = [];
  List<LessonRecord> remoteLessons = [];
  Map<String, dynamic>? remoteReminderSettings;
  DateTime scheduledFor = DateTime(2026, 5, 25);
  int scheduleDeletionCalls = 0;
  int cancelDeletionCalls = 0;
  int deleteCloudDataCalls = 0;

  void clear() {
    teacherClassIds.clear();
    scheduleIds.clear();
    lessonIds.clear();
  }

  @override
  Future<String> currentUserId() async => 'user-1';

  @override
  Future<List<TeacherClass>> fetchTeacherClasses() async => remoteClasses;

  @override
  Future<List<ScheduleItem>> fetchWeeklySchedule() async => remoteSchedule;

  @override
  Future<List<LessonRecord>> fetchLessonRecords() async => remoteLessons;

  @override
  Future<Map<String, dynamic>?> fetchReminderSettings() async {
    return remoteReminderSettings;
  }

  @override
  Future<void> upsertTeacherClass(TeacherClass item, String cloudId) async {
    teacherClassIds.add(cloudId);
  }

  @override
  Future<void> deleteTeacherClass(String cloudId) async {
    deletedTeacherClassIds.add(cloudId);
  }

  @override
  Future<void> upsertScheduleItem(
    ScheduleItem item,
    String cloudId, {
    required String className,
  }) async {
    scheduleIds.add(cloudId);
    uploadedScheduleItems.add(item);
  }

  @override
  Future<void> deleteScheduleItem(String cloudId) async {}

  @override
  Future<void> upsertLessonRecord(
    LessonRecord record,
    String cloudId, {
    required String className,
    required String subject,
  }) async {
    lessonIds.add(cloudId);
  }

  @override
  Future<void> deleteLessonRecord(String cloudId) async {}

  @override
  Future<void> saveProfileName(String fullName) async {}

  @override
  Future<void> saveReminderSettings({
    required bool notificationsEnabled,
    required int reminderMinutes,
  }) async {}

  @override
  Future<void> saveFcmToken({
    required String token,
    required String platform,
    String? appVersion,
  }) async {}

  @override
  Future<void> deleteFcmToken(String token) async {}

  @override
  Future<DateTime> scheduleCloudDataDeletion({
    Duration delay = const Duration(days: 7),
  }) async {
    scheduleDeletionCalls++;
    return scheduledFor;
  }

  @override
  Future<DateTime?> fetchCloudDataDeletionScheduledFor() async {
    return scheduledFor;
  }

  @override
  Future<void> cancelCloudDataDeletion() async {
    cancelDeletionCalls++;
  }

  @override
  Future<void> deleteCloudDataForCurrentUser() async {
    deleteCloudDataCalls++;
  }
}
