import 'dart:math';

import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models/lesson_record.dart';
import '../models/schedule_item.dart';
import '../models/teacher_class.dart';
import 'storage_service.dart';
import 'supabase_database_service.dart';
import 'time_helpers.dart';

class CloudSyncSummary {
  const CloudSyncSummary({
    required this.classes,
    required this.scheduleItems,
    required this.lessonRecords,
  });

  final int classes;
  final int scheduleItems;
  final int lessonRecords;

  int get total => classes + scheduleItems + lessonRecords;
}

class CloudSyncService {
  CloudSyncService({CloudDatabase? database})
      : _database = database ?? SupabaseDatabaseService();

  static const _classMapKey = 'cloudSync.classIds';
  static const _scheduleMapKey = 'cloudSync.scheduleIds';
  static const _lessonMapKey = 'cloudSync.lessonIds';
  static const _lastSyncAtKey = 'cloudSync.lastSyncAt';

  final CloudDatabase _database;

  DateTime? get lastSyncAt {
    final value = StorageService.settingsBox.get(_lastSyncAtKey);
    return value is DateTime ? value : null;
  }

  Future<CloudSyncSummary> uploadLocalData() async {
    final classes = StorageService.classesBox.values.toList();
    final schedule = StorageService.scheduleBox.values.toList();
    final lessons = StorageService.lessonsBox.values.toList();
    var uploadedClasses = 0;
    var uploadedSchedule = 0;
    var uploadedLessons = 0;

    for (final item in classes) {
      await uploadTeacherClass(item);
      uploadedClasses++;
    }
    for (final item in schedule) {
      await uploadScheduleItem(item, className: _classNameFor(item.classId));
      uploadedSchedule++;
    }
    for (final item in lessons) {
      final teacherClass = _classById(item.classId);
      await uploadLessonRecord(
        item,
        className: teacherClass?.className ?? item.classId,
        subject: teacherClass?.subject ?? '',
      );
      uploadedLessons++;
    }

    await StorageService.settingsBox.put(_lastSyncAtKey, DateTime.now());
    return CloudSyncSummary(
      classes: uploadedClasses,
      scheduleItems: uploadedSchedule,
      lessonRecords: uploadedLessons,
    );
  }

  Future<CloudSyncSummary> replaceCloudWithLocalData() async {
    await _database.cancelCloudDataDeletion();
    await _database.deleteCloudDataForCurrentUser();
    return uploadLocalData();
  }

  Future<CloudSyncSummary> restoreCloudDataReplaceLocal() async {
    await _database.cancelCloudDataDeletion();
    final remoteClasses = await _database.fetchTeacherClasses();
    final remoteSchedule = await _database.fetchWeeklySchedule();
    final remoteLessons = await _database.fetchLessonRecords();
    final remoteReminderSettings = await _database.fetchReminderSettings();

    final matchedSchedule = remoteSchedule
        .map((item) => _matchRemoteScheduleClass(item, remoteClasses))
        .toList();
    final matchedLessons = remoteLessons
        .map((record) => _matchRemoteLessonClass(record, remoteClasses))
        .toList();

    await StorageService.classesBox.clear();
    await StorageService.scheduleBox.clear();
    await StorageService.lessonsBox.clear();
    await StorageService.classesBox.putAll({
      for (final item in remoteClasses) item.id: item,
    });
    await StorageService.scheduleBox.putAll({
      for (final item in matchedSchedule) item.id: item,
    });
    await StorageService.lessonsBox.putAll({
      for (final item in matchedLessons) item.id: item,
    });
    await _replaceCloudIdMaps(
      classes: remoteClasses,
      schedule: matchedSchedule,
      lessons: matchedLessons,
    );
    await _saveRemoteReminderSettings(remoteReminderSettings);
    await StorageService.settingsBox.put(_lastSyncAtKey, DateTime.now());

    return CloudSyncSummary(
      classes: remoteClasses.length,
      scheduleItems: matchedSchedule.length,
      lessonRecords: matchedLessons.length,
    );
  }

  Future<DateTime> scheduleCloudDataDeletion() {
    return _database.scheduleCloudDataDeletion();
  }

  Future<DateTime?> fetchCloudDataDeletionScheduledFor() {
    return _database.fetchCloudDataDeletionScheduledFor();
  }

  Future<void> cancelCloudDataDeletion() {
    return _database.cancelCloudDataDeletion();
  }

  Future<void> deleteCloudDataForCurrentUser() {
    return _database.deleteCloudDataForCurrentUser();
  }

  Future<void> uploadTeacherClass(TeacherClass item) async {
    final cloudId = await _cloudIdFor(_classMapKey, item.id);
    await _database.upsertTeacherClass(item, cloudId);
  }

  Future<void> deleteTeacherClass(String localId) async {
    final cloudId = _existingCloudIdFor(_classMapKey, localId);
    if (cloudId == null) return;
    await _database.deleteTeacherClass(cloudId);
    await _removeCloudId(_classMapKey, localId);
  }

  Future<void> uploadScheduleItem(
    ScheduleItem item, {
    required String className,
  }) async {
    final cloudId = await _cloudIdFor(_scheduleMapKey, item.id);
    final normalizedItem = _normalizeScheduleItem(item);
    await _database.upsertScheduleItem(
      normalizedItem,
      cloudId,
      className: className,
    );
  }

  Future<void> deleteScheduleItem(String localId) async {
    final cloudId = _existingCloudIdFor(_scheduleMapKey, localId);
    if (cloudId == null) return;
    await _database.deleteScheduleItem(cloudId);
    await _removeCloudId(_scheduleMapKey, localId);
  }

  Future<void> uploadLessonRecord(
    LessonRecord record, {
    required String className,
    required String subject,
  }) async {
    final cloudId = await _cloudIdFor(_lessonMapKey, record.id);
    await _database.upsertLessonRecord(
      record,
      cloudId,
      className: className,
      subject: subject,
    );
  }

  Future<void> deleteLessonRecord(String localId) async {
    final cloudId = _existingCloudIdFor(_lessonMapKey, localId);
    if (cloudId == null) return;
    await _database.deleteLessonRecord(cloudId);
    await _removeCloudId(_lessonMapKey, localId);
  }

  Future<void> saveProfileName(String fullName) {
    return _database.saveProfileName(fullName);
  }

  Future<void> saveReminderSettings({
    required bool notificationsEnabled,
    required int reminderMinutes,
  }) {
    return _database.saveReminderSettings(
      notificationsEnabled: notificationsEnabled,
      reminderMinutes: reminderMinutes,
    );
  }

  Future<void> saveFcmToken({
    required String token,
    required String platform,
  }) async {
    await _database.saveFcmToken(
      token: token,
      platform: platform,
      appVersion: await _appVersion(),
    );
  }

  Future<void> deleteFcmToken(String token) {
    return _database.deleteFcmToken(token);
  }

  Future<String?> _appVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return '${packageInfo.version}+${packageInfo.buildNumber}';
    } on MissingPluginException {
      return null;
    }
  }

  Future<String> _cloudIdFor(String mapKey, String localId) async {
    if (isUuid(localId)) return localId;
    final map = _idMap(mapKey);
    final existing = map[localId];
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _newUuid();
    map[localId] = generated;
    await StorageService.settingsBox.put(mapKey, map);
    return generated;
  }

  String? _existingCloudIdFor(String mapKey, String localId) {
    if (isUuid(localId)) return localId;
    return _idMap(mapKey)[localId];
  }

  Future<void> _removeCloudId(String mapKey, String localId) async {
    if (isUuid(localId)) return;
    final map = _idMap(mapKey);
    map.remove(localId);
    await StorageService.settingsBox.put(mapKey, map);
  }

  Map<String, String> _idMap(String mapKey) {
    final raw = StorageService.settingsBox.get(mapKey);
    if (raw is! Map) return <String, String>{};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    );
  }

  TeacherClass? _classById(String id) {
    return StorageService.classesBox.get(id);
  }

  String _classNameFor(String id) {
    return _classById(id)?.className ?? id;
  }

  ScheduleItem _normalizeScheduleItem(ScheduleItem item) {
    final startTime = normalizeClockTimeAmPm(item.startTime);
    final endTime = normalizeLegacyScheduleEndTime(
      startTime: startTime,
      endTime: item.endTime,
    );
    return item.copyWith(
      startTime: startTime,
      endTime: endTime,
    );
  }

  ScheduleItem _matchRemoteScheduleClass(
    ScheduleItem item,
    List<TeacherClass> classes,
  ) {
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

  LessonRecord _matchRemoteLessonClass(
    LessonRecord record,
    List<TeacherClass> classes,
  ) {
    for (final teacherClass in classes) {
      if (teacherClass.className == record.classId) {
        return LessonRecord(
          id: record.id,
          classId: teacherClass.id,
          lessonTitle: record.lessonTitle,
          sessionType: record.sessionType,
          notes: record.notes,
          status: record.status,
          date: record.date,
          createdAt: record.createdAt,
        );
      }
    }
    return record;
  }

  Future<void> _replaceCloudIdMaps({
    required List<TeacherClass> classes,
    required List<ScheduleItem> schedule,
    required List<LessonRecord> lessons,
  }) async {
    await StorageService.settingsBox.put(
      _classMapKey,
      {for (final item in classes) item.id: item.id},
    );
    await StorageService.settingsBox.put(
      _scheduleMapKey,
      {for (final item in schedule) item.id: item.id},
    );
    await StorageService.settingsBox.put(
      _lessonMapKey,
      {for (final item in lessons) item.id: item.id},
    );
  }

  Future<void> _saveRemoteReminderSettings(Map<String, dynamic>? row) async {
    if (row == null) return;
    await StorageService.settingsBox.put(
      'notificationsEnabled',
      row['is_enabled'] as bool? ?? false,
    );
    await StorageService.settingsBox.put(
      'reminderMinutes',
      row['minutes_offset'] as int? ?? 10,
    );
  }

  static bool isUuid(String value) {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(value);
  }

  static String _newUuid() {
    final bytes = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final text = bytes.map(hex).join();
    return '${text.substring(0, 8)}-'
        '${text.substring(8, 12)}-'
        '${text.substring(12, 16)}-'
        '${text.substring(16, 20)}-'
        '${text.substring(20)}';
  }
}
